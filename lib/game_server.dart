import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'services/deck_service.dart';
import 'dart:math';

class GameServer {
  List<WebSocketChannel> _clients = [];
  HttpServer? _server;
  final DeckService _deckService = DeckService();
  
  // --- GAME STATE ---
  String _gameType = 'kadi';
  bool _isGameRunning = false;
  int _currentPlayerIndex = 0;
  int _direction = 1; 
  List<List<CardModel>> _playerHands = []; 
  List<int> _books = []; // Go Fish Books
  CardModel? _topCard;
  List<Map<String, dynamic>> _musicQueue = [];
  String? _currentMusicId;
  
  // --- RULE VARIABLES ---
  int _bombStack = 0;           
  bool _waitingForAnswer = false; 
  String? _forcedSuit;
  String? _forcedRank; 
  Map<int, bool> _hasSaidNikoKadi = {}; 
  List<CardModel> _discardPile = [];
  String? _jokerColorConstraint; 

  Future<void> start() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    var handler = webSocketHandler((WebSocketChannel webSocket) {
      if (_isGameRunning) {
        webSocket.sink.close(1000, "Game already started!");
        return;
      }

      _clients.add(webSocket);
      int playerIndex = _clients.length - 1; 
      print("Player $playerIndex joined. Total: ${_clients.length}");
      _hasSaidNikoKadi[playerIndex] = false; 
      
      _broadcast("PLAYER_COUNT_UPDATE", _clients.length);

      webSocket.stream.listen((message) {
        final data = jsonDecode(message);
        
        if (data['type'] == 'START_GAME' && playerIndex == 0) {
          // Allow 1 player for testing/debugging
          if (_clients.length >= 1) {
             _startGame(data['decks'] ?? 1, data['gameType'] ?? 'kadi');
          } else {
             _sendToPlayer(webSocket, "CHAT", {"sender": "System", "message": "Waiting for players..."});
          }
        }
        else if (data['type'] == 'PLAY_CARD') {
          _handlePlayCard(
            playerIndex, 
            data['cardIndex'], 
            data['requestedSuit'],
            data['requestedRank'],
            data['saidNikoKadi'] ?? false
          );
        } 
        else if (data['type'] == 'PICK_CARD') {
          _handlePickCard(playerIndex);
        }
        else if (data['type'] == 'ASK_CARD') {
           _handleGoFishAsk(playerIndex, data['targetIndex'], data['rank']);
        }
        else if (data['type'] == 'CHAT') {
          _broadcast("CHAT", {
            "sender": data['senderName'], 
            "message": data['message'],
            "isSystem": false
          });
        }else if (data['type'] == 'ADD_TO_QUEUE') {
          // Assuming you added _musicQueue and _currentMusicId to GameServer class
          String id = data['data']['videoId'];
          String title = data['data']['title'];
          
          _musicQueue.add({'videoId': id, 'title': title});
          
          if (_currentMusicId == null) {
              _playNextLanSong();
          } else {
              _broadcast("QUEUE_UPDATE", {'queue': _musicQueue});
          }
      }
      else if (data['type'] == 'SONG_ENDED') {
          _playNextLanSong();
      }
      }, onDone: () {
        _clients.remove(webSocket);
        _hasSaidNikoKadi.remove(playerIndex);
        _broadcast("PLAYER_COUNT_UPDATE", _clients.length);
      });
    });

    _server = await shelf_io.serve(handler, '0.0.0.0', 8080);
    print("Server running on ws://${_server!.address.host}:${_server!.port}");
  }

void _playNextLanSong() {
      if (_musicQueue.isNotEmpty) {
          var next = _musicQueue.removeAt(0);
          _currentMusicId = next['videoId'];
          String title = next['title']; // Get title
          
          // Broadcast with Title
          _broadcast("MUSIC_UPDATE", {'videoId': _currentMusicId, 'title': title});
          _broadcast("QUEUE_UPDATE", {'queue': _musicQueue});
      } else {
          _currentMusicId = null;
      }
  }

  void _startGame(int decks, String gameType) {
    _isGameRunning = true;
    _gameType = gameType;
    _deckService.initializeDeck(decks: decks);
    _deckService.shuffle();

    _playerHands = List.generate(_clients.length, (_) => []);
    
    // SETUP
    int dealCount = 4;
    // Go Fish Deal Count override
    if (_gameType == 'gofish') {
       dealCount = _clients.length <= 3 ? 7 : 5;
       _books = List.filled(_clients.length, 0);
    }

    for (int i = 0; i < _clients.length; i++) {
      _playerHands[i] = _deckService.drawCards(dealCount);
      _sendToPlayer(_clients[i], "DEAL_HAND", _playerHands[i]);
      _hasSaidNikoKadi[i] = false;
    }

    if (_gameType == 'kadi') {
        _topCard = _deckService.drawCards(1).first;
        // Ensure top card isn't a power card to start
        while (['2','3','8','jack','queen','king','ace','joker'].contains(_topCard!.rank)) {
           _deckService.addCardToBottom(_topCard!);
           _topCard = _deckService.drawCards(1).first;
        }
        _discardPile.clear();
        _jokerColorConstraint = null;
        _broadcast("UPDATE_TABLE", _topCard);
    } else {
        // Go Fish Setup
        _broadcast("GO_FISH_STATE", {'books': _books});
    }

    _currentPlayerIndex = 0;
    _direction = 1; 
    _bombStack = 0;
    _waitingForAnswer = false;
    _forcedSuit = null;
    _forcedRank = null;
    
    _broadcastTurn();
    _broadcast("CHAT", {"sender": "System", "message": "${_gameType.toUpperCase()} Started!"});
  }

  void _handlePlayCard(int playerIndex, int cardIndex, String? requestedSuit, String? requestedRank, bool saidNikoKadi) {
    if (playerIndex != _currentPlayerIndex) return;

    List<CardModel> hand = _playerHands[playerIndex];
    if (cardIndex >= hand.length) return; // Safety check
    CardModel card = hand[cardIndex];

    if (!_isValidMove(card)) {
      _sendToPlayer(_clients[playerIndex], "ERROR", "Invalid Move!");
      return;
    }

    if (saidNikoKadi) _hasSaidNikoKadi[playerIndex] = true;

    hand.removeAt(cardIndex);
    if (_topCard != null) _discardPile.add(_topCard!);
    _topCard = card;
    if (_jokerColorConstraint != null) _jokerColorConstraint = null;
    
    bool isBomb = ['2', '3', 'joker'].contains(card.rank);
    if (card.rank == '2') _bombStack += 2;
    else if (card.rank == '3') _bombStack += 3;
    else if (card.rank == 'joker') _bombStack += 5;

    // --- ACE LOGIC (Includes Spades Lock) ---
    if (card.rank == 'ace') {
       if (_bombStack > 0 && !isBomb) {
          _bombStack = 0; 
          _forcedSuit = null; 
          _forcedRank = null;
          _broadcast("CHAT", {"sender": "System", "message": "Bomb Blocked!"});
       } else {
          _bombStack = 0; 
          
          // SPECIAL: Ace of Spades Strategy (Lock & Key)
          // If you play Ace of Spades and have exactly 1 card left, you lock the game to that specific card.
          if (card.suit == 'spades' && hand.length == 1) {
             CardModel winningCard = hand[0]; 
             _forcedSuit = winningCard.suit;
             _forcedRank = winningCard.rank;
             _broadcast("CHAT", {"sender": "System", "message": "🔒 LOCKED: ${_forcedRank} of ${_forcedSuit}"});
          } 
          // Normal Ace Request
          else {
             _forcedSuit = requestedSuit ?? card.suit;
             _forcedRank = requestedRank;
             
             String msg = "New Suit: $_forcedSuit";
             if (_forcedRank != null) msg += " | Target: $_forcedRank";
             _broadcast("CHAT", {"sender": "System", "message": msg});
          }
       }
    } else {
       // Clear constraints if non-Ace played
       if (_forcedSuit != null) {
          _forcedSuit = null;
          _forcedRank = null;
       }
    }

    // --- NIKO KADI PENALTY ---
    bool isWinningHand = hand.isNotEmpty && hand.every((c) => c.rank == hand[0].rank);
    if (hand.length == 1) {
      if (_hasSaidNikoKadi[playerIndex] != true) {
        if (_isWinningCard(hand[0])) {
          _broadcast("CHAT", {"sender": "Referee", "message": "Player ${playerIndex + 1} forgot Niko Kadi! +2 Cards"});
          _drawCardsForPlayer(playerIndex, 2);
          _updateGameState();
          _advanceTurn();
          return; 
        }
      }
    }
    // If player broke a combo or picked cards, reset Niko Kadi status
    if (hand.length > 1 && !isWinningHand) _hasSaidNikoKadi[playerIndex] = false;

    _playerHands[playerIndex] = hand; 

    bool turnEnds = true;
    int skipCount = 0;

    // --- UPDATED TURN LOGIC (Chaining & Self-Answering) ---
    
    // 1. Question (Q/8): Player retains turn to Chain or Answer
    if (card.rank == 'queen' || card.rank == '8') {
      _waitingForAnswer = true;
      turnEnds = false; 
      _broadcast("CHAT", {"sender": "System", "message": "Question placed! Answer or Chain."});
    } 
    // 2. Answering: If waiting and play was valid (checked in isValidMove), turn ends
    else if (_waitingForAnswer) {
      _waitingForAnswer = false;
      turnEnds = true;
      _broadcast("CHAT", {"sender": "System", "message": "Question Answered."});
    }
    
    // 3. King
    else if (card.rank == 'king') {
       if (_bombStack > 0) _direction *= -1; 
       else _direction *= -1;
    }
    // 4. Jack
    else if (card.rank == 'jack') {
       if (_bombStack > 0) skipCount = 0; 
       else {
          if (_clients.length > 2) skipCount = 1; 
       }
    }
    
    // 5. Multi-drop (Only if not already retaining turn for Question)
    if (turnEnds && skipCount == 0 && hand.isNotEmpty) {
      if (hand.any((c) => c.rank == card.rank)) {
         turnEnds = false;
         _sendToPlayer(_clients[playerIndex], "CHAT", {"sender": "System", "message": "Multi-drop: Play another ${card.rank} or Pick."});
      }
    }

    // --- WIN CHECK ---
    if (hand.isEmpty) {
      bool powerCardFinish = ['2','3','joker','king','jack','queen','8'].contains(card.rank);
      // Explicitly fail if Ace is last card (unless it was Spades Lock scenario which leaves 1 card, so this handles immediate win attempts)
      if (card.rank == 'ace') powerCardFinish = true; 

      bool anyoneElseCardless = _playerHands.any((h) => h.isEmpty);
      
      if (powerCardFinish || anyoneElseCardless) {
         if (powerCardFinish) _broadcast("CHAT", {"sender": "System", "message": "Cannot win with Power Card!"});
         else _broadcast("CHAT", {"sender": "System", "message": "Win Blocked by Cardless Player!"});
         _updateGameState();
         if (turnEnds) _advanceTurn(skip: skipCount);
         return;
      } else {
         _broadcast("GAME_OVER", "Player ${playerIndex + 1} Wins!");
         return; 
      }
    }

    _sendToPlayer(_clients[playerIndex], "DEAL_HAND", hand); 
    _broadcast("UPDATE_TABLE", _topCard); 

    if (turnEnds) {
      _advanceTurn(skip: skipCount);
    } else {
      _broadcastTurn();
    }
  }

  bool _isWinningCard(CardModel card) {
    const nonWinningRanks = ['2', '3', '8', 'jack', 'queen', 'king', 'joker'];
    return !nonWinningRanks.contains(card.rank);
  }

  void _handlePickCard(int playerIndex) {
    if (playerIndex != _currentPlayerIndex) return;

    int count = (_bombStack > 0) ? _bombStack : 1;
    
    if (_bombStack > 0 && _topCard != null && _topCard!.rank == 'joker') {
        if (_topCard!.suit == 'red') _jokerColorConstraint = 'red';
        else if (_topCard!.suit == 'black') _jokerColorConstraint = 'black';
        _broadcast("CHAT", {"sender": "System", "message": "Constraint: $_jokerColorConstraint"});
    }

    _drawCardsForPlayer(playerIndex, count);

    _bombStack = 0;
    _forcedSuit = null;
    _forcedRank = null;
    
    // UPDATED: If picking during Question mode, question is voided
    if (_waitingForAnswer) {
        _waitingForAnswer = false;
        _broadcast("CHAT", {"sender": "System", "message": "Player picked. Question voided."});
    }
    
    _hasSaidNikoKadi[playerIndex] = false;

    _updateGameState();
    _advanceTurn();
  }

  void _drawCardsForPlayer(int playerIndex, int count) {
      List<CardModel> drawn = [];
      if (_deckService.remainingCards >= count) {
         drawn = _deckService.drawCards(count);
      } else {
         drawn.addAll(_deckService.drawCards(_deckService.remainingCards));
         int needed = count - drawn.length;
         if (_discardPile.isNotEmpty) {
            _deckService.addCards(_discardPile);
            _discardPile.clear();
            _deckService.shuffle();
            _broadcast("CHAT", {"sender": "System", "message": "Deck Reshuffled!"});
            drawn.addAll(_deckService.drawCards(needed));
         }
      }
      _playerHands[playerIndex].addAll(drawn);
      _sendToPlayer(_clients[playerIndex], "DEAL_HAND", _playerHands[playerIndex]);
  }

  void _advanceTurn({int skip = 0}) {
    int step = _direction * (1 + skip);
    _currentPlayerIndex = (_currentPlayerIndex + step) % _clients.length;

    if (_currentPlayerIndex < 0) {
      _currentPlayerIndex += _clients.length;
    }

    _broadcastTurn();
  }

  bool _isValidMove(CardModel card) {
    // 1. Joker Constraint
    if (_jokerColorConstraint != null) {
      bool isBomb = ['2', '3', 'joker'].contains(card.rank);
      if (isBomb) return true;
      String cardColor = (card.suit == 'hearts' || card.suit == 'diamonds' || card.suit == 'red') ? 'red' : 'black';
      return cardColor == _jokerColorConstraint;
    }

    // 2. Bomb Stack
    if (_bombStack > 0) {
      if (['2', '3', 'joker'].contains(card.rank)) return true;
      if (card.rank == 'ace') return true; 
      if (card.rank == 'king') return true; 
      if (card.rank == 'jack') return true; 
      return false; 
    }

    // 3. Question Mode (Self-Answering & Chaining)
    if (_waitingForAnswer) {
       // Chain Q/8 (Match Suit OR Rank)
       if (card.rank == 'queen' || card.rank == '8') {
           return card.suit == _topCard!.suit || card.rank == _topCard!.rank;
       }
       // Answer (Must be non-power card matching SUIT)
       if (['4','5','6','7','9','10'].contains(card.rank)) {
           return card.suit == _topCard!.suit;
       }
       return false;
    }

    // 4. Ace Counter-Play (Ace overrides any forced Suit/Rank)
    if (card.rank == 'ace') return true;

    // 5. Forced Requests (The Lock)
    if (_forcedRank != null && _forcedSuit != null) {
      return card.rank == _forcedRank && card.suit == _forcedSuit;
    }

    if (_forcedSuit != null) {
      return card.suit == _forcedSuit;
    }

    // 6. Standard Play
    return card.suit == _topCard!.suit || card.rank == _topCard!.rank || ['2','3','joker'].contains(card.rank);
  }

  void _updateGameState() {
     // LAN specific state updates if needed
  }

  void _sendToPlayer(WebSocketChannel client, String type, dynamic data) {
    client.sink.add(jsonEncode({"type": type, "data": data}));
  }

  void _broadcast(String type, dynamic data) {
    for (var client in _clients) client.sink.add(jsonEncode({"type": type, "data": data}));
  }
  
  void _broadcastTurn() {
    _broadcast("TURN_UPDATE", {
      "playerIndex": _currentPlayerIndex,
      "bombStack": _bombStack, 
      "waitingForAnswer": _waitingForAnswer,
      "direction": _direction,
      "jokerColorConstraint": _jokerColorConstraint,
    });
  }

  void stop() {
    _server?.close();
  }
  // --- GO FISH LOGIC ---
  void _handleGoFishAsk(int askerIdx, int targetIdx, String rank) {
     if (askerIdx != _currentPlayerIndex) return;
     if (targetIdx < 0 || targetIdx >= _clients.length || targetIdx == askerIdx) return;

     List<CardModel> targetHand = _playerHands[targetIdx];
     List<CardModel> found = targetHand.where((c) => c.rank == rank).toList();

     if (found.isNotEmpty) {
        // SUCCESS
        targetHand.removeWhere((c) => c.rank == rank);
        _playerHands[askerIdx].addAll(found);
        
        _broadcast("CHAT", {
           "sender": "System", 
           "message": "Player ${askerIdx+1} took ${found.length} ${rank}s from Player ${targetIdx+1}"
        });
        
        _checkBooks(askerIdx);
        _sendToPlayer(_clients[askerIdx], "DEAL_HAND", _playerHands[askerIdx]);
        _sendToPlayer(_clients[targetIdx], "DEAL_HAND", _playerHands[targetIdx]);
        
        // Go again
        _broadcastTurn();
     } else {
        // FAIL -> GO FISH
        _broadcast("CHAT", {"sender": "System", "message": "Player ${targetIdx+1} says: GO FISH!"});
        
        if (_deckService.remainingCards > 0) {
           List<CardModel> drawn = _deckService.drawCards(1);
           CardModel card = drawn.first;
           _playerHands[askerIdx].add(card);
           _checkBooks(askerIdx);
           _sendToPlayer(_clients[askerIdx], "DEAL_HAND", _playerHands[askerIdx]);
           
           if (card.rank == rank) {
               _broadcast("CHAT", {"sender": "System", "message": "Fished the $rank! Go again."});
               _broadcastTurn();
               return;
           }
        } else {
           _broadcast("CHAT", {"sender": "System", "message": "Pond is empty."});
        }
        
        _advanceTurn();
     }
  }

  void _checkBooks(int playerIndex) {
     Map<String, int> counts = {};
     for (var c in _playerHands[playerIndex]) counts[c.rank] = (counts[c.rank] ?? 0) + 1;
     
     counts.forEach((rank, count) {
        if (count == 4) {
           _playerHands[playerIndex].removeWhere((c) => c.rank == rank);
           _books[playerIndex]++;
           _broadcast("CHAT", {"sender": "System", "message": "Player ${playerIndex+1} made a Book of ${rank}s!"});
        }
     });
     
     _broadcast("GO_FISH_STATE", {'books': _books});
     
     // WIN CONDITION
     int totalBooks = _books.fold(0, (a, b) => a + b);
     if (totalBooks == 13 || (_deckService.remainingCards == 0 && _playerHands.every((h) => h.isEmpty))) {
         int maxBooks = _books.reduce(max);
         List<int> winners = [];
         for(int i=0; i<_books.length; i++) if(_books[i] == maxBooks) winners.add(i);
         _broadcast("GAME_OVER", "Player ${winners.first + 1} Wins!");
         _isGameRunning = false;
     }
  }
}