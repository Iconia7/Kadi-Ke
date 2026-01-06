import 'dart:async';
import 'dart:math';
import 'deck_service.dart';

class AiBot {
  final int id;
  List<CardModel> hand = [];
  AiBot(this.id);

  BotMove chooseMove(CardModel topCard, String? forcedSuit, int bombStack, bool waitingForAnswer, String? jokerConstraint) {
    List<int> playableIndices = [];
    for (int i = 0; i < hand.length; i++) {
      if (_isPlayable(hand[i], topCard, forcedSuit, bombStack, waitingForAnswer, jokerConstraint)) {
        playableIndices.add(i);
      }
    }

    if (playableIndices.isEmpty) return BotMove(-1); 
    
    int selectedIndex = playableIndices.first;
    for (int idx in playableIndices) {
      if (hand[idx].rank == topCard.rank) {
        selectedIndex = idx;
        break;
      }
    }

    CardModel card = hand[selectedIndex];
    String? reqSuit;
    String? reqRank;

    if (card.rank == 'ace' && bombStack == 0) {
      reqSuit = _getMostFrequentSuit();
      if (card.suit == 'spades') reqRank = _getMostFrequentRank();
    }

    return BotMove(selectedIndex, requestedSuit: reqSuit, requestedRank: reqRank);
  }

  bool _isPlayable(CardModel card, CardModel topCard, String? forcedSuit, int bombStack, bool waitingForAnswer, String? jokerConstraint) {
    if (jokerConstraint != null) {
      bool isBomb = ['2', '3', 'joker'].contains(card.rank);
      if (isBomb) return true;
      String cardColor = (card.suit == 'hearts' || card.suit == 'diamonds' || card.suit == 'red') ? 'red' : 'black';
      return cardColor == jokerConstraint;
    }

    if (['2', '3', 'joker'].contains(card.rank)) return true;
    
    if (bombStack > 0) {
      if (card.rank == 'ace') return true;
      if (card.rank == 'king') return true;
      if (card.rank == 'jack') return true;
      return false;
    }

    if (waitingForAnswer) {
       if (card.suit != topCard.suit) return false;
       return ['4','5','6','7','9','10'].contains(card.rank);
    }

    if (forcedSuit != null) {
      if (card.rank == 'ace') return true;
      return card.suit == forcedSuit;
    }
    
    if (card.rank == 'ace') return true;
    return card.suit == topCard.suit || card.rank == topCard.rank;
  }

  String _getMostFrequentSuit() {
    Map<String, int> counts = {'hearts':0, 'diamonds':0, 'clubs':0, 'spades':0};
    for (var c in hand) counts[c.suit] = (counts[c.suit] ?? 0) + 1;
    var sorted = counts.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  String _getMostFrequentRank() {
    Map<String, int> counts = {};
    for (var c in hand) counts[c.rank] = (counts[c.rank] ?? 0) + 1;
    var sorted = counts.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return '7'; 
    return sorted.first.key;
  }
}

class BotMove {
  final int cardIndex;
  final String? requestedSuit;
  final String? requestedRank;

  BotMove(this.cardIndex, {this.requestedSuit, this.requestedRank});
}

class LocalGameEngine {
  final DeckService _deckService = DeckService();
  final StreamController<Map<String, dynamic>> _streamController = StreamController.broadcast();
  
  Stream<Map<String, dynamic>> get gameStream => _streamController.stream;

  List<CardModel> _playerHand = [];
  List<AiBot> _bots = [];
  CardModel? _topCard;
  int _currentPlayerIndex = 0; 
  int _direction = 1; 
  int _bombStack = 0;
  bool _waitingForAnswer = false;
  String? _forcedSuit;
  String? _forcedRank;
  List<bool> _hasSaidMap = []; 
  List<CardModel> _discardPile = [];
  String? _jokerColorConstraint; // 'red' or 'black'
  
  Timer? _botTimer; 

void start(int aiCount, String difficulty, {int decks = 1}) async {
    _deckService.initializeDeck(decks: decks); 
    _deckService.shuffle();

    // ✅ VITAL FIX: Wait 500ms before sending data.
    // This ensures the GameScreen has finished building and listening to the stream.
    await Future.delayed(Duration(milliseconds: 500));

    _playerHand = _deckService.drawCards(4);
    _broadcast("DEAL_HAND", _playerHand.map((e) => e.toJson()).toList());

    _bots = List.generate(aiCount, (index) {
      var bot = AiBot(index + 1);
      bot.hand = _deckService.drawCards(4);
      return bot;
    });
    
    _hasSaidMap = List.filled(aiCount + 1, false);
    _discardPile.clear();
    _jokerColorConstraint = null;

    _topCard = _deckService.drawCards(1).first;
    while (['2','3','8','jack','queen','king','ace','joker'].contains(_topCard!.rank)) {
       _deckService.addCardToBottom(_topCard!);
       _topCard = _deckService.drawCards(1).first;
    }

    _broadcast("UPDATE_TABLE", _topCard!.toJson());
    _broadcast("PLAYER_COUNT_UPDATE", aiCount + 1);

    _bombStack = 0;
    _currentPlayerIndex = 0; 
    _advanceTurn(reset: true); 
  }

  void playCard(int cardIndex, {String? requestedSuit, String? requestedRank, bool saidNikoKadi = false}) {
    if (_currentPlayerIndex != 0) return; 
    if (saidNikoKadi) _hasSaidMap[0] = true;
    _processMove(0, _playerHand, cardIndex, reqSuit: requestedSuit, reqRank: requestedRank);
  }

  void pickCard() {
    if (_currentPlayerIndex != 0) return;
    _processPick(0, _playerHand);
  }

  bool _isWinningCard(CardModel card) {
    const nonWinningRanks = ['2', '3', '8', 'jack', 'queen', 'king', 'joker'];
    return !nonWinningRanks.contains(card.rank);
  }

  void _drawCardsForHand(List<CardModel> hand, int count) {
    if (_deckService.remainingCards >= count) {
      hand.addAll(_deckService.drawCards(count));
    } else {
      hand.addAll(_deckService.drawCards(_deckService.remainingCards));
      int needed = count - _deckService.remainingCards; 
      
      if (_discardPile.isNotEmpty) {
        _deckService.addCards(_discardPile);
        _discardPile.clear();
        _deckService.shuffle();
        _broadcast("CHAT", {"sender": "System", "message": "Deck Reshuffled!"});
        hand.addAll(_deckService.drawCards(needed));
      }
    }
  }

  void _advanceTurn({int skip = 0, bool reset = false}) {
    if (reset) {
      _currentPlayerIndex = 0;
    } else {
      int totalPlayers = _bots.length + 1;
      int steps = 1 + skip;
      _currentPlayerIndex = (_currentPlayerIndex + (_direction * steps)) % totalPlayers;
      if (_currentPlayerIndex < 0) _currentPlayerIndex += totalPlayers;
    }

    _broadcastTurn();

    if (_currentPlayerIndex > 0) {
      _botTimer?.cancel();
      _botTimer = Timer(Duration(seconds: 1), () => _runBotTurn());
    }
  }

  void _runBotTurn() {
    int botIndex = _currentPlayerIndex - 1;
    if (botIndex < 0 || botIndex >= _bots.length) return;

    AiBot bot = _bots[botIndex];
    BotMove move = bot.chooseMove(_topCard!, _forcedSuit, _bombStack, _waitingForAnswer, _jokerColorConstraint);

    if (move.cardIndex != -1) {
      bool sayNiko = false;
      if (bot.hand.length == 2) {
         sayNiko = Random().nextDouble() > 0.1; 
         if (sayNiko) {
            _hasSaidMap[_currentPlayerIndex] = true;
            _broadcast("CHAT", {"sender": "Bot ${bot.id}", "message": "Niko Kadi!"});
         }
      }
      _processMove(_currentPlayerIndex, bot.hand, move.cardIndex, reqSuit: move.requestedSuit, reqRank: move.requestedRank);
    } else {
      _processPick(_currentPlayerIndex, bot.hand);
    }
  }

bool _isValidMove(CardModel card) {
    // 1. Joker Constraint (Highest Priority)
    if (_jokerColorConstraint != null) {
      bool isBomb = ['2', '3', 'joker'].contains(card.rank);
      if (isBomb) return true;
      String cardColor = (card.suit == 'hearts' || card.suit == 'diamonds' || card.suit == 'red') ? 'red' : 'black';
      return cardColor == _jokerColorConstraint;
    }

    // 2. Bomb Stack Logic
    if (_bombStack > 0) {
      if (['2', '3', 'joker'].contains(card.rank)) return true; // Stack
      if (card.rank == 'ace') return true; // Block
      if (card.rank == 'king') return true; // Return
      if (card.rank == 'jack') return true; // Pass
      return false;
    }

    // 3. Question/Answer Logic (SELF-ANSWERING & CHAINING)
    if (_waitingForAnswer) {
       // Case A: Chaining Questions (e.g., Q -> Q or Q -> 8)
       // You can play another Question if it matches Suit OR Rank
       if (card.rank == 'queen' || card.rank == '8') {
           return card.suit == _topCard!.suit || card.rank == _topCard!.rank;
       }

       // Case B: Answering (e.g., Q -> 5)
       // You must play a standard card (4-10) matching the SUIT
       if (['4','5','6','7','9','10'].contains(card.rank)) {
           return card.suit == _topCard!.suit;
       }

       // You cannot play Power cards (2, 3, A, K, J) to answer a Question
       return false; 
    }

    // 4. Ace Counter-Play (CRITICAL: Ace breaks any lock)
    if (card.rank == 'ace') return true;

    // 5. Forced Suit/Rank (The Lock)
    if (_forcedRank != null && _forcedSuit != null) {
       return card.rank == _forcedRank && card.suit == _forcedSuit;
    }
    if (_forcedSuit != null) {
      return card.suit == _forcedSuit;
    }

    // 6. Standard Play
    return card.suit == _topCard!.suit || card.rank == _topCard!.rank || ['2','3','joker'].contains(card.rank);
  }

  void _processMove(int playerIndex, List<CardModel> hand, int cardIndex, {String? reqSuit, String? reqRank}) {
    CardModel card = hand[cardIndex];

    if (!_isValidMove(card)) {
        if (playerIndex > 0) _processPick(playerIndex, hand); // Bot fallback
        else _broadcast("ERROR", "Invalid Move!");
        return; 
    }

    // --- EXECUTE MOVE ---
    hand.removeAt(cardIndex);
    if (_topCard != null) _discardPile.add(_topCard!);
    _topCard = card;
    if (_jokerColorConstraint != null) _jokerColorConstraint = null;

    // --- BOMB CALCULATION ---
    bool isBomb = ['2', '3', 'joker'].contains(card.rank);
    if (card.rank == '2') _bombStack += 2;
    else if (card.rank == '3') _bombStack += 3;
    else if (card.rank == 'joker') _bombStack += 5;

    // --- ACE LOGIC ---
    if (card.rank == 'ace') {
       if (_bombStack > 0 && !isBomb) {
          _bombStack = 0; 
          _forcedSuit = null; 
          _forcedRank = null;
          _broadcast("CHAT", {"sender": "System", "message": "Bomb Blocked!"});
       } else {
          _bombStack = 0; 
          
          // SPECIAL: Ace of Spades Strategy
          if (card.suit == 'spades' && hand.length == 1) {
             CardModel winningCard = hand[0]; // The last card you hold
             _forcedSuit = winningCard.suit;
             _forcedRank = winningCard.rank;
             _broadcast("CHAT", {"sender": "System", "message": "🔒 LOCKED: ${_forcedRank} of ${_forcedSuit}"});
          } 
          // Normal Ace Request
          else {
             _forcedSuit = reqSuit ?? card.suit;
             _forcedRank = reqRank;
             
             String msg = "New Suit: $_forcedSuit";
             if (_forcedRank != null) msg += " | Target: $_forcedRank";
             _broadcast("CHAT", {"sender": "System", "message": msg});
          }
       }
    } else {
       // Clear constraints if non-Ace played (unless inside a Question Chain, logic handles suit match automatically)
       if (_forcedSuit != null) { _forcedSuit = null; _forcedRank = null; }
    }

    // --- NIKO KADI CHECK ---
    bool isWinningHand = hand.isNotEmpty && hand.every((c) => c.rank == hand[0].rank);
    if (hand.length == 1) {
      if (!_hasSaidMap[playerIndex]) {
        if (_isWinningCard(hand[0])) {
           if (playerIndex == 0) _broadcast("CHAT", {"sender": "Referee", "message": "Forgot Niko Kadi! Penalty!"});
           _processPick(playerIndex, hand, penaltyAmount: 2);
           return; 
        }
      }
    }
    if (hand.length > 1 && !isWinningHand) _hasSaidMap[playerIndex] = false;

    // --- TURN FLOW LOGIC ---
    bool turnEnds = true;
    int skip = 0;

    // 1. Question Logic (Q & 8) - Player retains turn
    if (card.rank == 'queen' || card.rank == '8') {
      _waitingForAnswer = true;
      turnEnds = false; // YOU keep the turn
      if (playerIndex == 0) _broadcast("CHAT", {"sender": "System", "message": "Question placed! Answer or Chain."});
    }
    // 2. Answering Logic - Turn ends if valid answer played
    else if (_waitingForAnswer) {
      _waitingForAnswer = false;
      turnEnds = true;
      if (playerIndex == 0) _broadcast("CHAT", {"sender": "System", "message": "Question Answered."});
    }
    // 3. King (Reverse/Return)
    else if (card.rank == 'king') {
       _direction *= -1; 
       if (_bombStack > 0) _broadcast("CHAT", {"sender": "System", "message": "Bomb Returned!"});
    }
    // 4. Jack (Skip/Pass)
    else if (card.rank == 'jack') {
       if (_bombStack > 0) skip = 0; 
       else {
          int totalPlayers = _bots.length + 1;
          if (totalPlayers > 2) skip = 1;
       }
    }
    
    // 5. Multi-drop (Standard) - Only if not holding turn for Question
    if (turnEnds && skip == 0 && hand.isNotEmpty) {
       if (hand.any((c) => c.rank == card.rank)) {
          turnEnds = false;
          if (playerIndex == 0) _broadcast("CHAT", {"sender": "System", "message": "Multi-drop: Play another ${card.rank} or Pick"});
       }
    }

    _broadcastUpdate(playerIndex, hand);

    // --- WIN CONDITION ---
    if (hand.isEmpty) {
      bool powerCardFinish = ['2','3','joker','king','jack','queen','8'].contains(card.rank);
      // Explicitly check Ace cannot win (unless it was part of a combo that ended on an Answer, which is handled by valid move)
      if (card.rank == 'ace') powerCardFinish = true;

      bool anyoneElseCardless = _bots.any((b) => b.hand.isEmpty) || (playerIndex != 0 && _playerHand.isEmpty);
      
      if (powerCardFinish || anyoneElseCardless) {
         if (powerCardFinish) _broadcast("CHAT", {"sender": "System", "message": "Cannot win with Power Card!"});
         else _broadcast("CHAT", {"sender": "System", "message": "Win Blocked by Cardless Player!"});
         _broadcastUpdate(playerIndex, hand);
         if (turnEnds) _advanceTurn(skip: skip);
         return;
      } else {
        _broadcast("GAME_OVER", "Player ${playerIndex == 0 ? 'You' : 'Bot $playerIndex'} Wins!");
        return;
      }
    }

    if (turnEnds) {
      _advanceTurn(skip: skip);
    } else {
      _broadcastTurn(); 
      if (playerIndex > 0) {
         _botTimer?.cancel();
         _botTimer = Timer(Duration(milliseconds: 800), () => _runBotTurn());
      }
    }
  }

  void _processPick(int playerIndex, List<CardModel> hand, {int penaltyAmount = 0}) {
    int count = penaltyAmount > 0 ? penaltyAmount : ((_bombStack > 0) ? _bombStack : 1);
    
    if (_bombStack > 0 && _topCard != null && _topCard!.rank == 'joker') {
      if (_topCard!.suit == 'red') _jokerColorConstraint = 'red';
      else if (_topCard!.suit == 'black') _jokerColorConstraint = 'black';
      _broadcast("CHAT", {"sender": "System", "message": "Next player must match color: $_jokerColorConstraint"});
    }

    _drawCardsForHand(hand, count);
    
    // RESET STATES
    _bombStack = 0;
    _forcedSuit = null;
    _forcedRank = null;
    
    // If you picked while trying to answer/chain, the question is voided for the next person
    if (_waitingForAnswer) {
        _waitingForAnswer = false; 
    }
    
    _hasSaidMap[playerIndex] = false; 

    _broadcastUpdate(playerIndex, hand);
    _advanceTurn();
  }

  void _broadcastUpdate(int playerIndex, List<CardModel> hand) {
     if (playerIndex == 0) _broadcast("DEAL_HAND", hand.map((e) => e.toJson()).toList());
     _broadcast("UPDATE_TABLE", _topCard!.toJson());
  }

  void _broadcast(String type, dynamic data) {
    if (!_streamController.isClosed) _streamController.add({"type": type, "data": data});
  }

  void _broadcastTurn() {
    _broadcast("TURN_UPDATE", {
      "playerIndex": _currentPlayerIndex,
      "bombStack": _bombStack,
      "waitingForAnswer": _waitingForAnswer,
      "jokerColorConstraint": _jokerColorConstraint,
    });
  }

  void dispose() {
    _botTimer?.cancel();
    _streamController.close();
  }
}