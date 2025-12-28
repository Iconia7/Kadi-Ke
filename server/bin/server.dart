import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// --- MODELS & SERVICES (Inline for easy deployment) ---

class CardModel {
  final String suit; // "hearts", "spades", "diamonds", "clubs"
  final String rank; // "2", "3", ... "king", "ace", "joker"

  CardModel({required this.suit, required this.rank});

  Map<String, dynamic> toJson() => {'suit': suit, 'rank': rank};
  factory CardModel.fromJson(Map<String, dynamic> json) => CardModel(suit: json['suit'], rank: json['rank']);
}

class DeckService {
  List<CardModel> _deck = [];
  int get remainingCards => _deck.length;

  void initializeDeck({int decks = 1}) {
    _deck.clear();
    const suits = ['hearts', 'diamonds', 'clubs', 'spades'];
    const ranks = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'jack', 'queen', 'king', 'ace'];

    for (int i = 0; i < decks; i++) {
      for (var suit in suits) {
        for (var rank in ranks) {
          _deck.add(CardModel(suit: suit, rank: rank));
        }
      }
      // Jokers per deck
      _deck.add(CardModel(suit: "red", rank: "joker"));
      _deck.add(CardModel(suit: "black", rank: "joker"));
    }
  }

  void shuffle() {
    _deck.shuffle(Random());
  }

  List<CardModel> drawCards(int count) {
    if (count >= _deck.length) {
      final remaining = List<CardModel>.from(_deck);
      _deck.clear();
      return remaining;
    }
    final drawn = _deck.take(count).toList();
    _deck.removeRange(0, count);
    return drawn;
  }

  void addCardToBottom(CardModel card) {
    _deck.add(card);
  }

  void addCards(List<CardModel> cards) {
    _deck.addAll(cards);
  }
}

// --- SERVER LOGIC ---

class Player {
  final String id;
  final String name;
  final WebSocketChannel socket;
  List<CardModel> hand = [];
  bool hasSaidNikoKadi = false;
  
  Player(this.id, this.name, this.socket);
}

class GameRoom {
  final String code;
  final DeckService deckService = DeckService();
  List<Player> players = [];
  List<CardModel> discardPile = [];
  
  // Game State
  String gameType = 'kadi';
  bool isGameStarted = false;
  CardModel? topCard;
  int currentPlayerIndex = 0;
  int direction = 1;
  int bombStack = 0;
  bool waitingForAnswer = false;
  String? forcedSuit;
  String? forcedRank;
  String? jokerColorConstraint;
  
  // Music State
  List<Map<String, dynamic>> musicQueue = [];
  String? currentMusicId;
  String? currentMusicTitle;

  GameRoom(this.code);

  void broadcast(String type, dynamic data) {
    String payload = jsonEncode({"type": type, "data": data});
    for (var p in players) {
      try { p.socket.sink.add(payload); } catch (e) { print("Socket error: $e"); }
    }
  }
  
  Map<String, dynamic> getGameState() {
    return {
      'playerIndex': currentPlayerIndex,
      'bombStack': bombStack,
      'waitingForAnswer': waitingForAnswer,
      'jokerColorConstraint': jokerColorConstraint,
      'direction': direction
    };
  }
}

class KadiServer {
  final Map<String, GameRoom> _rooms = {}; 

  Future<void> start() async {
    var handler = webSocketHandler((WebSocketChannel socket) {
      String? playerId;
      String? currentRoomCode;

      socket.stream.listen((message) {
        final data = jsonDecode(message);
        String type = data['type'];

        // --- LOBBY LOGIC ---
        if (type == 'CREATE_GAME') {
          String roomCode = _generateRoomCode();
          _rooms[roomCode] = GameRoom(roomCode);
          _rooms[roomCode]!.gameType = data['gameType'] ?? 'kadi';
          socket.sink.add(jsonEncode({"type": "ROOM_CREATED", "data": roomCode}));
        }
        else if (type == 'JOIN_GAME') {
          String code = data['roomCode'].toString().toUpperCase();
          String name = data['name'];
          
          if (_rooms.containsKey(code)) {
            currentRoomCode = code;
            playerId = DateTime.now().millisecondsSinceEpoch.toString(); 
            
            Player newPlayer = Player(playerId!, name, socket);
            _rooms[code]!.players.add(newPlayer);
            
            // Send Initial Info
            _broadcastPlayerInfo(_rooms[code]!);
            
            // If Music is playing, sync new player
            if (_rooms[code]!.currentMusicId != null) {
               socket.sink.add(jsonEncode({
                 "type": "MUSIC_UPDATE", 
                 "data": {'videoId': _rooms[code]!.currentMusicId, 'title': _rooms[code]!.currentMusicTitle}
               }));
               socket.sink.add(jsonEncode({
                 "type": "QUEUE_UPDATE", 
                 "data": {'queue': _rooms[code]!.musicQueue}
               }));
            }
          } else {
            socket.sink.add(jsonEncode({"type": "ERROR", "data": "Room not found"}));
          }
        }
        
        // --- GAMEPLAY ACTIONS ---
        else if (currentRoomCode != null && _rooms.containsKey(currentRoomCode)) {
           GameRoom room = _rooms[currentRoomCode]!;
           _handleGameAction(room, playerId!, type, data);
        }

      }, onDone: () {
        if (currentRoomCode != null && _rooms.containsKey(currentRoomCode)) {
           GameRoom room = _rooms[currentRoomCode]!;
           room.players.removeWhere((p) => p.id == playerId);
           if (room.players.isEmpty) {
             _rooms.remove(currentRoomCode);
             print("Room $currentRoomCode deleted.");
           } else {
             _broadcastPlayerInfo(room);
           }
        }
      });
    });

    // Listen on 0.0.0.0 is crucial for Render deployment
    var server = await shelf_io.serve(handler, '0.0.0.0', 8080);
    print('Kadi Server running on port ${server.port}');
  }

  void _handleGameAction(GameRoom room, String pid, String type, dynamic data) {
     // 1. CHAT
     if (type == 'CHAT') {
        room.broadcast("CHAT", {"sender": data['senderName'], "message": data['message']});
     }
     
     // 2. MUSIC
     else if (type == 'ADD_TO_QUEUE') {
        room.musicQueue.add(data['data']);
        if (room.currentMusicId == null) {
           _playNextSong(room);
        } else {
           room.broadcast("QUEUE_UPDATE", {'queue': room.musicQueue});
        }
     }
     else if (type == 'SONG_ENDED') {
        _playNextSong(room);
     }
     
     // 3. START GAME
     else if (type == 'START_GAME') {
        // Only host (index 0) usually starts, but for simplicity we allow any start call
        _startGame(room, data['decks'] ?? 1);
     }
     
     // 4. PLAYER MOVES (Require Turn Check)
     else {
        int pIndex = room.players.indexWhere((p) => p.id == pid);
        if (pIndex != -1 && pIndex == room.currentPlayerIndex) {
           if (type == 'PLAY_CARD') _handlePlayCard(room, pIndex, data);
           else if (type == 'PICK_CARD') _handlePickCard(room, pIndex);
        }
     }
  }

  void _startGame(GameRoom room, int decks) {
     room.deckService.initializeDeck(decks: decks);
     room.deckService.shuffle();
     
     room.currentPlayerIndex = 0;
     room.direction = 1;
     room.bombStack = 0;
     room.waitingForAnswer = false;
     room.jokerColorConstraint = null;
     room.discardPile.clear();
     
     // Deal Hands
     for(var p in room.players) {
        p.hand = room.deckService.drawCards(4);
        p.hasSaidNikoKadi = false;
        p.socket.sink.add(jsonEncode({"type": "DEAL_HAND", "data": p.hand.map((c)=>c.toJson()).toList()}));
     }
     
     // Top Card
     room.topCard = room.deckService.drawCards(1).first;
     while (['2','3','8','jack','queen','king','ace','joker'].contains(room.topCard!.rank)) {
       room.deckService.addCardToBottom(room.topCard!);
       room.topCard = room.deckService.drawCards(1).first;
     }
     
     room.broadcast("UPDATE_TABLE", room.topCard!.toJson());
     room.broadcast("TURN_UPDATE", room.getGameState());
     room.broadcast("CHAT", {"sender": "System", "message": "Game Started!"});
  }

  void _handlePlayCard(GameRoom room, int pIndex, dynamic data) {
     Player player = room.players[pIndex];
     int cardIndex = data['cardIndex'];
     
     if (cardIndex >= player.hand.length) return;
     CardModel card = player.hand[cardIndex];
     
     // --- VALIDATION LOGIC ---
     if (!_isValidMove(room, card)) {
        player.socket.sink.add(jsonEncode({"type": "ERROR", "data": "Invalid Move"}));
        return;
     }
     
     if (data['saidNikoKadi'] == true) player.hasSaidNikoKadi = true;
     
     // Execute Move
     player.hand.removeAt(cardIndex);
     if (room.topCard != null) room.discardPile.add(room.topCard!);
     room.topCard = card;
     if (room.jokerColorConstraint != null) room.jokerColorConstraint = null;
     
     // Bomb Logic
     bool isBomb = ['2','3','joker'].contains(card.rank);
     if (card.rank == '2') {
       room.bombStack += 2;
     } else if (card.rank == '3') room.bombStack += 3;
     else if (card.rank == 'joker') room.bombStack += 5;
     
     // Ace Logic
     if (card.rank == 'ace') {
        if (room.bombStack > 0 && !isBomb) {
           room.bombStack = 0; room.forcedSuit = null; room.forcedRank = null;
           room.broadcast("CHAT", {"sender": "System", "message": "Bomb Blocked!"});
        } else {
           room.bombStack = 0;
           // Spades Lock
           if (card.suit == 'spades' && player.hand.length == 1) {
              CardModel last = player.hand[0];
              room.forcedSuit = last.suit; room.forcedRank = last.rank;
              room.broadcast("CHAT", {"sender": "System", "message": "LOCKED: ${last.rank} of ${last.suit}"});
           } else {
              room.forcedSuit = data['requestedSuit'];
              room.forcedRank = data['requestedRank'];
              room.broadcast("CHAT", {"sender": "System", "message": "Request: ${room.forcedSuit}"});
           }
        }
     } else {
        if (room.forcedSuit != null) { room.forcedSuit = null; room.forcedRank = null; }
     }
     
     // Turn Flow
     bool turnEnds = true;
     int skip = 0;
     
     if (card.rank == 'queen' || card.rank == '8') {
        room.waitingForAnswer = true;
        turnEnds = false;
        room.broadcast("CHAT", {"sender": "System", "message": "Question! Answer or Chain."});
     } else if (room.waitingForAnswer) {
        room.waitingForAnswer = false;
        turnEnds = true;
     } else if (card.rank == 'king') {
        room.direction *= -1;
        if (room.bombStack > 0) room.broadcast("CHAT", {"sender": "System", "message": "Bomb Returned!"});
     } else if (card.rank == 'jack') {
        if (room.bombStack > 0) {
          skip = 0;
        } else {
          skip = 1;
        } 
     }
     
     // Multi-drop
     if (turnEnds && skip == 0 && player.hand.isNotEmpty) {
        if (player.hand.any((c) => c.rank == card.rank)) turnEnds = false;
     }
     
     // Win Check
     if (player.hand.isEmpty) {
        bool powerFinish = ['2','3','joker','king','jack','queen','8','ace'].contains(card.rank);
        if (powerFinish) {
           room.broadcast("CHAT", {"sender": "System", "message": "Cannot win with Power Card!"});
           _updateGameState(room);
           if (turnEnds) _advanceTurn(room, skip: skip);
           return;
        } else {
           // NIKO KADI PENALTY CHECK
           if (!player.hasSaidNikoKadi) {
              // This is where _isWinningCard was missing
              if (_isWinningCard(card)) {
                 room.broadcast("CHAT", {"sender": "Referee", "message": "Forgot Niko Kadi! +2 Cards"});
                 _handlePickCard(room, pIndex, penalty: 2); // Helper to draw 2
                 return;
              }
           }
           
           room.broadcast("GAME_OVER", "${player.name} Wins!");
           return;
        }
     }
     
     player.socket.sink.add(jsonEncode({"type": "DEAL_HAND", "data": player.hand.map((c)=>c.toJson()).toList()}));
     room.broadcast("UPDATE_TABLE", room.topCard!.toJson());
     
     if (turnEnds) {
       _advanceTurn(room, skip: skip);
     } else {
       _updateGameState(room);
     }
  }

  void _handlePickCard(GameRoom room, int pIndex, {int? penalty}) {
     Player player = room.players[pIndex];
     int count = penalty ?? (room.bombStack > 0 ? room.bombStack : 1);
     
     // Joker Constraint Logic (only if not a penalty)
     if (penalty == null && room.bombStack > 0 && room.topCard?.rank == 'joker') {
        room.jokerColorConstraint = (room.topCard!.suit == 'red') ? 'red' : 'black';
        room.broadcast("CHAT", {"sender": "System", "message": "Constraint: ${room.jokerColorConstraint}"});
     }
     
     // Draw
     List<CardModel> drawn = [];
     if (room.deckService.remainingCards >= count) {
        drawn = room.deckService.drawCards(count);
     } else {
        drawn.addAll(room.deckService.drawCards(room.deckService.remainingCards));
        room.deckService.addCards(room.discardPile);
        room.discardPile.clear();
        room.deckService.shuffle();
        int needed = count - drawn.length;
        drawn.addAll(room.deckService.drawCards(needed));
     }
     player.hand.addAll(drawn);
     
     // Reset
     if (penalty == null) {
       room.bombStack = 0;
       room.forcedSuit = null;
       room.forcedRank = null;
       if (room.waitingForAnswer) {
          room.waitingForAnswer = false;
          room.broadcast("CHAT", {"sender": "System", "message": "Player picked. Question voided."});
       }
     }
     player.hasSaidNikoKadi = false;
     
     player.socket.sink.add(jsonEncode({"type": "DEAL_HAND", "data": player.hand.map((c)=>c.toJson()).toList()}));
     
     // Only advance turn if it wasn't a penalty that keeps turn (usually penalty ends turn in Kadi)
     _advanceTurn(room);
  }

  bool _isValidMove(GameRoom room, CardModel card) {
     if (room.jokerColorConstraint != null) {
        bool isBomb = ['2', '3', 'joker'].contains(card.rank);
        if (isBomb) return true;
        String color = (['hearts','diamonds','red'].contains(card.suit)) ? 'red' : 'black';
        return color == room.jokerColorConstraint;
     }
     if (room.bombStack > 0) {
        if (['2','3','joker'].contains(card.rank)) return true;
        if (['ace','king','jack'].contains(card.rank)) return true;
        return false;
     }
     if (room.waitingForAnswer) {
        if (card.rank == 'queen' || card.rank == '8') return card.suit == room.topCard!.suit || card.rank == room.topCard!.rank;
        if (['4','5','6','7','9','10'].contains(card.rank)) return card.suit == room.topCard!.suit;
        return false;
     }
     if (card.rank == 'ace') return true;
     if (room.forcedRank != null && room.forcedSuit != null) return card.rank == room.forcedRank && card.suit == room.forcedSuit;
     if (room.forcedSuit != null) return card.suit == room.forcedSuit;
     
     return card.suit == room.topCard!.suit || card.rank == room.topCard!.rank || ['2','3','joker'].contains(card.rank);
  }

  bool _isWinningCard(CardModel card) {
    const nonWinningRanks = ['2', '3', '8', 'jack', 'queen', 'king', 'joker'];
    return !nonWinningRanks.contains(card.rank);
  }

  void _advanceTurn(GameRoom room, {int skip = 0}) {
     int total = room.players.length;
     int step = room.direction * (1 + skip);
     room.currentPlayerIndex = (room.currentPlayerIndex + step) % total;
     if (room.currentPlayerIndex < 0) room.currentPlayerIndex += total;
     _updateGameState(room);
  }
  
  void _updateGameState(GameRoom room) {
     room.broadcast("TURN_UPDATE", room.getGameState());
  }

  void _playNextSong(GameRoom room) {
     if (room.musicQueue.isNotEmpty) {
        var next = room.musicQueue.removeAt(0);
        room.currentMusicId = next['videoId'];
        room.currentMusicTitle = next['title'];
        
        room.broadcast("MUSIC_UPDATE", {'videoId': room.currentMusicId, 'title': room.currentMusicTitle});
        room.broadcast("QUEUE_UPDATE", {'queue': room.musicQueue});
     } else {
        room.currentMusicId = null;
     }
  }

  void _broadcastPlayerInfo(GameRoom room) {
     List<Map<String, dynamic>> pList = room.players.asMap().entries.map((e) => 
        {'id': e.value.id, 'name': e.value.name, 'index': e.key}
     ).toList();
     
     for (var p in room.players) {
        p.socket.sink.add(jsonEncode({
           "type": "PLAYER_INFO", 
           "data": {"players": pList, "myId": p.id}
        }));
     }
  }

  String _generateRoomCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }
}

void main() {
  KadiServer().start();
}