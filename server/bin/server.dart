import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ==========================================
//           MODELS & DECK SERVICE
// ==========================================

class CardModel {
  final String suit; 
  final String rank; 

  CardModel({required this.suit, required this.rank});

  Map<String, dynamic> toJson() => {'suit': suit, 'rank': rank};
  factory CardModel.fromJson(Map<String, dynamic> json) => CardModel(suit: json['suit'], rank: json['rank']);
  
  @override
  String toString() => "$rank of $suit";
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
      // Jokers per deck (Standard Kadi requirement)
      _deck.add(CardModel(suit: "red", rank: "joker"));
      _deck.add(CardModel(suit: "black", rank: "joker"));
    }
  }

  void shuffle() => _deck.shuffle(Random());

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

  void addCardToBottom(CardModel card) => _deck.add(card);
  void addCards(List<CardModel> cards) => _deck.addAll(cards);
}

// ==========================================
//              SERVER LOGIC
// ==========================================

class Player {
  final String id;
  final String name;
  final WebSocketChannel socket;
  List<CardModel> hand = [];
  
  // Game-Specific State
  bool hasSaidNikoKadi = false; // Kadi
  int books = 0; // Go Fish
  
  Player(this.id, this.name, this.socket);
}

class GameRoom {
  final String code;
  final DeckService deckService = DeckService();
  List<Player> players = [];
  
  // SHARED STATE
  String gameType = 'kadi'; // 'kadi' or 'gofish'
  bool isGameStarted = false;
  int currentPlayerIndex = 0;
  
  // MUSIC STATE
  List<Map<String, dynamic>> musicQueue = [];
  String? currentMusicId;
  String? currentMusicTitle;

  // KADI STATE
  List<CardModel> discardPile = [];
  CardModel? topCard;
  int direction = 1;
  int bombStack = 0;
  bool waitingForAnswer = false;
  String? forcedSuit;
  String? forcedRank;
  String? jokerColorConstraint;

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
      // Kadi
      'bombStack': bombStack,
      'waitingForAnswer': waitingForAnswer,
      'jokerColorConstraint': jokerColorConstraint,
      'direction': direction,
      // Go Fish
      'books': players.map((p) => p.books).toList(),
    };
  }
}

class MultiGameServer {
  final Map<String, GameRoom> _rooms = {}; 

  Future<void> start() async {
    var handler = webSocketHandler((WebSocketChannel socket) {
      String? playerId;
      String? currentRoomCode;

      socket.stream.listen((message) {
        final data = jsonDecode(message);
        String type = data['type'];

        // --- LOBBY MANAGEMENT ---
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
            
            _broadcastPlayerInfo(_rooms[code]!);
            
            // Sync Music on join
            if (_rooms[code]!.currentMusicId != null) {
               socket.sink.add(jsonEncode({
                 "type": "MUSIC_UPDATE", 
                 "data": {'videoId': _rooms[code]!.currentMusicId, 'title': _rooms[code]!.currentMusicTitle}
               }));
            }
          } else {
            socket.sink.add(jsonEncode({"type": "ERROR", "data": "Room not found"}));
          }
        }
        
        // --- GAME ACTIONS ---
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

    // Listen on 0.0.0.0 for Render
    var server = await shelf_io.serve(handler, '0.0.0.0', 8080);
    print('Game Server running on port ${server.port}');
  }

  void _handleGameAction(GameRoom room, String pid, String type, dynamic data) {
     if (type == 'CHAT') {
        room.broadcast("CHAT", {"sender": data['senderName'], "message": data['message']});
        return;
     }
     if (type == 'ADD_TO_QUEUE') {
        room.musicQueue.add(data['data']);
        if (room.currentMusicId == null) _playNextSong(room);
        else room.broadcast("QUEUE_UPDATE", {'queue': room.musicQueue});
        return;
     }
     if (type == 'SONG_ENDED') {
        _playNextSong(room);
        return;
     }
     if (type == 'START_GAME') {
        _startGame(room, data['decks'] ?? 1);
        return;
     }

     // --- GAMEPLAY ROUTER ---
     int pIndex = room.players.indexWhere((p) => p.id == pid);
     if (pIndex != -1 && pIndex == room.currentPlayerIndex) {
        
        if (room.gameType == 'kadi') {
           if (type == 'PLAY_CARD') _handleKadiPlay(room, pIndex, data);
           else if (type == 'PICK_CARD') _handleKadiPick(room, pIndex);
        } 
        else if (room.gameType == 'gofish') {
           if (type == 'ASK_CARD') _handleGoFishAsk(room, pIndex, data);
        }
     }
  }

  // ==========================================
  //               SETUP LOGIC
  // ==========================================

  void _startGame(GameRoom room, int decks) {
     room.deckService.initializeDeck(decks: decks);
     room.deckService.shuffle();
     room.currentPlayerIndex = 0;
     room.isGameStarted = true;
     
     // KADI SETUP
     if (room.gameType == 'kadi') {
       room.direction = 1; room.bombStack = 0; room.waitingForAnswer = false;
       room.jokerColorConstraint = null; room.discardPile.clear();
       room.forcedSuit = null; room.forcedRank = null;
       
       for(var p in room.players) {
          p.hand = room.deckService.drawCards(4);
          p.hasSaidNikoKadi = false;
          _sendHand(p);
       }
       
       // Ensure valid top card
       room.topCard = room.deckService.drawCards(1).first;
       while (['2','3','8','jack','queen','king','ace','joker'].contains(room.topCard!.rank)) {
         room.deckService.addCardToBottom(room.topCard!);
         room.topCard = room.deckService.drawCards(1).first;
       }
       room.broadcast("UPDATE_TABLE", room.topCard!.toJson());
     } 
     // GO FISH SETUP
     else {
       int count = room.players.length <= 3 ? 7 : 5;
       for(var p in room.players) {
          p.hand = room.deckService.drawCards(count);
          p.books = 0;
          _sendHand(p);
       }
       room.broadcast("GO_FISH_STATE", {'books': room.players.map((p)=>0).toList()});
     }
     
     room.broadcast("TURN_UPDATE", room.getGameState());
     room.broadcast("CHAT", {"sender": "System", "message": "${room.gameType.toUpperCase()} Started!"});
  }

  // ==========================================
  //             GO FISH LOGIC
  // ==========================================

  void _handleGoFishAsk(GameRoom room, int askerIdx, dynamic data) {
     int targetIdx = data['targetIndex'];
     String rank = data['rank'];
     
     if (targetIdx < 0 || targetIdx >= room.players.length || targetIdx == askerIdx) return;
     
     Player asker = room.players[askerIdx];
     Player target = room.players[targetIdx];
     
     List<CardModel> found = target.hand.where((c) => c.rank == rank).toList();
     
     if (found.isNotEmpty) {
        // SUCCESS: Take cards
        target.hand.removeWhere((c) => c.rank == rank);
        asker.hand.addAll(found);
        
        room.broadcast("CHAT", {
           "sender": "System", 
           "message": "${asker.name} took ${found.length} ${rank}s from ${target.name}"
        });
        
        _checkGoFishBooks(room, asker);
        _sendHand(asker);
        _sendHand(target);
        
        // Success means you go again
        room.broadcast("TURN_UPDATE", room.getGameState());
     } else {
        // FAIL: Go Fish
        room.broadcast("CHAT", {"sender": "System", "message": "${target.name} says: GO FISH!"});
        
        if (room.deckService.remainingCards > 0) {
           List<CardModel> drawn = room.deckService.drawCards(1);
           CardModel card = drawn.first;
           asker.hand.add(card);
           _sendHand(asker);
           _checkGoFishBooks(room, asker);
           
           if (card.rank == rank) {
              room.broadcast("CHAT", {"sender": "System", "message": "Fished the $rank! Go again."});
              room.broadcast("TURN_UPDATE", room.getGameState());
              return; 
           }
        } else {
           room.broadcast("CHAT", {"sender": "System", "message": "Pond is empty."});
        }
        
        _advanceTurn(room);
     }
  }

  void _checkGoFishBooks(GameRoom room, Player p) {
     Map<String, int> counts = {};
     for (var c in p.hand) counts[c.rank] = (counts[c.rank] ?? 0) + 1;
     
     counts.forEach((rank, count) {
        if (count == 4) {
           p.hand.removeWhere((c) => c.rank == rank);
           p.books++;
           room.broadcast("CHAT", {"sender": "System", "message": "${p.name} made a Book of ${rank}s!"});
        }
     });
     
     room.broadcast("GO_FISH_STATE", {'books': room.players.map((pl)=>pl.books).toList()});
     
     // Win Condition
     int totalBooks = room.players.fold(0, (sum, pl) => sum + pl.books);
     if (totalBooks == 13 || (room.deckService.remainingCards == 0 && room.players.every((pl)=>pl.hand.isEmpty))) {
        Player winner = room.players.reduce((curr, next) => curr.books > next.books ? curr : next);
        room.broadcast("GAME_OVER", "${winner.name} Wins with ${winner.books} books!");
     }
  }

  // ==========================================
  //               KADI LOGIC
  // ==========================================

  void _handleKadiPlay(GameRoom room, int pIndex, dynamic data) {
     Player player = room.players[pIndex];
     int cardIndex = data['cardIndex'];
     if (cardIndex >= player.hand.length) return;
     CardModel card = player.hand[cardIndex];
     
     // Rules Validation
     bool isValid = _isValidKadiMove(room, card);
     if (!isValid) { 
        player.socket.sink.add(jsonEncode({"type": "ERROR", "data": "Invalid Move"})); 
        return; 
     }

     if (data['saidNikoKadi'] == true) player.hasSaidNikoKadi = true;

     // Play Card
     player.hand.removeAt(cardIndex);
     if (room.topCard != null) room.discardPile.add(room.topCard!);
     room.topCard = card;
     if (room.jokerColorConstraint != null) room.jokerColorConstraint = null;

     // Bomb Logic
     bool isBomb = ['2','3','joker'].contains(card.rank);
     if (card.rank == '2') room.bombStack += 2;
     else if (card.rank == '3') room.bombStack += 3;
     else if (card.rank == 'joker') room.bombStack += 5;

     // Ace Logic
     if (card.rank == 'ace') {
        if (room.bombStack > 0 && !isBomb) {
           room.bombStack = 0; room.forcedSuit = null; room.forcedRank = null;
           room.broadcast("CHAT", {"sender": "System", "message": "Bomb Blocked!"});
        } else {
           room.bombStack = 0;
           // Ace of Spades Lock
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
     
     // Turn Flow & Specials
     bool turnEnds = true;
     int skip = 0;
     if (card.rank == 'queen' || card.rank == '8') { room.waitingForAnswer = true; turnEnds = false; }
     else if (room.waitingForAnswer) { room.waitingForAnswer = false; }
     else if (card.rank == 'king') room.direction *= -1;
     else if (card.rank == 'jack') skip = (room.bombStack > 0) ? 0 : 1;

     // Multi-drop Check (allow dropping duplicates)
     if (turnEnds && skip == 0 && player.hand.isNotEmpty) {
        if (player.hand.any((c) => c.rank == card.rank)) turnEnds = false;
     }

     // Win Check
     if (player.hand.isEmpty) {
        // Power Card restriction
        if (['2','3','8','jack','queen','king','ace','joker'].contains(card.rank)) {
           room.broadcast("CHAT", {"sender": "System", "message": "Cannot win with Power Card!"});
           _sendHand(player); // Re-sync
           _advanceTurn(room, skip: skip); 
           return;
        }
        // Niko Kadi Penalty
        if (!player.hasSaidNikoKadi) {
             room.broadcast("CHAT", {"sender": "Referee", "message": "Forgot Niko Kadi! +2 Cards"});
             _handleKadiPick(room, pIndex, penalty: 2);
             return;
        }
        room.broadcast("GAME_OVER", "${player.name} Wins!");
        return;
     }

     _sendHand(player);
     room.broadcast("UPDATE_TABLE", room.topCard!.toJson());
     
     if (turnEnds) _advanceTurn(room, skip: skip);
     else room.broadcast("TURN_UPDATE", room.getGameState());
  }

  void _handleKadiPick(GameRoom room, int pIndex, {int? penalty}) {
     Player player = room.players[pIndex];
     int count = penalty ?? (room.bombStack > 0 ? room.bombStack : 1);
     
     // Joker Constraint Logic
     if (penalty == null && room.bombStack > 0 && room.topCard?.rank == 'joker') {
        room.jokerColorConstraint = (room.topCard!.suit == 'red') ? 'red' : 'black';
        room.broadcast("CHAT", {"sender": "System", "message": "Constraint: ${room.jokerColorConstraint}"});
     }

     List<CardModel> drawn = [];
     if (room.deckService.remainingCards >= count) drawn = room.deckService.drawCards(count);
     else {
        drawn.addAll(room.deckService.drawCards(room.deckService.remainingCards));
        room.deckService.addCards(room.discardPile); room.discardPile.clear(); room.deckService.shuffle();
        int needed = count - drawn.length;
        drawn.addAll(room.deckService.drawCards(needed));
     }
     player.hand.addAll(drawn);
     
     if (penalty == null) {
       room.bombStack = 0;
       if (room.waitingForAnswer) { room.waitingForAnswer = false; }
     }
     player.hasSaidNikoKadi = false;
     
     _sendHand(player);
     _advanceTurn(room);
  }

  bool _isValidKadiMove(GameRoom room, CardModel card) {
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
    const nonWinning = ['2', '3', '8', 'jack', 'queen', 'king', 'joker'];
    return !nonWinning.contains(card.rank);
  }

  // ==========================================
  //               HELPERS
  // ==========================================

  void _advanceTurn(GameRoom room, {int skip = 0}) {
     int step = (room.gameType == 'kadi' ? room.direction : 1) * (1 + skip);
     room.currentPlayerIndex = (room.currentPlayerIndex + step) % room.players.length;
     if (room.currentPlayerIndex < 0) room.currentPlayerIndex += room.players.length;
     
     // Auto-Draw for empty hands in Go Fish
     if (room.gameType == 'gofish' && room.players[room.currentPlayerIndex].hand.isEmpty && room.deckService.remainingCards > 0) {
        room.players[room.currentPlayerIndex].hand.addAll(room.deckService.drawCards(1));
        _sendHand(room.players[room.currentPlayerIndex]);
     }
     
     room.broadcast("TURN_UPDATE", room.getGameState());
  }

  void _playNextSong(GameRoom room) {
     if (room.musicQueue.isNotEmpty) {
        var next = room.musicQueue.removeAt(0);
        room.currentMusicId = next['videoId'];
        room.currentMusicTitle = next['title'];
        room.broadcast("MUSIC_UPDATE", {'videoId': room.currentMusicId, 'title': room.currentMusicTitle});
        room.broadcast("QUEUE_UPDATE", {'queue': room.musicQueue});
     }
  }

  void _sendHand(Player p) {
     p.socket.sink.add(jsonEncode({"type": "DEAL_HAND", "data": p.hand.map((c)=>c.toJson()).toList()}));
  }

  void _broadcastPlayerInfo(GameRoom room) {
     List<Map<String, dynamic>> pList = room.players.asMap().entries.map((e) => 
        {'id': e.value.id, 'name': e.value.name, 'index': e.key}
     ).toList();
     for (var p in room.players) {
        p.socket.sink.add(jsonEncode({ "type": "PLAYER_INFO", "data": {"players": pList, "myId": p.id} }));
     }
  }

  String _generateRoomCode() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }
}

void main() {
  MultiGameServer().start();
}