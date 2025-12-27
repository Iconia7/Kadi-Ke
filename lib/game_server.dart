import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'services/deck_service.dart';

class GameServer {
  List<WebSocketChannel> _clients = [];
  HttpServer? _server;
  final DeckService _deckService = DeckService();
  
  // --- GAME STATE ---
  bool _isGameRunning = false;
  int _currentPlayerIndex = 0;
  int _direction = 1; 
  List<List<CardModel>> _playerHands = []; 
  CardModel? _topCard;
  
  // --- RULE VARIABLES ---
  int _bombStack = 0;           
  bool _waitingForAnswer = false; 
  String? _forcedSuit;
  String? _forcedRank; 
  Map<int, bool> _hasSaidNikoKadi = {}; 
  List<CardModel> _discardPile = [];
  String? _jokerColorConstraint; 

  Future<void> start() async {
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
          if (_clients.length >= 2) _startGame(data['decks'] ?? 1);
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
        else if (data['type'] == 'CHAT') {
          _broadcast("CHAT", {
            "sender": data['senderName'], 
            "message": data['message'],
            "isSystem": false
          });
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

  void _startGame(int decks) {
    _isGameRunning = true;
    _deckService.initializeDeck(decks: decks);
    _deckService.shuffle();

    _playerHands = List.generate(_clients.length, (_) => []);

    for (int i = 0; i < _clients.length; i++) {
      _playerHands[i] = _deckService.drawCards(4);
      _sendToPlayer(_clients[i], "DEAL_HAND", _playerHands[i]);
      _hasSaidNikoKadi[i] = false;
    }

    _topCard = _deckService.drawCards(1).first;
    _discardPile.clear();
    _jokerColorConstraint = null;
    _broadcast("UPDATE_TABLE", _topCard);

    _currentPlayerIndex = 0;
    _direction = 1; 
    _bombStack = 0;
    _waitingForAnswer = false;
    _forcedSuit = null;
    _forcedRank = null;
    
    _broadcastTurn();
  }

void _handlePlayCard(int playerIndex, int cardIndex, String? requestedSuit, String? requestedRank, bool saidNikoKadi) {
    if (playerIndex != _currentPlayerIndex) return;

    List<CardModel> hand = _playerHands[playerIndex];
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

    if (card.rank == 'ace') {
       if (_bombStack > 0 && !isBomb) {
          _bombStack = 0; 
          _forcedSuit = null; 
          _forcedRank = null;
       } else {
          _forcedSuit = requestedSuit ?? card.suit;
          _forcedRank = requestedRank;
          _bombStack = 0; 
          
          String msg = "New Suit: $_forcedSuit";
          if (_forcedRank != null) msg += " | Target: $_forcedRank";
          _broadcast("CHAT", {"sender": "System", "message": msg});
       }
    } else {
       if (_forcedSuit != null) {
          _forcedSuit = null;
          _forcedRank = null;
       }
    }

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
    if (hand.length > 1 && !isWinningHand) _hasSaidNikoKadi[playerIndex] = false;

    _playerHands[playerIndex] = hand; 

    bool turnEnds = true;
    int skipCount = 0;

    if (card.rank == 'king') {
       if (_bombStack > 0) _direction *= -1; 
       else _direction *= -1;
    }
    else if (card.rank == 'jack') {
       if (_bombStack > 0) skipCount = 0; 
       else {
          if (_clients.length > 2) skipCount = 1; 
       }
    }
    else if (card.rank == 'queen' || card.rank == '8') {
      _waitingForAnswer = true;
      turnEnds = false; 
    } 
    else if (_waitingForAnswer) {
      _waitingForAnswer = false;
      turnEnds = true;
    }
    
    // Multi-drop
    if (turnEnds && skipCount == 0 && hand.isNotEmpty) {
      if (hand.any((c) => c.rank == card.rank)) {
         turnEnds = false;
         _sendToPlayer(_clients[playerIndex], "CHAT", {"sender": "System", "message": "Multi-drop: Play another ${card.rank} or Pick."});
      }
    }

    // --- CARDLESS LOGIC ---
    if (hand.isEmpty) {
      bool powerCardFinish = ['2','3','joker','king','jack','queen','8'].contains(card.rank);
      bool anyoneElseCardless = _playerHands.any((h) => h.isEmpty);
      
      if (powerCardFinish || anyoneElseCardless) {
         if (powerCardFinish) _broadcast("CHAT", {"sender": "System", "message": "Player ${playerIndex + 1} is Cardless!"});
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
  _waitingForAnswer = false;
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
    if (_jokerColorConstraint != null) {
      bool isBomb = ['2', '3', 'joker'].contains(card.rank);
      if (isBomb) return true;
      String cardColor = (card.suit == 'hearts' || card.suit == 'diamonds' || card.suit == 'red') ? 'red' : 'black';
      return cardColor == _jokerColorConstraint;
    }

    if (['2', '3', 'joker'].contains(card.rank)) return true;

    if (_bombStack > 0) {
      return ['ace', 'king', 'jack'].contains(card.rank);
    }

    if (_waitingForAnswer) {
       if (card.suit != _topCard!.suit) return false;
       return ['4','5','6','7','9','10'].contains(card.rank);
    }

    if (_forcedRank != null && _forcedSuit != null) {
      return card.rank == _forcedRank && card.suit == _forcedSuit;
    }

    if (_forcedSuit != null) {
      if (card.rank == 'ace') return true; 
      return card.suit == _forcedSuit;
    }

    if (card.rank == 'ace') return true;
    return card.suit == _topCard!.suit || card.rank == _topCard!.rank;
  }

  void _updateGameState() {
     // LAN specific: iterate to send hands if needed, but here simple broadcast of table usually sufficient
     // For simplicity in this file structure, assume client handles its own state mostly
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
}