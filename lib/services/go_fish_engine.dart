import 'dart:async';
import 'dart:math';
import 'deck_service.dart';

class GoFishEngine {
  final DeckService _deckService = DeckService();
  final StreamController<Map<String, dynamic>> _streamController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get gameStream => _streamController.stream;

  List<List<CardModel>> _hands = [];
  List<int> _books = [];
  int _currentPlayerIndex = 0;
  int _playerCount = 0;
  
  Timer? _botTimer; 
  bool _isGameOver = false;
  Map<int, Set<String>> _botMemory = {}; 

  // FIX: Added 'decks' parameter to match call signature, even if unused for now
  void start(int aiCount, String difficulty, {int decks = 1}) {
    _isGameOver = false;
    _playerCount = aiCount + 1;
    _hands = List.generate(_playerCount, (_) => []);
    _books = List.filled(_playerCount, 0);
    _botMemory = {};
    
    _deckService.initializeDeck();
    _deckService.shuffle();
    
    // Deal 7 cards if 3 or fewer players, else 5
    int dealCount = _playerCount <= 3 ? 7 : 5;
    for (int i = 0; i < _playerCount; i++) _hands[i] = _deckService.drawCards(dealCount);
    
    _broadcastUpdate();
    _broadcast("PLAYER_COUNT_UPDATE", _playerCount);
    _currentPlayerIndex = 0;
    _broadcastTurn();
  }

  void askForCard(int targetIndex, String rank) {
    if (_currentPlayerIndex != 0 || _isGameOver) return;
    _processAsk(0, targetIndex, rank);
  }

  void _processAsk(int askerIndex, int targetIndex, String rank) {
    if (_isGameOver) return;
    List<CardModel> targetHand = _hands[targetIndex];
    List<CardModel> foundCards = targetHand.where((c) => c.rank == rank).toList();

    _updateMemory(askerIndex, rank); 

    if (foundCards.isNotEmpty) {
      // SUCCESS: Transfer cards
      _hands[targetIndex].removeWhere((c) => c.rank == rank);
      _hands[askerIndex].addAll(foundCards);
      
      _broadcast("CHAT", {
        "sender": askerIndex == 0 ? "You" : "P${askerIndex + 1}", 
        "message": "Took ${foundCards.length} ${rank}s from P${targetIndex + 1}"
      });
      
      _checkBooks(askerIndex);
      _broadcastUpdate();
      
      // Asker goes again
      if (askerIndex != 0) {
        _botTimer?.cancel();
        _botTimer = Timer(Duration(seconds: 2), () => _runBotTurn());
      }
      
    } else {
      // FAIL: Go Fish
      _broadcast("CHAT", {
        "sender": targetIndex == 0 ? "You" : "P${targetIndex + 1}", 
        "message": "GO FISH! 🐟"
      });
      
      _processGoFish(askerIndex, rank);
    }
  }
  
  void _processGoFish(int playerIndex, String askedRank) {
    if (_deckService.remainingCards > 0) {
       List<CardModel> drawn = _deckService.drawCards(1);
       CardModel card = drawn.first;
       _hands[playerIndex].add(card);
       _checkBooks(playerIndex);
       
       _broadcastUpdate();

       if (card.rank == askedRank) {
          _broadcast("CHAT", {
            "sender": "System", 
            "message": "${playerIndex == 0 ? "You" : "P${playerIndex+1}"} fished the ${card.rank}! Go again."
          });
          if (playerIndex != 0) {
             _botTimer?.cancel();
             _botTimer = Timer(Duration(seconds: 2), () => _runBotTurn());
          }
          return;
       }
    } else {
      _broadcast("CHAT", {"sender": "System", "message": "Pond is empty!"});
    }

    _advanceTurn();
  }

  void _advanceTurn() {
    if (_isGameOver) return;
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _playerCount;
    
    if (_hands[_currentPlayerIndex].isEmpty) {
        if (_deckService.remainingCards > 0) {
           List<CardModel> draw = _deckService.drawCards(1);
           _hands[_currentPlayerIndex].addAll(draw);
           _broadcast("CHAT", {"sender": "System", "message": "Player ${_currentPlayerIndex+1} drew a card (Empty Hand)"});
           _broadcastUpdate();
        } else {
           bool allEmpty = _hands.every((h) => h.isEmpty);
           if (allEmpty) {
             _endGame();
             return;
           }
        }
    }

    _broadcastTurn();

    if (_currentPlayerIndex != 0) {
      _botTimer?.cancel();
      _botTimer = Timer(Duration(seconds: 2), () => _runBotTurn());
    }
  }

  void _runBotTurn() {
    int botIdx = _currentPlayerIndex;
    if (_isGameOver) return;
    if (_hands[botIdx].isEmpty) { _advanceTurn(); return; }

    List<CardModel> hand = _hands[botIdx];
    String rankToAsk = hand[Random().nextInt(hand.length)].rank;
    
    List<int> validTargets = List.generate(_playerCount, (i) => i)
        ..remove(botIdx)
        ..removeWhere((i) => _hands[i].isEmpty);
    
    if (validTargets.isEmpty) { _advanceTurn(); return; }
    int target = validTargets[Random().nextInt(validTargets.length)];

    for (var card in hand) {
      for (int t in validTargets) {
        if (_botMemory[t]?.contains(card.rank) ?? false) {
          rankToAsk = card.rank;
          target = t;
          break;
        }
      }
    }

    _broadcast("CHAT", {"sender": "P${botIdx+1}", "message": "Asking P${target+1} for ${rankToAsk}s..."});
    Timer(Duration(milliseconds: 1000), () => _processAsk(botIdx, target, rankToAsk));
  }

  void _checkBooks(int playerIndex) {
    Map<String, int> counts = {};
    for (var c in _hands[playerIndex]) {
      counts[c.rank] = (counts[c.rank] ?? 0) + 1;
    }

    counts.forEach((rank, count) {
      if (count == 4) {
        _hands[playerIndex].removeWhere((c) => c.rank == rank);
        _books[playerIndex]++;
        _broadcast("CHAT", {
          "sender": "System", 
          "message": "${playerIndex == 0 ? "You" : "P${playerIndex+1}"} made a Book of ${rank}s!"
        });
      }
    });
    
    int totalBooks = _books.reduce((a, b) => a + b);
    if (totalBooks == 13 || (_deckService.remainingCards == 0 && _hands.every((h) => h.isEmpty))) {
       _endGame();
    }
  }
  
  void _updateMemory(int playerIndex, String rank) {
    if (!_botMemory.containsKey(playerIndex)) _botMemory[playerIndex] = {};
    _botMemory[playerIndex]!.add(rank);
  }

  void _endGame() {
    int maxBooks = _books.reduce(max);
    List<int> winners = [];
    for(int i=0; i<_books.length; i++) if(_books[i] == maxBooks) winners.add(i);
    
    String msg = winners.contains(0) ? "You Won!" : "Player ${winners.first + 1} Wins!";
    if (winners.length > 1) msg = "It's a Tie!";
    
    _isGameOver = true;
    _botTimer?.cancel();
    _broadcast("GAME_OVER", msg);
  }

  void _broadcastUpdate() {
    _streamController.add({
      "type": "DEAL_HAND",
      "data": _hands[0].map((e) => e.toJson()).toList()
    });
    _streamController.add({
      "type": "GO_FISH_STATE",
      "data": {
        "books": _books,
        "handSizes": _hands.map((h) => h.length).toList(),
        "pondSize": _deckService.remainingCards
      }
    });
  }
  
  void _broadcast(String type, dynamic data) {
    if (!_streamController.isClosed) _streamController.add({"type": type, "data": data});
  }
  
  void _broadcastTurn() {
      _streamController.add({"type": "TURN_UPDATE", "data": {"playerIndex": _currentPlayerIndex}});
  }

  void dispose() {
    _botTimer?.cancel();
    _streamController.close();
  }
}