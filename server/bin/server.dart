import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:io'; // For Platform info if needed
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:crypto/crypto.dart';

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
  int cardsPlayedThisTurn = 0; // Kadi Multi-drop
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
  int entryFee = 0; // Added for Betting
  
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

  // HOUSE RULES
  Map<String, dynamic> rules = {
    'jokerPenalty': 5, // 5 or 10
    'queenAction': 'question', // 'question' or 'skip'
    'allowBombStacking': true // true or false
  };

  GameRoom(this.code);

  void broadcast(String type, dynamic data) {
    String payload = jsonEncode({"type": type, "data": data});
    for (var p in players) {
      try { p.socket.sink.add(payload); } catch (e) { MultiGameServer._log("Socket error for ${p.id}: $e", level: 'ERROR'); }
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
      'cardsPlayedThisTurn': players[currentPlayerIndex].cardsPlayedThisTurn,
    };
  }
}

class MultiGameServer {
  final Map<String, GameRoom> _rooms = {}; 
  
  // Track online users by userId -> username
  final Map<String, String> _onlineUsers = {};
  
  // Track user WebSocket connections for notifications
  final Map<String, WebSocketSink> _userSockets = {};

  static void _log(String message, {String level = 'INFO'}) {
    final time = DateTime.now().toIso8601String();
    print("[$time] [$level] $message");
  }

  // ==========================================
  //               AUTH & PERSISTENCE
  // ==========================================

  final File _usersFile = File('users.json');
  Map<String, dynamic> _users = {};

  String _hashPassword(String password) {
    final salt = "kadi_ke_salt_2026"; // In a real production app, use a unique salt per user
    final bytes = utf8.encode(password + salt);
    return sha256.convert(bytes).toString();
  }

  void _loadUsers() {
    if (_usersFile.existsSync()) {
      try {
        _users = jsonDecode(_usersFile.readAsStringSync());
        _log("Loaded ${_users.length} users.");
      } catch (e) {
        _log("Error loading users: $e", level: 'ERROR');
      }
    }
  }

  void _saveUsers() {
    try {
      _usersFile.writeAsStringSync(jsonEncode(_users));
    } catch (e) {
      _log("Error saving users: $e", level: 'ERROR');
    }
  }

  Future<Response> _handleAuth(Request request) async {
    final path = request.url.path;
    
    // CORS Preflight
    if (request.method == 'OPTIONS') {
      return Response.ok('', headers: _corsHeaders);
    }

    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final username = data['username'];
      final password = data['password']; // In prod, HASH THIS!

      if (path == 'register') {
        if (_users.containsKey(username)) {
          return Response.ok(jsonEncode({'error': 'Username taken'}), headers: _corsHeaders);
        }
        
        // Check email uniqueness if provided
        final email = data['email'];
        if (email != null && email.toString().isNotEmpty) {
           bool emailExists = false;
           _users.forEach((_, u) {
              if (u['email'] == email) emailExists = true;
           });
           if (emailExists) {
             return Response.ok(jsonEncode({'error': 'Email already registered'}), headers: _corsHeaders);
           }
        }

        // Simple User Object
        _users[username] = {
           'password': _hashPassword(password),
           'email': email, // Store email
           'id': DateTime.now().millisecondsSinceEpoch.toString(), // Generate simple ID
           'wins': 0,
           'coins': 0, // Initial coins explicitly 0 for production
           'created_at': DateTime.now().toIso8601String()
        };
        _saveUsers();
        return Response.ok(jsonEncode({'status': 'success', 'userId': _users[username]['id']}), headers: _corsHeaders);
      } 
      
      else if (path == 'login') {
        final currentHash = _hashPassword(password);
        final legacyHash = sha256.convert(utf8.encode(password)).toString(); // Legacy (unsalted)
        
        _log("Login attempt for user: $username");
        
        if (!_users.containsKey(username)) {
           _log("Login failed: User '$username' not found in database", level: 'WARNING');
           return Response.ok(jsonEncode({'error': 'Invalid Credentials'}), headers: _corsHeaders);
        }

        final storedHash = _users[username]['password'];
        bool success = false;

        if (storedHash == currentHash) {
          success = true;
        } else if (storedHash == legacyHash) {
          _log("Legacy unsalted hash detected for '$username'. Upgrading...");
          _users[username]['password'] = currentHash;
          _saveUsers();
          success = true;
        } else if (storedHash == password) {
          _log("Legacy plain-text password detected for '$username'. Upgrading to salted hash...");
          _users[username]['password'] = currentHash;
          _saveUsers();
          success = true;
        }

        if (!success) {
           _log("Login failed: Password hash mismatch for '$username'", level: 'WARNING');
           return Response.ok(jsonEncode({'error': 'Invalid Credentials'}), headers: _corsHeaders);
        }

        _log("Login successful: $username");
        return Response.ok(jsonEncode({
           'status': 'success', 
           'userId': _users[username]['id'],
           'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}' // Mock Token
        }), headers: _corsHeaders);
      }
      
    } catch (e) {
      return Response.internalServerError(body: "Auth Error: $e", headers: _corsHeaders);
    }
    
    return Response.notFound('Not Found');
  }

  Future<Response> _handleGoogleAuth(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final googleId = data['googleId'];
      final email = data['email'];
      final displayName = data['displayName'] ?? "Google User";

      _log("Google Login attempt: $email ($googleId)");

      // Check if user already exists by googleId
      String? username;
      _users.forEach((key, value) {
        if (value['googleId'] == googleId) {
          username = key;
        }
      });

      if (username == null) {
        // Register new user
        username = email.split('@')[0]; // Use email prefix as initial username
        
        // Ensure uniqueness
        String originalUsername = username!;
        int count = 1;
        while (_users.containsKey(username)) {
          username = "${originalUsername}_${count++}";
        }

        _users[username!] = {
          'googleId': googleId,
          'email': email,
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'wins': 0,
          'coins': 0,
          'created_at': DateTime.now().toIso8601String()
        };
        _saveUsers();
        _log("Created new Google-linked user: $username");
      }

      return Response.ok(jsonEncode({
        'status': 'success',
        'userId': _users[username]['id'],
        'username': username,
        'token': 'google_token_${DateTime.now().millisecondsSinceEpoch}'
      }), headers: _corsHeaders);

    } catch (e) {
      _log("Google Auth Error: $e", level: 'ERROR');
      return Response.internalServerError(body: "Google Auth Error: $e", headers: _corsHeaders);
    }
  }

  Future<Response> _handleForgotPassword(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final email = data['email'];
      
      _log("Forgot password request for: $email");
      
      String? targetUsername;
      _users.forEach((u, v) {
        if (v['email'] == email) targetUsername = u;
      });
      
      if (targetUsername == null) {
         // Generic response for security
         return Response.ok(jsonEncode({'status': 'success', 'message': 'If an account exists, a reset code has been sent.'}), headers: _corsHeaders);
      }
      
      // Generate Reset Token
      final token = _generateRoomCode(); // Reuse 6-char code generator for simplicity
      _users[targetUsername!]['resetToken'] = token;
      _users[targetUsername!]['resetTokenExpiry'] = DateTime.now().add(Duration(minutes: 15)).toIso8601String();
      _saveUsers();
      
      _log("Reset Token for $targetUsername: $token");
      
      // Return token in response for DEBUGGING/DEVELOPMENT purposes only
      return Response.ok(jsonEncode({
        'status': 'success', 
        'message': 'Reset code generated.',
        'debug_token': token 
      }), headers: _corsHeaders);
      
    } catch (e) {
       _log("Forgot Password Error: $e", level: 'ERROR');
       return Response.internalServerError(body: "Error processing request", headers: _corsHeaders);
    }
  }

  Future<Response> _handleResetPassword(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final email = data['email'];
      final token = data['token'];
      final newPassword = data['newPassword'];
      
      _log("Password reset attempt for: $email with token $token");
      
      String? targetUsername;
      _users.forEach((u, v) {
        if (v['email'] == email) targetUsername = u;
      });
      
      if (targetUsername == null) {
         return Response.ok(jsonEncode({'error': 'Invalid request'}), headers: _corsHeaders);
      }
      
      var userData = _users[targetUsername];
      if (userData['resetToken'] != token) {
         return Response.ok(jsonEncode({'error': 'Invalid reset token'}), headers: _corsHeaders);
      }
      
      // Check expiry
      if (userData['resetTokenExpiry'] != null) {
         DateTime expiry = DateTime.parse(userData['resetTokenExpiry']);
         if (DateTime.now().isAfter(expiry)) {
            return Response.ok(jsonEncode({'error': 'Token expired'}), headers: _corsHeaders);
         }
      }
      
      // Success - Update Password
      _users[targetUsername!]['password'] = _hashPassword(newPassword);
      _users[targetUsername!].remove('resetToken');
      _users[targetUsername!].remove('resetTokenExpiry');
      _saveUsers();
      
      _log("Password successfully reset for $targetUsername");
      return Response.ok(jsonEncode({'status': 'success', 'message': 'Password updated'}), headers: _corsHeaders);
      
    } catch (e) {
       _log("Reset Password Error: $e", level: 'ERROR');
       return Response.internalServerError(body: "Error processing request", headers: _corsHeaders);
    }
  }

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type',
    'Content-Type': 'application/json'
  };

  Future<Response> _handleLeaderboard(Request request) async {
    try {
      _log("Fetching leaderboard. Total users: ${_users.length}");
      // Convert users map to list and sort by wins
      var userList = _users.entries.map((entry) {
        return {
          'username': entry.key,
          'wins': int.tryParse(entry.value['wins'].toString()) ?? 0,
          'userId': entry.value['id'],
        };
      }).toList();

      userList.sort((a, b) => (b['wins'] as int).compareTo(a['wins'] as int));
      
      // Return top 20
      var topUsers = userList.take(20).toList();
      _log("Returning ${topUsers.length} users for leaderboard.");
      
      return Response.ok(jsonEncode({'leaderboard': topUsers}), headers: _corsHeaders);
    } catch (e, stack) {
      _log("Leaderboard Error: $e\n$stack", level: 'ERROR');
      return Response.internalServerError(body: jsonEncode({'error': "Leaderboard Error: $e"}), headers: _corsHeaders);
    }
  }

  Future<Response> _handleActiveRooms(Request request) async {
     final activeRooms = _rooms.values
        .where((r) => !r.isGameStarted && r.players.length < 8)
        .map((r) => {
           'code': r.code,
           'players': r.players.length,
           'gameType': r.gameType,
           'entryFee': r.entryFee
        }).toList();
     
     return Response.ok(jsonEncode(activeRooms), headers: _corsHeaders);
  }

  Future<Response> _handleUpdateStats(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final username = data['username'];
      final winsToAdd = int.tryParse(data['wins']?.toString() ?? "1") ?? 1;

      _log("Update Stats Request: $username increment by $winsToAdd");

      if (_users.containsKey(username)) {
        int currentWins = int.tryParse(_users[username]['wins']?.toString() ?? "0") ?? 0;
        _users[username]['wins'] = currentWins + winsToAdd;
        _saveUsers();
        _log("Wins updated for $username: ${_users[username]['wins']}");
        return Response.ok(jsonEncode({'status': 'success', 'wins': _users[username]['wins']}), headers: _corsHeaders);
      } else {
        _log("Update Stats Fail: User $username not found", level: 'WARNING');
        return Response.ok(jsonEncode({'error': 'User not found'}), headers: _corsHeaders);
      }
    } catch (e, stack) {
      _log("Update Stats Error: $e\n$stack", level: 'ERROR');
      return Response.internalServerError(body: jsonEncode({'error': "Update Stats Error: $e"}), headers: _corsHeaders);
    }
  }

  Future<Response> _handleUpdateProfile(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final oldUsername = data['oldUsername'];
      final newUsername = data['newUsername'];

      _log("Profile Update Request: $oldUsername -> $newUsername");

      if (!_users.containsKey(oldUsername)) {
        return Response.ok(jsonEncode({'error': 'User not found'}), headers: _corsHeaders);
      }

      if (_users.containsKey(newUsername)) {
        return Response.ok(jsonEncode({'error': 'Username already taken'}), headers: _corsHeaders);
      }

      // Re-key the user map
      final userData = _users.remove(oldUsername);
      _users[newUsername] = userData;
      
      _saveUsers();
      _log("Profile updated successfully: $newUsername");
      
      return Response.ok(jsonEncode({'status': 'success', 'username': newUsername}), headers: _corsHeaders);
    } catch (e, stack) {
      _log("Update Profile Error: $e\n$stack", level: 'ERROR');
      return Response.internalServerError(body: jsonEncode({'error': 'Update Profile Error'}), headers: _corsHeaders);
    }
  }

  // ==========================================
  //         FRIEND MANAGEMENT
  // ==========================================

  Future<Response> _handleFriendRequest(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final targetUsername = data['targetUsername'];
      
      // Get requesting user from auth (in production, extract from JWT)
      final authHeader = request.headers['authorization'];
      if (authHeader == null) {
        return Response.ok(jsonEncode({'error': 'Not authenticated'}), headers: _corsHeaders);
      }
      
      // Simple token validation - extract username
      // In production, use proper JWT validation
      String? requestingUsername;
      _users.forEach((username, userData) {
        if (authHeader.contains(userData['id'] ?? '')) {
          requestingUsername = username;
        }
      });
      
      if (requestingUsername == null) {
        return Response.ok(jsonEncode({'error': 'Invalid authentication'}), headers: _corsHeaders);
      }
      
      if (!_users.containsKey(targetUsername)) {
        return Response.ok(jsonEncode({'error': 'User not found'}), headers: _corsHeaders);
      }
      
      if (requestingUsername == targetUsername) {
        return Response.ok(jsonEncode({'error': 'Cannot add yourself as friend'}), headers: _corsHeaders);
      }
      
      // Initialize friends list if not exists
      _users[requestingUsername]!['friends'] ??= [];
      _users[targetUsername]!['friends'] ??= [];
      
      // Check if already friends or pending
      final requesterFriends = _users[requestingUsername]!['friends'] as List;
      final alreadyExists = requesterFriends.any((f) => f['userId'] == _users[targetUsername]!['id']);
      
      if (alreadyExists) {
        return Response.ok(jsonEncode({'error': 'Friend request already exists'}), headers: _corsHeaders);
      }
      
      // Add pending request to target user's friends list
      (_users[targetUsername]!['friends'] as List).add({
        'userId': _users[requestingUsername]!['id'],
        'username': requestingUsername,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      });
      
      _saveUsers();
      _log("Friend request sent from $requestingUsername to $targetUsername");
      
      return Response.ok(jsonEncode({'status': 'success'}), headers: _corsHeaders);
    } catch (e) {
      _log("Friend Request Error: $e", level: 'ERROR');
      return Response.internalServerError(body: jsonEncode({'error': 'Server error'}), headers: _corsHeaders);
    }
  }

  Future<Response> _handleFriendAccept(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final friendUserId = data['userId'];
      
      // Get current user
      final authHeader = request.headers['authorization'];
      String? currentUsername;
      _users.forEach((username, userData) {
        if (authHeader?.contains(userData['id'] ?? '') == true) {
          currentUsername = username;
        }
      });
      
      if (currentUsername == null) {
        return Response.ok(jsonEncode({'error': 'Not authenticated'}), headers: _corsHeaders);
      }
      
      // Find friend username
      String? friendUsername;
      _users.forEach((username, userData) {
        if (userData['id'] == friendUserId) {
          friendUsername = username;
        }
      });
      
      if (friendUsername == null) {
        return Response.ok(jsonEncode({'error': 'User not found'}), headers: _corsHeaders);
      }
      
      // Update pending request to accepted
      final currentUserFriends = (_users[currentUsername]!['friends'] ?? []) as List;
      final requestIndex = currentUserFriends.indexWhere((f) => f['userId'] == friendUserId);
      
      if (requestIndex != -1) {
        currentUserFriends[requestIndex]['status'] = 'accepted';
      }
      
      // Add to friend's friend list as accepted
      _users[friendUsername]!['friends'] ??= [];
      final friendFriends = _users[friendUsername]!['friends'] as List;
      final existingIndex = friendFriends.indexWhere((f) => f['userId'] == _users[currentUsername]!['id']);
      
      if (existingIndex == -1) {
        friendFriends.add({
          'userId': _users[currentUsername]!['id'],
          'username': currentUsername,
          'status': 'accepted',
          'createdAt': DateTime.now().toIso8601String(),
        });
      } else {
        friendFriends[existingIndex]['status'] = 'accepted';
      }
      
      _saveUsers();
      _log("Friend request accepted: $currentUsername <-> $friendUsername");
      
      return Response.ok(jsonEncode({'status': 'success'}), headers: _corsHeaders);
    } catch (e) {
      _log("Friend Accept Error: $e", level: 'ERROR');
      return Response.internalServerError(body: jsonEncode({'error': 'Server error'}), headers: _corsHeaders);
    }
  }

  Future<Response> _handleFriendRemove(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final friendUserId = data[' userId'];
      
      // Get current user
      final authHeader = request.headers['authorization'];
      String? currentUsername;
      _users.forEach((username, userData) {
        if (authHeader?.contains(userData['id'] ?? '') == true) {
          currentUsername = username;
        }
      });
      
      if (currentUsername == null) {
        return Response.ok(jsonEncode({'error': 'Not authenticated'}), headers: _corsHeaders);
      }
      
      // Remove from both users' friend lists
      if (_users[currentUsername]!['friends'] != null) {
        (_users[currentUsername]!['friends'] as List).removeWhere((f) => f['userId'] == friendUserId);
      }
      
      // Find and remove from friend's list too
      _users.forEach((username, userData) {
        if (userData['id'] == friendUserId && userData['friends'] != null) {
          (userData['friends'] as List).removeWhere((f) => f['userId'] == _users[currentUsername]!['id']);
        }
      });
      
      _saveUsers();
      _log("Friend removed for user $currentUsername");
      
      return Response.ok(jsonEncode({'status': 'success'}), headers: _corsHeaders);
    } catch (e) {
      _log("Friend Remove Error: $e", level: 'ERROR');
      return Response.internalServerError(body: jsonEncode({'error': 'Server error'}), headers: _corsHeaders);
    }
  }

  Future<Response> _handleFriendsList(Request request) async {
    try {
      // Get current user
      final authHeader = request.headers['authorization'];
      String? currentUsername;
      String? currentUserId;
      _users.forEach((username, userData) {
        if (authHeader?.contains(userData['id'] ?? '') == true) {
          currentUsername = username;
          currentUserId = userData['id'];
        }
      });
      
      if (currentUsername == null) {
        return Response.ok(jsonEncode({'error': 'Not authenticated'}), headers: _corsHeaders);
      }
      
      final friends = (_users[currentUsername]!['friends'] ?? []) as List;
      
      // Enrich friend data with current wins and online status
      final enrichedFriends = friends.map((friend) {
        // Find full user data
        final friendData = _users.values.firstWhere(
          (u) => u['id'] == friend['userId'],
          orElse: () => {},
        );
        
        return {
          'userId': friend['userId'],
          'username': friend['username'],
          'status': friend['status'],
          'wins': friendData['wins'] ?? 0,
          'isOnline': false, // TODO: Track online status via WebSocket
          'createdAt': friend['createdAt'],
        };
      }).toList();
      
      return Response.ok(jsonEncode({'friends': enrichedFriends}), headers: _corsHeaders);
    } catch (e) {
      _log("Friends List Error: $e", level: 'ERROR');
      return Response.internalServerError(body: jsonEncode({'error': 'Server error'}), headers: _corsHeaders);
    }
  }

  Future<Response> _handleFriendSearch(Request request) async {
    try {
      final username = request.url.queryParameters['username'] ?? '';
      
      if (username.isEmpty) {
        return Response.ok(jsonEncode({'users': []}), headers: _corsHeaders);
      }
      
      // Search for users matching username (case-insensitive partial match)
      final results = <Map<String, dynamic>>[];
      _users.forEach((key, userData) {
        if (key.toLowerCase().contains(username.toLowerCase())) {
          results.add({
            'userId': userData['id'],
            'username': key,
            'wins': userData['wins'] ?? 0,
          });
        }
      });
      
      // Limit to 20 results
      return Response.ok(jsonEncode({'users': results.take(20).toList()}), headers: _corsHeaders);
    } catch (e) {
      _log("Friend Search Error: $e", level: 'ERROR');
      return Response.internalServerError(body: jsonEncode({'error': 'Server error'}), headers: _corsHeaders);
    }
  }

  // ==========================================
  //              WEBSOCKET HANDLER
  // ==========================================

  Future<void> _start() async {
    _loadUsers(); // Load DB on start

    // WebSocket Handler
    var wsHandler = webSocketHandler(
      (WebSocketChannel socket) {
        String? playerId;
        StreamSubscription? subscription;
        String? currentRoomCode;

        subscription = socket.stream.listen((message) {
          try {
             final decoded = jsonDecode(message);
             String action = decoded['action'] ?? '';
             
             // Track user presence on connection
             if (action == 'JOIN') {
               String userId = decoded['userId'] ?? '';
               String username = decoded['username'] ?? '';
               
               if (userId.isNotEmpty && username.isNotEmpty) {
                 // Track online user
                 _onlineUsers[userId] = username;
                 _userSockets[userId] = socket.sink;
                 
                 // Notify friends that user came online
                 _notifyFriendsUserOnline(userId, username);
                 
                 _log("User $username ($userId) came online");
               }
               return; // Do not process as game logic if it's a JOIN action
             }

             // Existing game logic
             final data = decoded; // Use the already decoded message
             // Basic Sanity Check
             if (data == null || data['type'] == null) return;

             String type = data['type'];

             // --- LOBBY MANAGEMENT ---
             if (type == 'CREATE_GAME') {
               String roomCode = _generateRoomCode();
               _rooms[roomCode] = GameRoom(roomCode);
               _rooms[roomCode]!.gameType = data['gameType'] ?? 'kadi';
               _rooms[roomCode]!.entryFee = data['entryFee'] ?? 0;
               if (data['rules'] != null) {
                  _rooms[roomCode]!.rules = data['rules'];
               }
               
               // Auto-join the creator
               currentRoomCode = roomCode;
               playerId = DateTime.now().millisecondsSinceEpoch.toString();
               String playerName = data['playerName'] ?? "Host"; // Ensure client sends this
               
               Player newPlayer = Player(playerId!, playerName, socket);
               _rooms[roomCode]!.players.add(newPlayer);

               socket.sink.add(jsonEncode({"type": "ROOM_CREATED", "data": roomCode}));
               _broadcastPlayerInfo(_rooms[roomCode]!); // Update lobby
               
               _log("Room Created: $roomCode by $playerName. Rules: ${_rooms[roomCode]!.rules}");
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
                 _log("Player $name joined room $code");
               } else {
                 socket.sink.add(jsonEncode({"type": "ERROR", "data": "Room not found"}));
               }
             }
             
             // --- GAME ACTIONS ---
             else if (currentRoomCode != null && _rooms.containsKey(currentRoomCode)) {
                GameRoom room = _rooms[currentRoomCode]!;
                _handleGameAction(room, playerId!, type, data);
             }

          } catch (e, stack) {
             _log("Error processing message: $e", level: 'ERROR');
          }

        }, onDone: () {
          if (currentRoomCode != null && _rooms.containsKey(currentRoomCode)) {
             GameRoom room = _rooms[currentRoomCode]!;
             // Remove player
             room.players.removeWhere((p) => p.id == playerId);
             
             // If room is empty, delete it
             if (room.players.isEmpty) {
               _rooms.remove(currentRoomCode);
               _log("Room $currentRoomCode deleted (Empty).");
             } else {
               // Notify others that player left
               _broadcastPlayerInfo(room);
               _log("Player left room $currentRoomCode. Rem: ${room.players.length}");
             }
          }
        }, onError: (error) {
           _log("WebSocket Error: $error", level: 'ERROR');
        });
      },
      // ✅ VITAL FIX: Keep connection alive by pinging every 10 seconds
      pingInterval: Duration(seconds: 10), 
    );

    // Main Pipeline with Health & Auth
    var handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler((Request request) {
         if (request.url.path == 'health') {
           return Response.ok('{"status": "ok", "rooms": ${_rooms.length}, "users": ${_users.length}}', headers: {'content-type': 'application/json'});
         }
         if (request.url.path == 'register' || request.url.path == 'login') {
            return _handleAuth(request);
         }
         if (request.url.path == 'leaderboard') {
            return _handleLeaderboard(request);
         }
          if (request.url.path == 'update_stats') {
             return _handleUpdateStats(request);
          }
          if (request.url.path == 'active_rooms') {
             return _handleActiveRooms(request);
          }
          if (request.url.path == 'update_profile') {
             return _handleUpdateProfile(request);
          }
          if (request.url.path == 'update_profile') {
             return _handleUpdateProfile(request);
          }
          if (request.url.path == 'forgot_password') {
             return _handleForgotPassword(request);
          }
          if (request.url.path == 'reset_password') {
             return _handleResetPassword(request);
          }
          if (request.url.path == 'google_login') {
             return _handleGoogleAuth(request);
          }
          if (request.url.path == 'friends/request') {return _handleFriendRequest(request);}
          if (request.url.path == 'friends/accept') {return _handleFriendAccept(request);}
          if (request.url.path == 'friends/remove') {return _handleFriendRemove(request);}
          if (request.url.path == 'friends/list') {return _handleFriendsList(request);}
          if (request.url.path == 'friends/search') {return _handleFriendSearch(request);}
         return wsHandler(request);
      });

    // Listen on 0.0.0.0 for Render
    var server = await shelf_io.serve(handler, '0.0.0.0', 8080);
    _log('Game Server running on port ${server.port}');
  }

  void _handleGameAction(GameRoom room, String pid, String type, dynamic data) {
     try {
       if (type == 'CHAT') {
          room.broadcast("CHAT", {"sender": data['senderName'], "message": data['message']});
          return;
       }
       if (type == 'EMOTE') {
          // Broadcast to all, including sender so they see it too (or exclude sender if local handled)
          room.broadcast("EMOTE", {"senderId": pid, "emote": data['emote']});
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
             if (type == 'PLAY_CARD') _handleKadiPlay(room, pIndex, data);
             else if (type == 'PICK_CARD') _handleKadiPick(room, pIndex);
             else if (type == 'PASS_TURN') _handleKadiPass(room, pIndex);
          } 
          else if (room.gameType == 'gofish') {
             if (type == 'ASK_CARD') _handleGoFishAsk(room, pIndex, data);
          }
       }
     } catch (e) {
       _log("Game Action Error: $e", level: 'ERROR');
     }
  }

  // ==========================================
  //               SETUP LOGIC
  // ==========================================

  void _startGame(GameRoom room, int decks) {
     _log("Starting game in room ${room.code} with $decks decks");
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
        _log("Game Over in room ${room.code}. Winner: ${winner.name}");
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

     player.cardsPlayedThisTurn++;

     // Play Card
     player.hand.removeAt(cardIndex);
     if (room.topCard != null) room.discardPile.add(room.topCard!);
     room.topCard = card;
     if (room.jokerColorConstraint != null) room.jokerColorConstraint = null;

     // Bomb Logic
     bool isBomb = ['2','3','joker'].contains(card.rank);
     
     // Stacking Rule
     if (room.bombStack > 0 && isBomb && room.rules['allowBombStacking'] == false) {
        // You cannot stack! You sent a "move" that should be invalid or handled?
        // Actually, _isValidKadiMove should handle prevention.
     }

     if (card.rank == '2') room.bombStack += 2;
     else if (card.rank == '3') room.bombStack += 3;
     else if (card.rank == 'joker') room.bombStack += (room.rules['jokerPenalty'] as int); // Rule Applied

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
     
     if (card.rank == 'queen') {
        if (room.rules['queenAction'] == 'skip') {
           skip = (room.bombStack > 0) ? 0 : 1;
        } else {
           room.waitingForAnswer = true; turnEnds = false;
        }
     }
     else if (card.rank == '8') { room.waitingForAnswer = true; turnEnds = false; }
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
        _log("Game Over in room ${room.code}. Winner: ${player.name}");
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
        _log("Deck reshuffled in room ${room.code}");
     }
     player.hand.addAll(drawn);
     
     if (penalty == null) {
       room.bombStack = 0;
       if (room.waitingForAnswer) { room.waitingForAnswer = false; }
     }
     player.hasSaidNikoKadi = false;
     
     _sendHand(player);
     _sendHand(player);
     _advanceTurn(room);
  }

  void _handleKadiPass(GameRoom room, int pIndex) {
     Player player = room.players[pIndex];
     if (player.cardsPlayedThisTurn > 0) {
        _advanceTurn(room);
     } else {
        player.socket.sink.add(jsonEncode({"type": "ERROR", "data": "Cannot pass without playing!"}));
     }
  }

  bool _isValidKadiMove(GameRoom room, CardModel card) {
     if (room.jokerColorConstraint != null) {
        bool isBomb = ['2', '3', 'joker'].contains(card.rank);
        if (isBomb) return true;
        String color = (['hearts','diamonds','red'].contains(card.suit)) ? 'red' : 'black';
        return color == room.jokerColorConstraint;
     }
     if (room.bombStack > 0) {
        if (room.rules['allowBombStacking'] == false) {
           return false; // MUST PICK if stacking disabled
           // Wait, usually player picks via PICK_CARD. So if they try to PLAY a card, it must be valid.
           // If they have a bomb, can they play it? No.
           // But wait, if stacking is false, then a Bomb is an attack that cannot be countered.
           // So NO card is valid? Except maybe Ace/King to block/reverse if allowed?
           // Kadi rules vary. Typically "No Stacking" means you eat the damage.
           // So if stack > 0, you cannot play 2,3,Joker.
        }
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
  


  // ==========================================
  //               HELPERS
  // ==========================================

  void _advanceTurn(GameRoom room, {int skip = 0}) {
     int step = (room.gameType == 'kadi' ? room.direction : 1) * (1 + skip);
     
     // Reset current player stats before moving
     room.players[room.currentPlayerIndex].cardsPlayedThisTurn = 0;
     
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
         p.socket.sink.add(jsonEncode({ 
            "type": "PLAYER_INFO", 
            "data": {
               "players": pList, 
               "myId": p.id,
               "entryFee": room.entryFee // Broadcast Entry Fee
            } 
         }));
      }
  }

  String _generateRoomCode() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    var random = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => letters.codeUnitAt(random.nextInt(letters.length))));
  }

  // Helper method to notify friends when user comes online
  void _notifyFriendsUserOnline(String userId, String username) {
    try {
      // Find the user's friends list
      String? userUsername;
      _users.forEach((uname, userData) {
        if (userData['id'] == userId) {
          userUsername = uname;
        }
      });
      
      if (userUsername == null) return;
      
      final friends = (_users[userUsername]!['friends'] ?? []) as List;
      
      // Notify each accepted friend who is online
      for (var friend in friends) {
        if (friend['status'] == 'accepted') {
          final friendUserId = friend['userId'];
          
          // Check if friend is online
          if (_onlineUsers.containsKey(friendUserId) && _userSockets.containsKey(friendUserId)) {
            // Send notification through WebSocket
            try {
              _userSockets[friendUserId]!.add(jsonEncode({
                'type': 'FRIEND_ONLINE',
                'data': {
                  'friendId': userId,
                  'friendName': username,
                }
              }));
              _log("Notified friend about $username coming online");
            } catch (e) {
              _log("Error sending friend online notification: $e", level: 'ERROR');
            }
          }
        }
      }
    } catch (e) {
      _log("Error in _notifyFriendsUserOnline: $e", level: 'ERROR');
    }
  }
}

void main() {
  MultiGameServer()._start();
}