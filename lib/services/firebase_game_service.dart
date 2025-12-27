import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'deck_service.dart';

class FirebaseGameService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final StreamController<Map<String, dynamic>> _gameStreamController = StreamController.broadcast();

  StreamSubscription<DocumentSnapshot>? _gameSubscription;
  StreamSubscription<QuerySnapshot>? _messageSubscription;

  Stream<Map<String, dynamic>> get gameStream => _gameStreamController.stream;
  String? _currentGameCode;
  String? _myUserId;
  
  static final FirebaseGameService _instance = FirebaseGameService._internal();
  factory FirebaseGameService() => _instance;
  FirebaseGameService._internal();

  String get currentUserId => _myUserId ?? "unknown";

  Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      if (_auth.currentUser == null) {
        UserCredential user = await _auth.signInAnonymously();
        _myUserId = user.user?.uid;
      } else {
        _myUserId = _auth.currentUser?.uid;
      }
    } catch (e) {
      print("Auth Error: $e");
    }
  }

  // --- CLIENT METHODS ---

  Future<String> createGame(String playerName, String gameType) async {
    if (_myUserId == null) await initialize();
    leaveGame(); 
    
    String code = _generateRoomCode();
    _currentGameCode = code;

    await _db.collection('games').doc(code).set({
      'code': code,
      'hostId': _myUserId,
      'gameType': gameType,
      'status': 'waiting', 
      'createdAt': FieldValue.serverTimestamp(),
      'players': [{
        'id': _myUserId,
        'name': playerName,
        'isHost': true,
      }],
      'hands': {}, 
      'table': {}, 
      'books': [], 
      'turnIndex': 0,
      'direction': 1,
      'bombStack': 0,
      'waitingForAnswer': false,
      'jokerColorConstraint': null // NEW STATE
    });

    _listenToGame(code);
    return code;
  }

  Future<String?> joinGame(String code, String playerName, String expectedGameType) async {
    if (_myUserId == null) await initialize();
    leaveGame(); 
    
    String cleanCode = code.trim().toUpperCase();
    _currentGameCode = cleanCode;

    try {
      DocumentReference gameRef = _db.collection('games').doc(cleanCode);
      DocumentSnapshot doc = await gameRef.get();

      if (!doc.exists) return "Game Not Found";
      
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      String roomGameType = data['gameType'] ?? 'kadi';
      if (roomGameType != expectedGameType) {
        return "Wrong Game Mode! This is a ${roomGameType.toUpperCase()} room.";
      }
      
      if (data['status'] != 'waiting') return "Game Already Started";

      List players = data['players'] ?? [];
      
      if (!players.any((p) => p['id'] == _myUserId)) {
        if (players.length >= 10) return "Room is Full (Max 10)";
        players.add({
          'id': _myUserId,
          'name': playerName,
          'isHost': false,
        });
        await gameRef.update({'players': players});
      }

      _listenToGame(cleanCode);
      return null; 
    } catch (e) {
      return "Connection Error";
    }
  }

  void _listenToGame(String code) {
    _gameSubscription?.cancel();
    _messageSubscription?.cancel();

    _gameSubscription = _db.collection('games').doc(code).snapshots().listen((snapshot) {
      if (!snapshot.exists) return;
      
      Map<String, dynamic> data = snapshot.data()!;
      String status = data['status'];
      List players = data['players'];
      
      _gameStreamController.add({
        'type': 'PLAYER_INFO',
        'data': {
          'players': players,
          'myId': _myUserId
        }
      });

      if (status == 'playing') {
        Map hands = data['hands'] ?? {};
        if (hands.containsKey(_myUserId)) {
          List myCards = (hands[_myUserId] as List).map((c) => CardModel.fromJson(c)).toList();
          _gameStreamController.add({
            'type': 'DEAL_HAND',
            'data': myCards.map((c) => c.toJson()).toList()
          });
        }

        if (data['table'] != null && data['table'].isNotEmpty) {
          _gameStreamController.add({
            'type': 'UPDATE_TABLE',
            'data': data['table']
          });
        }
        
        if (data['gameType'] == 'gofish' && data['books'] != null) {
          _gameStreamController.add({
            'type': 'GO_FISH_STATE',
            'data': {'books': data['books']}
          });
        }

        if (data['turnIndex'] != null) {
          _gameStreamController.add({
            'type': 'TURN_UPDATE',
            'data': {
              'playerIndex': data['turnIndex'],
              'bombStack': data['bombStack'] ?? 0,
              'waitingForAnswer': data['waitingForAnswer'] ?? false, 
              'jokerColorConstraint': data['jokerColorConstraint'], // Listen for constraint
            }
          });
        }
      }
      
      if (data['winner'] != null && data['winner'] != "") {
        _gameStreamController.add({
          'type': 'GAME_OVER',
          'data': "${data['winner']} Wins!"
        });
      }
    });

    _messageSubscription = _db.collection('games').doc(code).collection('messages')
      .orderBy('timestamp', descending: false)
      .limitToLast(1)
      .snapshots().listen((qs) {
        if (qs.docs.isNotEmpty) {
          var msg = qs.docs.first.data();
          _gameStreamController.add({
            'type': 'CHAT',
            'data': {'sender': msg['sender'], 'message': msg['text']}
          });
        }
      });
  }

  Future<void> sendAction(String type, Map<String, dynamic> data) async {
    if (_currentGameCode == null) return;
    await _db.collection('games').doc(_currentGameCode).collection('actions').add({
      'type': type,
      'playerId': _myUserId,
      'data': data,
      'timestamp': FieldValue.serverTimestamp()
    });
  }
  
  Future<void> restartGame() async {
     if (_currentGameCode == null) return;
     sendAction("START_GAME", {});
     await _db.collection('games').doc(_currentGameCode).update({'winner': ""});
  }

  void leaveGame() {
    _gameSubscription?.cancel();
    _messageSubscription?.cancel();
    _currentGameCode = null;
  }

  String _generateRoomCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }
}

class FirebaseHostEngine {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DeckService _deckService = DeckService();
  final String gameCode;
  
  StreamSubscription? _actionsSubscription;

  List<Map<String, dynamic>> _players = [];
  Map<String, List<CardModel>> _hands = {};
  CardModel? _topCard;
  int _currentPlayerIndex = 0;
  int _direction = 1;
  int _bombStack = 0;
  bool _waitingForAnswer = false;
  String? _forcedSuit;
  String? _forcedRank;
  Set<String> _nikoKadiDeclarations = {}; 
  
  String _gameType = 'kadi';
  List<int> _books = [];
  List<CardModel> _discardPile = []; 
  String? _jokerColorConstraint; // 'red' or 'black'

  FirebaseHostEngine(this.gameCode);

  void start() {
    _listenToActions();
  }
  
  void stop() {
    _actionsSubscription?.cancel();
  }

  void _listenToActions() {
    _actionsSubscription = _db.collection('games').doc(gameCode).collection('actions')
      .orderBy('timestamp')
      .snapshots()
      .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            var action = change.doc.data()!;
            _processAction(action['type'], action['playerId'], action['data'] ?? {});
            change.doc.reference.delete(); 
          }
        }
      });
  }

  void _processAction(String type, String playerId, Map<String, dynamic> data) {
    if (type == 'CHAT') {
      _sendSystemMessage(data['senderName'], data['message']);
      return;
    }
    
    if (type == 'START_GAME') {
      _db.collection('games').doc(gameCode).get().then((doc) {
        if (doc.exists) {
          _gameType = doc.data()!['gameType'] ?? 'kadi';
          _players = List<Map<String, dynamic>>.from(doc.data()!['players']);
          if (_players.isNotEmpty && playerId == _players[0]['id']) { 
             int decks = data['decks'] ?? 1;
             _handleStartGame(decks);
          }
        }
      });
      return;
    }

    if (_players.isEmpty) return; 
    
    String currentUserId = _players[_currentPlayerIndex]['id'];
    
    if (playerId != currentUserId) return; 

    if (_gameType == 'kadi') {
      if (type == 'PLAY_CARD') _handlePlayCard(playerId, data['cardIndex'], data);
      else if (type == 'PICK_CARD') _handlePickCard(playerId);
    } 
    else {
      if (type == 'ASK_CARD') {
        int targetIndex = data['targetIndex']; 
        String rank = data['rank'];
        _handleAskCard(playerId, targetIndex, rank); 
      }
    }
  }

  void _handleStartGame(int decks) {
     _deckService.initializeDeck(decks: decks);
     _deckService.shuffle();
     _currentPlayerIndex = 0;
     
     if (_gameType == 'kadi') {
        _startKadi();
     } else {
        _startGoFish();
     }
      
     _updateGameState("playing");
     _db.collection('games').doc(gameCode).update({'winner': ""}); 
     _sendSystemMessage("System", "Game Started: ${_gameType.toUpperCase()}");
  }
  
  void _startKadi() {
     _bombStack = 0;
     _direction = 1;
     _forcedSuit = null;
     _nikoKadiDeclarations.clear();
     _discardPile.clear(); 
     _jokerColorConstraint = null;
     
     for (var p in _players) _hands[p['id']] = _deckService.drawCards(4);
     
     do {
        if (_topCard != null) _deckService.addCardToBottom(_topCard!);
        _topCard = _deckService.drawCards(1).first;
     } while (['2','3','8','jack','queen','king','ace','joker'].contains(_topCard!.rank));
  }
  
  void _startGoFish() {
    _books = List.filled(_players.length, 0);
    int count = _players.length <= 3 ? 7 : 5;
    for (var p in _players) _hands[p['id']] = _deckService.drawCards(count);
    _topCard = CardModel(suit: 'back', rank: 'deck'); 
  }

  void _handleAskCard(String askerId, int targetIdx, String rank) {
    if (targetIdx < 0 || targetIdx >= _players.length) return;
    String targetId = _players[targetIdx]['id'];
    if (askerId == targetId) return; 

    List<CardModel> targetHand = _hands[targetId]!;
    List<CardModel> found = targetHand.where((c) => c.rank == rank).toList();

    if (found.isNotEmpty) {
      targetHand.removeWhere((c) => c.rank == rank);
      _hands[askerId]!.addAll(found);
      String askerName = _players[_currentPlayerIndex]['name'];
      String targetName = _players[targetIdx]['name'];
      _sendSystemMessage("System", "$askerName took ${found.length} $rank(s) from $targetName");
      _checkBooks(askerId);
      _updateGameState("playing");
    } else {
      _sendSystemMessage("System", "Go Fish! 🐟");
      if (_deckService.remainingCards > 0) {
        List<CardModel> drawn = _deckService.drawCards(1);
        CardModel card = drawn.first;
        _hands[askerId]!.add(card);
        _checkBooks(askerId);
        if (card.rank == rank) {
           _sendSystemMessage("System", "Fished the $rank! Go again.");
           _updateGameState("playing");
           return; 
        }
      } else {
        _sendSystemMessage("System", "Pond empty.");
      }
      _advanceTurn();
    }
  }

  void _checkBooks(String pid) {
    Map<String, int> counts = {};
    for (var c in _hands[pid]!) counts[c.rank] = (counts[c.rank] ?? 0) + 1;
    
    counts.forEach((rank, count) {
      if (count == 4) {
        _hands[pid]!.removeWhere((c) => c.rank == rank);
        int pIndex = _players.indexWhere((p) => p['id'] == pid);
        if (pIndex != -1) _books[pIndex]++;
        _sendSystemMessage("System", "Book of ${rank}s made!");
      }
    });
    
    int totalBooks = _books.fold(0, (a, b) => a + b);
    if (_hands.values.every((h) => h.isEmpty) && _deckService.remainingCards == 0) {
      int maxB = _books.reduce(max);
      int wIndex = _books.indexOf(maxB);
      String wName = _players[wIndex]['name'];
      _db.collection('games').doc(gameCode).update({'winner': wName});
    }
  }

  void _handlePlayCard(String pid, int index, Map<String, dynamic> data) {
    List<CardModel> hand = _hands[pid]!;
    if (index >= hand.length) return;
    CardModel card = hand[index];
    
    if (!_isValidMove(card)) return; 

    bool saidNiko = data['saidNikoKadi'] ?? false;
    if (saidNiko) _nikoKadiDeclarations.add(pid);

    hand.removeAt(index);
    if (_topCard != null) _discardPile.add(_topCard!);
    _topCard = card;
    
    // Clear Joker Constraint if move was valid
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
          _sendSystemMessage("System", "Bomb Blocked by Ace!");
       } else {
          _forcedSuit = data['requestedSuit'];
          _forcedRank = data['requestedRank'];
          _bombStack = 0; 
          String msg = "Request: ${_forcedSuit}";
          if (_forcedRank != null) msg += " $_forcedRank";
          _sendSystemMessage("System", msg);
       }
    } else {
       if (_forcedSuit != null) {
          _forcedSuit = null;
          _forcedRank = null;
       }
    }

    bool isWinningHand = hand.isNotEmpty && hand.every((c) => c.rank == hand[0].rank);
    if (hand.length == 1) {
      if (!_nikoKadiDeclarations.contains(pid)) {
         if (_isWinningCard(hand[0])) {
           _sendSystemMessage("Referee", "Forgot Niko Kadi! +2 Cards");
           _drawCardsForPlayer(pid, 2); 
           _updateGameState("playing");
           _advanceTurn();
           return;
         }
      }
    }
    if (hand.length > 1 && !isWinningHand) _nikoKadiDeclarations.remove(pid);
    
    bool turnEnds = true;
    int skip = 0;

    if (card.rank == 'king') {
       if (_bombStack > 0) {
          _direction *= -1; 
          _sendSystemMessage("System", "Bomb Returned!");
       } else {
          _direction *= -1; 
       }
    } 
    else if (card.rank == 'jack') {
       if (_bombStack > 0) {
          skip = 0; 
          _sendSystemMessage("System", "Bomb Passed!");
       } else {
          if (_players.length > 2) skip = 1; 
       }
    }
    else if (card.rank == 'queen' || card.rank == '8') {
      _waitingForAnswer = true;
      turnEnds = false; 
      _sendSystemMessage("System", "Play the Answer!");
    } 
    else if (_waitingForAnswer) {
      _waitingForAnswer = false;
      turnEnds = true;
    }
    
    if (turnEnds && skip == 0 && hand.isNotEmpty) {
      if (hand.any((c) => c.rank == card.rank)) {
         turnEnds = false; 
      }
    }

    if (hand.isEmpty) {
      bool powerCardFinish = ['2','3','joker','king','jack','queen','8'].contains(card.rank);
      bool anyoneElseCardless = _hands.entries.any((e) => e.key != pid && e.value.isEmpty);
      
      if (powerCardFinish || anyoneElseCardless) {
         if (powerCardFinish) _sendSystemMessage("System", "Player is Cardless (Power Card)!");
         else _sendSystemMessage("System", "Win Blocked by Cardless Player!");
         _updateGameState("playing");
         if (turnEnds) _advanceTurn(skip: skip);
         return;
      } else {
        _db.collection('games').doc(gameCode).update({'winner': _players[_currentPlayerIndex]['name']});
        return;
      }
    }

    _updateGameState("playing");
    if (turnEnds) _advanceTurn(skip: skip);
  }

  void _handlePickCard(String pid) {
    int count = _bombStack > 0 ? _bombStack : 1;
    
    // Check if picking due to bomb stack AND top card is Joker
    if (_bombStack > 0 && _topCard != null && _topCard!.rank == 'joker') {
      // Set color constraint for NEXT player
      if (_topCard!.suit == 'red') _jokerColorConstraint = 'red';
      else if (_topCard!.suit == 'black') _jokerColorConstraint = 'black';
      _sendSystemMessage("System", "Picked Joker Bomb! Next must play $_jokerColorConstraint.");
    }

    _drawCardsForPlayer(pid, count); 
    
    _bombStack = 0;
    _forcedSuit = null;
    _forcedRank = null;
    _waitingForAnswer = false; 
    _nikoKadiDeclarations.remove(pid);
    
    _updateGameState("playing");
    _advanceTurn();
  }

  void _drawCardsForPlayer(String pid, int count) {
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
        _sendSystemMessage("System", "Deck reshuffled from pile!");
        drawn.addAll(_deckService.drawCards(needed));
      }
    }
    _hands[pid]!.addAll(drawn);
  }

  void _advanceTurn({int skip = 0}) {
    int step = _direction * (1 + skip);
    _currentPlayerIndex = (_currentPlayerIndex + step) % _players.length;
    if (_currentPlayerIndex < 0) _currentPlayerIndex += _players.length;
    _updateGameState("playing");
  }

  bool _isValidMove(CardModel card) {
    // 0. Joker Color Constraint
    if (_jokerColorConstraint != null) {
      bool isBomb = ['2', '3', 'joker'].contains(card.rank);
      if (isBomb) return true; // Can always stack bombs
      
      String cardColor = (card.suit == 'hearts' || card.suit == 'diamonds' || card.suit == 'red') ? 'red' : 'black';
      return cardColor == _jokerColorConstraint;
    }

    if (['2', '3', 'joker'].contains(card.rank)) return true;

    if (_bombStack > 0) {
      if (card.rank == 'ace') return true; 
      if (card.rank == 'king') return true; 
      if (card.rank == 'jack') return true; 
      return false; 
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
  
  bool _isWinningCard(CardModel card) {
    const nonWinningRanks = ['2', '3', '8', 'jack', 'queen', 'king', 'joker'];
    return !nonWinningRanks.contains(card.rank);
  }

  void _updateGameState(String status) {
    Map<String, dynamic> handsJson = {};
    _hands.forEach((key, list) => handsJson[key] = list.map((c) => c.toJson()).toList());

    _db.collection('games').doc(gameCode).update({
      'status': status,
      'hands': handsJson,
      'table': _topCard?.toJson(),
      'books': _books, 
      'turnIndex': _currentPlayerIndex,
      'forcedSuit': _forcedSuit,
      'forcedRank': _forcedRank,
      'bombStack': _bombStack,
      'waitingForAnswer': _waitingForAnswer,
      'jokerColorConstraint': _jokerColorConstraint, // Send constraint state
    });
  }

  void _sendSystemMessage(String sender, String msg) {
    _db.collection('games').doc(gameCode).collection('messages').add({
      'sender': sender,
      'text': msg,
      'timestamp': FieldValue.serverTimestamp()
    });
  }
}