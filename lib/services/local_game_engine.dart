import 'dart:async';
import 'dart:math';
import 'deck_service.dart';

class AiBot {
  final int id;
  final String difficulty; // 'easy', 'medium', 'hard'
  List<CardModel> hand = [];
  
  AiBot(this.id, this.difficulty);

  BotMove chooseMove(CardModel topCard, String? forcedSuit, String? forcedRank, int bombStack, bool waitingForAnswer, String? jokerConstraint) {
    List<int> playableIndices = [];
    for (int i = 0; i < hand.length; i++) {
      if (_isPlayable(hand[i], topCard, forcedSuit, forcedRank, bombStack, waitingForAnswer, jokerConstraint)) {
        playableIndices.add(i);
      }
    }

    if (playableIndices.isEmpty) return BotMove(-1); 
    
    // DIFFICULTY LOGIC
    int selectedIndex = playableIndices.first;
    Random rnd = Random();

    // EASY: 30% chance to pick a random valid card instead of optimal (simulates confusion)
    if (difficulty == 'easy' && rnd.nextDouble() < 0.3) {
       selectedIndex = playableIndices[rnd.nextInt(playableIndices.length)];
    }
    // MEDIUM: Tries to match Rank (Defensive) or Suit
    else if (difficulty == 'medium') {
       // Prefer matching Rank to keep Suit options open
       var rankMatches = playableIndices.where((i) => hand[i].rank == topCard.rank).toList();
       if (rankMatches.isNotEmpty) selectedIndex = rankMatches.first;
       else selectedIndex = playableIndices.first; // Default to first valid
    }
    // HARD: Optimal Strategy
    else if (difficulty == 'hard') {
       // 1. If Bomb Stack > 0, MUST block or return if possible (filtered by _isPlayable but prioritized here)
       // 2. Save Power Cards (Aces/Kings) for later unless necessary
       // 3. Chain Questions if possible
       
       // Simple heuristic: Try to keep 'Ace' for last if possible, unless blocking bomb
       playableIndices.sort((a, b) {
          int scoreA = _evalCard(hand[a], topCard);
          int scoreB = _evalCard(hand[b], topCard);
          return scoreB.compareTo(scoreA); // Descending score
       });
       selectedIndex = playableIndices.first;
    }

    CardModel card = hand[selectedIndex];
    String? reqSuit;
    String? reqRank;

    if (card.rank == 'ace' && bombStack == 0) {
      reqSuit = _getMostFrequentSuit();
      // Hard bots lock Ace of Spades intelligently
      if (difficulty == 'hard' && card.suit == 'spades' && hand.length == 1) {
         reqRank = card.rank; // Self-lock (should be winning card, but logic implies we just played it)
         // Actually, if we play Ace Spades as last card, we win instantly usually, unless blocked.
         // Logic for locking usually happens if we have 1 card LEFT (which is this one).
         // Wait, if hand.length == 1 and we play it, hand is empty. Game Over.
         // Lock is useful if we *don't* win yet (e.g. Ace prevents win?). 
         // Actually standard rule: Ace Spades lock happens if you play it and have cards remaining? 
         // No, the code says `hand.length == 1` meaning the card being played IS the last one? 
         // "if (card.suit == 'spades' && hand.length == 1)" -> We are playing our last card.
         // So we win immediately. The lock is irrelevant unless valid move check prevents winning with power card?
         // Ah, Ace IS a power card. So we CANNOT win with it.
         // So we must pick. Thus the lock applies for the NEXT turn after we pick?
         // The engine logic handles the pick if we play power card as last.
      }
    }

    return BotMove(selectedIndex, requestedSuit: reqSuit, requestedRank: reqRank);
  }

  int _evalCard(CardModel c, CardModel top) {
     // Higher value = Better move
     int score = 0;
     if (c.suit == top.suit) score += 2;
     if (c.rank == top.rank) score += 3; // Rank match breaks suit flow (good)
     
     // Save Power Cards (UNLESS hand is getting small)
     // If hand is small, we should try to dump power cards so our LAST card is a standard card.
     if (hand.length > 3) {
        if (c.rank == 'ace') score -= 5; 
        if (c.rank == '2' || c.rank == '3') score -= 2; 
     } else {
        // Hand is small, DUMP power cards now!
        if (['2','3','8','jack','queen','king','ace','joker'].contains(c.rank)) score += 10;
     }
     
     // Dump non-power
     if (!['2','3','8','jack','queen','king','ace','joker'].contains(c.rank)) score += 5;

     return score;
  }
  
  // ignore: unused_element
  bool _isPlayable(CardModel card, CardModel topCard, String? forcedSuit, String? forcedRank, int bombStack, bool waitingForAnswer, String? jokerConstraint) {
    // 1. Joker Constraint (Highest Priority)
    if (jokerConstraint != null) {
      bool isBomb = ['2', '3', 'joker'].contains(card.rank);
      if (isBomb) return true;
      String cardColor = (card.suit == 'hearts' || card.suit == 'diamonds' || card.suit == 'red') ? 'red' : 'black';
      return cardColor == jokerConstraint;
    }

    // 2. Bomb Overrides (Bomb can be played on ANY suit/rank/constraint/lock)
    if (['2', '3', 'joker'].contains(card.rank)) return true;

    // 3. Bomb Stack Logic
    if (bombStack > 0) {
      // Stack already handled by #2
      if (card.rank == 'ace') return true; // Block
      if (card.rank == 'king') return true; // Return
      if (card.rank == 'jack') return true; // Pass
      return false;
    }

    // 4. Question/Answer Logic (CRITICAL FIX: Add chaining support)
    if (waitingForAnswer) {
       // Case A: Chaining Questions (e.g., Q -> Q or Q -> 8)
       // Can play another Question if it matches Suit OR Rank
       if (card.rank == 'queen' || card.rank == '8') {
           return card.suit == topCard.suit || card.rank == topCard.rank;
       }

       // Case B: Answering (e.g., Q -> 5)
       // Must play standard card (4-10) matching the SUIT
       if (['4','5','6','7','9','10'].contains(card.rank)) {
           return card.suit == topCard.suit;
       }

       // Cannot play Power cards (A, K, J) to answer a Question (Bombs handled in #2)
       return false;
    }

    // 5. Ace Counter-Play (CRITICAL: Ace breaks any lock)
    if (card.rank == 'ace') return true;

    // 6. Forced Suit/Rank (Ace of Spades lock support)
    if (forcedRank != null && forcedSuit != null) {
       // Double lock: must match EXACT card
       return card.rank == forcedRank && card.suit == forcedSuit;
    }
    if (forcedSuit != null) {
      // Suit lock only
      return card.suit == forcedSuit;
    }
    
    // 7. Standard Play
    return card.suit == topCard.suit || card.rank == topCard.rank;
  }

  String _getMostFrequentSuit() {
    Map<String, int> counts = {'hearts':0, 'diamonds':0, 'clubs':0, 'spades':0};
    for (var c in hand) counts[c.suit] = (counts[c.suit] ?? 0) + 1;
    var sorted = counts.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
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
  String? _forcedRank; // For 'Ace' requests
  String? _jokerColorConstraint; // 'red' or 'black'
  int _cardsPlayedThisTurn = 0; // NEW: Multi-drop state
  List<bool> _hasSaidMap = []; 
  List<CardModel> _discardPile = [];
  
  Timer? _botTimer; 
  Map<String, dynamic> _rules = {'cardlessBlocker': true};

void start(int aiCount, String difficulty, {int decks = 1, Map<String, dynamic>? rules}) async {
    if (rules != null) _rules = rules;
    _deckService.initializeDeck(decks: decks); 
    _deckService.shuffle();

    // ✅ VITAL FIX: Wait 500ms before sending data.
    // This ensures the GameScreen has finished building and listening to the stream.
    await Future.delayed(Duration(milliseconds: 500));

    _playerHand = _deckService.drawCards(4);
    _broadcast("DEAL_HAND", _playerHand.map((e) => e.toJson()).toList());

    _bots = List.generate(aiCount, (index) {
      var bot = AiBot(index + 1, difficulty); // Pass difficulty
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



  void sayNikoKadi() {
    _hasSaidMap[0] = true;
    _broadcast("CHAT", {
      "sender": "You", 
      "message": "Niko Kadi!",
      "isSystem": false,
      "isNikoKadi": true,
      "playerIndex": 0
    });
  }

  void pickCard() {
    if (_currentPlayerIndex != 0) return;
    _processPick(0, _playerHand);
  }

  void passTurn() {
     if (_currentPlayerIndex != 0) return;
     if (_cardsPlayedThisTurn > 0) {
        _advanceTurn();
     }
  }

  bool _isWinningCard(CardModel card) {
    // Power Cards cannot win: 2, 3, 8, J, Q, K, A, Joker
    const nonWinningRanks = ['2', '3', '8', 'jack', 'queen', 'king', 'ace', 'joker'];
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
      
      _cardsPlayedThisTurn = 0; // Reset for next/current player
      
      _currentPlayerIndex = (_currentPlayerIndex + (_direction * steps)) % totalPlayers;
      if (_currentPlayerIndex < 0) _currentPlayerIndex += totalPlayers;
    }

    _broadcastTurn();

    // Always schedule bot turn if it's not player 0
    if (_currentPlayerIndex > 0) {
      print('Scheduling bot turn for player $_currentPlayerIndex');
      _botTimer?.cancel();
      _botTimer = Timer(Duration(seconds: 1), () {
        print('Bot timer fired for player $_currentPlayerIndex');
        _runBotTurn();
      });
    } else {
      print('Player turn: $_currentPlayerIndex');
    }
  }

  void _runBotTurn() {
    int botIndex = _currentPlayerIndex - 1;
    
    // Debug logging
    print('Bot turn triggered: currentPlayerIndex=$_currentPlayerIndex, botIndex=$botIndex, totalBots=${_bots.length}');
    
    if (botIndex < 0 || botIndex >= _bots.length) {
      print('ERROR: Invalid bot index! Advancing turn...');
      // Instead of returning silently, advance turn to prevent freeze
      _advanceTurn();
      return;
    }

    AiBot bot = _bots[botIndex];
    BotMove move = bot.chooseMove(_topCard!, _forcedSuit, _forcedRank, _bombStack, _waitingForAnswer, _jokerColorConstraint);

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
    // 1. Bomb Override: 2, 3, Joker always valid on ANY suit
    if (['2','3','joker'].contains(card.rank)) return true;

    // 2. Joker Constraint (Highest Priority if not bomb)
    if (_jokerColorConstraint != null) {
      String cardColor = (card.suit == 'hearts' || card.suit == 'diamonds' || card.suit == 'red') ? 'red' : 'black';
      return cardColor == _jokerColorConstraint;
    }

    // 3. Bomb Stack Defense
    if (_bombStack > 0) {
      // Stack (2, 3, Joker) already handled by #1
      // Defense: Ace, King, Jack are valid
      if (['ace','king','jack'].contains(card.rank)) return true;
      return false;
    }

    // 4. Question/Answer Logic (SELF-ANSWERING & CHAINING)
    if (_waitingForAnswer) {
       // Case A: Chaining Questions (e.g., Q -> Q or Q -> 8)
       if (card.rank == 'queen' || card.rank == '8') {
           return card.suit == _topCard!.suit || card.rank == _topCard!.rank;
       }
       // Case B: Answering (e.g., Q -> 5)
       if (['4','5','6','7','9','10'].contains(card.rank)) {
           return card.suit == _topCard!.suit;
       }
       return false; 
    }

    // 5. Ace Counter-Play
    if (card.rank == 'ace') return true;

    // 6. Forced Suit/Rank (The Lock)
    if (_forcedRank != null && _forcedSuit != null) {
       return card.rank == _forcedRank && card.suit == _forcedSuit;
    }
    if (_forcedRank != null) return card.rank == _forcedRank;
    if (_forcedSuit != null) return card.suit == _forcedSuit;

    // 7. Standard Play
    return card.suit == _topCard!.suit || card.rank == _topCard!.rank;
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

    _cardsPlayedThisTurn++;

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
          
          // LOKI/LOCK Blocking Logic (New)
          if (_forcedSuit != null && _forcedRank != null) {
             if (_cardsPlayedThisTurn == 1) {
                // One-Ace Block: Keep what the player requested
                _forcedSuit = reqSuit;
                _forcedRank = reqRank;
                
                String msg = "Partial Block!";
                if (reqSuit != null && reqRank == null) msg = "Blocking Rank! Suit ${reqSuit.toUpperCase()} continues.";
                if (reqRank != null && reqSuit == null) msg = "Blocking Suit! Rank ${reqRank} continues.";
                _broadcast("CHAT", {"sender": "System", "message": msg});
             } else {
                // Two-Ace Block: Clear everything
                _forcedSuit = null;
                _forcedRank = null;
                _broadcast("CHAT", {"sender": "System", "message": "FULL BLOCK!"});
             }
          } else {
             // Standard Ace Logic / Spades Lock
             if (card.suit == 'spades' && hand.length == 1) {
                CardModel winningCard = hand[0]; 
                _forcedSuit = winningCard.suit;
                _forcedRank = winningCard.rank;
                _broadcast("CHAT", {"sender": "System", "message": "🔒 LOCKED: ${_forcedRank} of ${_forcedSuit}"});
             } else {
                _forcedSuit = reqSuit ?? card.suit;
                _forcedRank = reqRank;
                _broadcast("CHAT", {"sender": "System", "message": "Request: ${_forcedSuit ?? _forcedRank}"});
             }
          }
       }
    } else {
       // If playing a Bomb, we override/clear Requests
       if (isBomb) {
           _forcedSuit = null;
           _forcedRank = null;
       }
       // If playing valid card into Request, usually we clear it? 
       // User says persistence. But if I play the requested suit, the "Top Card" now IS that suit.
       // So Standard Play rules will naturally enforce it for the next player anyway.
       // Explicitly clearing it prevents "Ghost constraints".
       else if (_forcedSuit != null || _forcedRank != null) {
          _forcedSuit = null;
          _forcedRank = null;
       }
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
    
    // 5. Multi-drop (Standard & Bombs)
    if (turnEnds && skip == 0 && hand.isNotEmpty) {
       bool canMultiDrop = hand.any((c) => c.rank == card.rank);
       bool isBombChain = isBomb && hand.any((c) => ['2', '3', 'joker'].contains(c.rank));
       
       if (canMultiDrop || isBombChain) {
          turnEnds = false;
          String msg = canMultiDrop ? "Multi-drop: Play another ${card.rank} or Pick" : "Bomb Chain! Play another Bomb or Pick";
          if (playerIndex == 0) _broadcast("CHAT", {"sender": "System", "message": msg});
       }
    }

    _broadcastUpdate(playerIndex, hand);

    // --- WIN CHECK ---
     if (hand.isEmpty) {
        bool powerCardFinish = ['2','3','8','jack','queen','king','ace','joker'].contains(card.rank);
        
        if (powerCardFinish) {
           _broadcast("CHAT", {"sender": "System", "message": "Cannot win with Power Card! Pick 1."});
           _processPick(playerIndex, hand, penaltyAmount: 1); // Force pick
           return;
         } else {
           // --- OPTIONAL CARDLESS BLOCKER RULE ---
           if (_rules['cardlessBlocker'] == true) {
             bool anyoneElseCardless = false;
             // Check player
             if (playerIndex != 0 && _playerHand.isEmpty) anyoneElseCardless = true;
             // Check bots
             for (int i = 0; i < _bots.length; i++) {
               int botIdx = i + 1;
               if (playerIndex != botIdx && _bots[i].hand.isEmpty) {
                 anyoneElseCardless = true;
                 break;
               }
             }

             if (anyoneElseCardless) {
               _broadcast("CHAT", {"sender": "Referee", "message": "Someone else is cardless! Win blocked by House Rule."});
               _drawCardsForHand(hand, 1); // Reduced penalty to 1 so they don't get stuck forever
               if (turnEnds) _advanceTurn(skip: skip);
               return;
             }
           }

           _broadcast("GAME_OVER", playerIndex == 0 ? "You Win!" : "Bot ${playerIndex} Wins!");
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
    // Only clear constraints if this was a Bomb/Penalty pick
    if (_bombStack > 0) {
        _forcedSuit = null;
        _forcedRank = null;
    }
    
    _bombStack = 0;
    
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
      "direction": _direction,
      "forcedSuit": _forcedSuit,
      "forcedRank": _forcedRank,
      "cardsPlayedThisTurn": _cardsPlayedThisTurn,
    });
  }

  void dispose() {
    _botTimer?.cancel();
    _streamController.close();
  }
}