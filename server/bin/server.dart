import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:io'; // For Platform info if needed
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:mime/mime.dart'; // Ensure mime type check if possible, or just trust extension
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:crypto/crypto.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:dbcrypt/dbcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'database_service.dart';

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
  final String? avatar;
  final WebSocketChannel socket;
  List<CardModel> hand = [];
  
  // Game-Specific State
  bool hasSaidNikoKadi = false; // Kadi
  int cardsPlayedThisTurn = 0; // Kadi Multi-drop
  int books = 0; // Go Fish
  
  Player(this.id, this.name, this.avatar, this.socket);
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
      'forcedSuit': forcedSuit,
      'forcedRank': forcedRank,
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

  final DatabaseService _dbService = DatabaseService();
  String _jwtSecret = "kadi_ke_jwt_secret_2026_pepper_your_salt"; // Fallback

  final DBCrypt _dbcrypt = DBCrypt();

  String _hashPassword(String password) {
    return _dbcrypt.hashpw(password, _dbcrypt.gensalt());
  }

  bool _verifyPassword(String password, String hashed) {
    try {
      return _dbcrypt.checkpw(password, hashed);
    } catch (e) {
      return false;
    }
  }

  String _generateJwt(String userId, String username) {
    final jwt = JWT({
      'userId': userId,
      'username': username,
      'iat': DateTime.now().millisecondsSinceEpoch,
    });
    return jwt.sign(SecretKey(_jwtSecret), expiresIn: Duration(days: 7));
  }

  String? _verifyJwt(String? token) {
    if (token == null) return null;
    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      return jwt.payload['userId'];
    } catch (e) {
      return null;
    }
  }

  void _migrateIfNecessary() {
    final file = File('users.json');
    if (file.existsSync()) {
      try {
        final Map<String, dynamic> usersData = jsonDecode(file.readAsStringSync());
        _log("Found users.json. Migrating to SQLite...");
        _dbService.migrateFromJSON(usersData);
        // Rename file instead of deleting to be safe
        file.renameSync('users.json.migrated');
        _log("Migration complete. users.json renamed to users.json.migrated");
      } catch (e) {
        _log("Migration error: $e", level: 'ERROR');
      }
    }
  }

  void _loadUsers() {
    // No-op - we now use DatabaseService directly
  }

  void _saveUsers() {
    // No-op - we now use DatabaseService directly
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
        if (_dbService.getUserByUsername(username) != null) {
          return Response.ok(jsonEncode({'error': 'Username taken'}), headers: _corsHeaders);
        }
        
        // Check email uniqueness if provided
        final email = data['email'];
        if (email != null && email.toString().isNotEmpty) {
           // This requires a separate DB check, but let's assume getByEmail or filter
           // For now, let's keep it simple or add getUserByEmail to DatabaseService
        }

        final id = DateTime.now().millisecondsSinceEpoch.toString();
        _dbService.saveUser(username, {
           'id': id,
           'password': _hashPassword(password),
           'email': email,
           'wins': 0,
           'coins': 0,
           'created_at': DateTime.now().toIso8601String()
        });
        
        return Response.ok(jsonEncode({
           'status': 'success', 
           'userId': id,
           'token': _generateJwt(id, username)
        }), headers: _corsHeaders);
      } 
      
      else if (path == 'login') {
        _log("Login attempt for user: $username");
        
        final user = _dbService.getUserByUsername(username);
        if (user == null) {
           _log("Login failed: User '$username' not found", level: 'WARNING');
           return Response.ok(jsonEncode({'error': 'Invalid Credentials'}), headers: _corsHeaders);
        }

        final storedHash = user['password'];
        bool success = false;

        if (_verifyPassword(password, storedHash)) {
          success = true;
        } else if (storedHash == sha256.convert(utf8.encode(password)).toString()) {
          _log("Legacy unsalted hash detected for '$username'. Upgrading...");
          _dbService.updateUser(user['id'], {'password': _hashPassword(password)});
          success = true;
        } else if (storedHash == password) {
          _log("Legacy plain-text password detected for '$username'. Upgrading to salted hash...");
          _dbService.updateUser(user['id'], {'password': _hashPassword(password)});
          success = true;
        }

        if (!success) {
           _log("Login failed: Password mismatch for '$username'", level: 'WARNING');
           return Response.ok(jsonEncode({'error': 'Invalid Credentials'}), headers: _corsHeaders);
        }

        _log("Login successful: $username");
        final userId = user['id'];
        return Response.ok(jsonEncode({
           'status': 'success', 
           'userId': userId,
           'token': _generateJwt(userId, username)
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

      final allUsers = _dbService.getAllUsers();
      String? username;
      allUsers.forEach((key, value) {
        if (value['googleId'] == googleId) {
          username = key;
        }
      });

      if (username == null) {
        final String? email = data['email'];
        final String? displayName = data['displayName'];
        
        // Look for user by email (we need a getUserByEmail or find in allUsers)
        final allUsers = _dbService.getAllUsers();
        String? foundUsername;
        allUsers.forEach((u, v) {
          if (v['email'] == email) foundUsername = u;
        });

        if (foundUsername == null) {
          // Create new user for Google Auth
          final id = DateTime.now().millisecondsSinceEpoch.toString();
          // Generate a unique username from display name
          String baseName = (displayName ?? email?.split('@').first ?? "User").replaceAll(' ', '_');
          String uniqueName = baseName;
          int counter = 1;
          while (_dbService.getUserByUsername(uniqueName) != null) {
            uniqueName = "${baseName}_$counter";
            counter++;
          }
          
          _dbService.saveUser(uniqueName, {
            'id': id,
            'username': uniqueName,
            'email': email,
            'password': 'google_auth_no_password',
            'wins': 0,
            'coins': 0,
            'created_at': DateTime.now().toIso8601String()
          });
          foundUsername = uniqueName;
        }
        
        final user = _dbService.getUserByUsername(foundUsername!);
        _log("Created new Google-linked user: $foundUsername");
        username = foundUsername; // Assign foundUsername to the outer scope's username
      }

      final user = _dbService.getUserByUsername(username!);
      return Response.ok(jsonEncode({
        'status': 'success',
        'userId': user!['id'],
        'username': username,
        'token': _generateJwt(user['id'], username!) // Issue real JWT for google login too
      }), headers: _corsHeaders);

    } catch (e) {
      _log("Google Auth Error: $e", level: 'ERROR');
      return Response.internalServerError(body: "Google Auth Error: $e", headers: _corsHeaders);
    }
  }

  // CONFIGURATION
  // Loaded from config.json for security
  String _smtpEmail = ''; 
  String _smtpPassword = ''; 

  void _loadConfig() {
    // Priority 1: Environment Variables
    final envJwt = Platform.environment['JWT_SECRET'];
    if (envJwt != null && envJwt.isNotEmpty) {
      _jwtSecret = envJwt;
      _log("JWT Secret loaded from environment.");
    }

    final configFile = File('config.json');
    if (configFile.existsSync()) {
      try {
        final config = jsonDecode(configFile.readAsStringSync());
        _smtpEmail = config['smtp_email'] ?? '';
        _smtpPassword = config['smtp_password'] ?? '';
        
        if (envJwt == null) {
          final configJwt = config['jwt_secret'];
          if (configJwt != null && configJwt.isNotEmpty) {
            _jwtSecret = configJwt;
            _log("JWT Secret loaded from config.json.");
          }
        }
        
        _log("Configuration loaded.");
      } catch (e) {
        _log("Error loading config.json: $e", level: 'ERROR');
      }
    } else {
      _log("config.json not found. Using defaults/env.", level: 'WARNING');
    }
  }

  Future<void> _sendEmail(String recipient, String subject, String text) async {
    if (_smtpEmail.isEmpty || _smtpPassword.isEmpty || _smtpPassword.contains("INSERT")) {
       _log("Email not sent: SMTP credentials not configured in config.json", level: 'WARNING');
       return;
    }

    // 1. Configure SMTP Server (Using Gmail as default)
    // Note: User must generate an "App Password" from Google Account Security settings
    final smtpServer = gmail(_smtpEmail, _smtpPassword);

    // 2. Create Message
    final message = Message()
      ..from = Address(_smtpEmail, 'Kadi KE Game Support')
      ..recipients.add(recipient)
      ..subject = subject
      ..text = text
      ..html = "<h1>$subject</h1><p>${text.replaceAll('\n', '<br>')}</p>";

    try {
      final sendReport = await send(message, smtpServer);
      _log('Email sent to $recipient: ${sendReport.toString()}');
    } catch (e) {
      _log('Email sending failed: $e', level: 'ERROR');
      // Don't crash the server, just log it.
    }
  }

  Future<Response> _handleForgotPassword(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final email = data['email'];
      
      _log("Forgot password request for: $email");
      
      final allUsers = _dbService.getAllUsers();
      String? targetUsername;
      String? targetId;
      allUsers.forEach((u, v) {
        if (v['email'] == email) {
           targetUsername = u;
           targetId = v['id'];
        }
      });
      
      if (targetUsername == null) {
         return Response.ok(jsonEncode({'status': 'success', 'message': 'If an account exists, a reset code has been sent.'}), headers: _corsHeaders);
      }
      
      // Generate Reset Token
      final token = _generateRoomCode();
      _dbService.updateUser(targetId!, {
        'resetToken': token,
        'resetTokenExpiry': DateTime.now().add(Duration(minutes: 15)).toIso8601String()
      });
      
      _log("Reset Token generated for $targetUsername. Sending email...");
      
      // SEND EMAIL
      await _sendEmail(
        email, 
        "Kadi KE Game - Password Reset", 
        "Your password reset code is: $token\n\nThis code expires in 15 minutes."
      );
      
      return Response.ok(jsonEncode({
        'status': 'success', 
        'message': 'Reset code sent to your email.',
        // 'debug_token': token // REMOVED FOR PRODUCTION SECURITY
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
      
      final allUsers = _dbService.getAllUsers();
      Map<String, dynamic>? userData;
      allUsers.forEach((u, v) {
        if (v['email'] == email) userData = v;
      });
      
      if (userData == null) {
         return Response.ok(jsonEncode({'error': 'Invalid request'}), headers: _corsHeaders);
      }
      
      if (userData!['resetToken'] != token) {
         return Response.ok(jsonEncode({'error': 'Invalid reset token'}), headers: _corsHeaders);
      }
      
      // Check expiry
      if (userData!['resetTokenExpiry'] != null) {
         DateTime expiry = DateTime.parse(userData!['resetTokenExpiry']);
         if (DateTime.now().isAfter(expiry)) {
            return Response.ok(jsonEncode({'error': 'Token expired'}), headers: _corsHeaders);
         }
      }
      
      // Success - Update Password
      _dbService.updateUser(userData!['id'], {
        'password': _hashPassword(newPassword),
        'resetToken': null,
        'resetTokenExpiry': null
      });
      
      _log("Password successfully reset for $email");
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
      final allUsers = _dbService.getAllUsers();
      _log("Fetching leaderboard. Total users in DB: ${allUsers.length}");
      
      var userList = allUsers.entries.map((entry) {
        return {
          'username': entry.key,
          'wins': int.tryParse(entry.value['wins'].toString()) ?? 0,
          'userId': entry.value['id'],
        };
      }).toList();

      userList.sort((a, b) => (b['wins'] as int).compareTo(a['wins'] as int));
      
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
      final authHeader = request.headers['authorization'];
      final token = authHeader?.split(' ').last;
      final userIdFromToken = _verifyJwt(token);

      if (userIdFromToken == null) {
        return Response.forbidden(jsonEncode({'error': 'Invalid or missing authentication token'}), headers: _corsHeaders);
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final username = data['username'];
      final winsToAdd = int.tryParse(data['wins']?.toString() ?? "1") ?? 1;

      _log("Update Stats Request: $username increment by $winsToAdd (Authenticated)");

      final user = _dbService.getUserByUsername(username);
      if (user != null) {
        // Double check: userId from token matches the requested user to update
        if (user['id'] != userIdFromToken) {
           return Response.forbidden(jsonEncode({'error': 'Unauthorized: Cannot update stats for another user'}), headers: _corsHeaders);
        }

        int currentWins = int.tryParse(user['wins']?.toString() ?? "0") ?? 0;
        int newWins = currentWins + winsToAdd;
        _dbService.updateUser(user['id'], {'wins': newWins});
        
        _log("Wins updated for $username: $newWins");
        return Response.ok(jsonEncode({'status': 'success', 'wins': newWins}), headers: _corsHeaders);
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
      final authHeader = request.headers['authorization'];
      final token = authHeader?.split(' ').last;
      final userIdFromToken = _verifyJwt(token);

      if (userIdFromToken == null) {
        return Response.forbidden(jsonEncode({'error': 'Invalid or missing authentication token'}), headers: _corsHeaders);
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final oldUsername = data['oldUsername'];
      final newUsername = data['newUsername'];

      final oldUser = _dbService.getUserByUsername(oldUsername);
      if (oldUser == null || oldUser['id'] != userIdFromToken) {
        return Response.forbidden(jsonEncode({'error': 'Unauthorized profile update attempt'}), headers: _corsHeaders);
      }

      if (_dbService.getUserByUsername(newUsername) != null) {
        return Response.ok(jsonEncode({'error': 'Username already taken'}), headers: _corsHeaders);
      }

      _dbService.updateUsername(oldUsername, newUsername);
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
      final authHeader = request.headers['authorization'];
      final token = authHeader?.split(' ').last;
      final userIdFromToken = _verifyJwt(token);

      if (userIdFromToken == null) {
        return Response.forbidden(jsonEncode({'error': 'Invalid or missing authentication token'}), headers: _corsHeaders);
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final targetUsername = data['targetUsername'];
      
      final requester = _dbService.getUserById(userIdFromToken);
      if (requester == null) {
        return Response.forbidden(jsonEncode({'error': 'Invalid user identification'}), headers: _corsHeaders);
      }
      final requestingUsername = requester['username'];
      final targetUser = _dbService.getUserByUsername(targetUsername);
      
      if (targetUser == null) {
        _log("Friend Request Fail: Target user '$targetUsername' not found", level: 'WARNING');
        return Response.ok(jsonEncode({'error': 'User not found'}), headers: _corsHeaders);
      }
      
      final String targetId = targetUser['id'];
      _log("Sending friend request from $requestingUsername ($userIdFromToken) to $targetUsername ($targetId)");

      // Check if already friends or pending
      final friends = _dbService.getFriends(userIdFromToken);
      if (friends.any((f) => f['userId'] == targetId)) {
        _log("Friend Request Fail: Already friends/pending with $targetUsername");
        return Response.ok(jsonEncode({'error': 'Friend request already exists'}), headers: _corsHeaders);
      }
      
      _dbService.addFriendRequest(targetId, userIdFromToken, requestingUsername);
      _log("Friend request stored in DB for recipient $targetId");
      _log("Friend request sent from $requestingUsername to $targetUsername");
      
      // Notify target user via WebSocket
      if (_userSockets.containsKey(targetUser['id'])) {
         try {
            _userSockets[targetUser['id']]!.add(jsonEncode({
               'type': 'FRIEND_REQUEST',
               'data': {
                  'friendId': userIdFromToken,
                  'friendName': requestingUsername,
               }
            }));
            _log("Live notification sent to $targetUsername for friend request");
         } catch (e) {
            _log("Error sending live friend request notification: $e", level: 'ERROR');
         }
      }

      return Response.ok(jsonEncode({'status': 'success'}), headers: _corsHeaders);
    } catch (e) {
      _log("Friend Request Error: $e", level: 'ERROR');
      return Response.internalServerError(body: jsonEncode({'error': 'Server error'}), headers: _corsHeaders);
    }
  }

  Future<Response> _handleFriendAccept(Request request) async {
    try {
      final authHeader = request.headers['authorization'];
      final token = authHeader?.split(' ').last;
      final userIdFromToken = _verifyJwt(token);

      if (userIdFromToken == null) {
        return Response.forbidden(jsonEncode({'error': 'Invalid or missing authentication token'}), headers: _corsHeaders);
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final friendUserId = data['userId']; // This is the ID of the user who sent the request
      
      final currentUser = _dbService.getUserById(userIdFromToken);
      if (currentUser == null) {
        return Response.ok(jsonEncode({'error': 'Not authenticated'}), headers: _corsHeaders);
      }
      
      final targetUser = _dbService.getUserById(friendUserId); // This is the user who sent the request
      if (targetUser == null) {
        return Response.ok(jsonEncode({'error': 'User not found'}), headers: _corsHeaders);
      }
      
      // Accept the request for the current user (userIdFromToken) from friendUserId
      _dbService.acceptFriendRequest(userIdFromToken, friendUserId);
      // Bi-directional friend entry
      _dbService.addFriendRequest(friendUserId, userIdFromToken, currentUser['username']);
      _dbService.acceptFriendRequest(friendUserId, userIdFromToken);
      
      _log("Friend request accepted: ${currentUser['username']} <-> ${targetUser['username']}");

      // Notify the requester that their request was accepted
      if (_userSockets.containsKey(friendUserId)) {
         try {
            _userSockets[friendUserId]!.add(jsonEncode({
               'type': 'FRIEND_ACCEPT',
               'data': {
                  'friendName': currentUser['username'],
               }
            }));
            _log("Live notification sent to requester for friend acceptance");
         } catch (e) {
            _log("Error sending live friend accept notification: $e", level: 'ERROR');
         }
      }

      return Response.ok(jsonEncode({'status': 'success'}), headers: _corsHeaders);
    } catch (e) {
      _log("Friend Accept Error: $e", level: 'ERROR');
      return Response.internalServerError(body: jsonEncode({'error': 'Server error'}), headers: _corsHeaders);
    }
  }

  Future<Response> _handleFriendRemove(Request request) async {
    try {
      final authHeader = request.headers['authorization'];
      final token = authHeader?.split(' ').last;
      final userIdFromToken = _verifyJwt(token);

      if (userIdFromToken == null) {
        return Response.forbidden(jsonEncode({'error': 'Invalid or missing authentication token'}), headers: _corsHeaders);
      }

      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final friendUserId = data['userId'];
      final currentUser = _dbService.getUserById(userIdFromToken);
      
      if (currentUser == null) {
        return Response.ok(jsonEncode({'error': 'Not authenticated'}), headers: _corsHeaders);
      }
      
      _dbService.removeFriend(userIdFromToken, friendUserId);
      _log("Friend removed: $userIdFromToken and $friendUserId");
      return Response.ok(jsonEncode({'status': 'success'}), headers: _corsHeaders);
    } catch (e) {
      _log("Friend Remove Error: $e", level: 'ERROR');
      return Response.internalServerError(body: jsonEncode({'error': 'Server error'}), headers: _corsHeaders);
    }
  }

  Future<Response> _handleFeedback(Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);

      // Log to DB
      _dbService.saveFeedback(data);

      // Log to file for easy dev access
      final logFile = File('feedback.log');
      final logEntry = "[${DateTime.now().toIso8601String()}] User: ${data['username']} (${data['userId']}) | Type: ${data['type']} | Message: ${data['message']}\n";
      await logFile.writeAsString(logEntry, mode: FileMode.append);

      _log("Feedback received from ${data['username']}: ${data['message']}");
      return Response.ok(jsonEncode({'status': 'success'}), headers: _corsHeaders);
    } catch (e) {
      _log("Feedback Error: $e", level: 'ERROR');
      return Response.internalServerError(body: jsonEncode({'error': 'Server error'}), headers: _corsHeaders);
    }
  }

  Future<Response> _handleFriendsList(Request request) async {
    try {
      final authHeader = request.headers['authorization'];
      final token = authHeader?.split(' ').last;
      final userIdFromToken = _verifyJwt(token);

      if (userIdFromToken == null) {
        return Response.forbidden(jsonEncode({'error': 'Invalid or missing authentication token'}), headers: _corsHeaders);
      }

      final friends = _dbService.getFriends(userIdFromToken);
      _log("Fetching friends list for $userIdFromToken. Found ${friends.length} entries in DB.");
      final enrichedFriends = <Map<String, dynamic>>[];

      for (var friend in friends) {
         try {
            final friendData = _dbService.getUserById(friend['userId']);

            if (friendData != null) {
                bool isOnline = _onlineUsers.containsKey(friend['userId']);

                enrichedFriends.add({
                   'userId': friend['userId'],
                   'username': friendData['username'], 
                   'status': friend['status'],
                   'wins': friendData['wins'] ?? 0,
                   'isOnline': isOnline,
                   'createdAt': friend['createdAt'],
                   'avatar': friendData['avatar'] ?? 'assets/avatars/default.png',
                });
            } else {
                enrichedFriends.add({
                   'userId': friend['userId'],
                   'username': friend['username'], 
                   'status': friend['status'],
                   'wins': 0,
                   'isOnline': false,
                   'createdAt': friend['createdAt'],
                });
            }
         } catch (e) {
            _log("Error processing friend ${friend['userId']}: $e", level: 'ERROR');
         }
      }
      
      return Response.ok(jsonEncode({'friends': enrichedFriends}), headers: _corsHeaders);
    } catch (e, stack) {
      _log("Friends List Critical Error: $e\n$stack", level: 'ERROR');
      return Response.internalServerError(body: jsonEncode({'error': 'Server error'}), headers: _corsHeaders);
    }
  }

  Future<Response> _handleFriendSearch(Request request) async {
    try {
      final username = request.url.queryParameters['username'] ?? '';
      
      if (username.isEmpty) {
        return Response.ok(jsonEncode({'users': []}), headers: _corsHeaders);
      }
      
      final allUsers = _dbService.getAllUsers();
      final results = <Map<String, dynamic>>[];
      allUsers.forEach((key, userData) {
        if (key.toLowerCase().contains(username.toLowerCase())) {
          results.add({
            'userId': userData['id'],
            'username': key,
            'wins': userData['wins'] ?? 0,
            'avatar': userData['avatar'],
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
    _dbService.initialize();
    _migrateIfNecessary();
    _loadConfig();

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
               String token = decoded['token'] ?? '';
               String username = decoded['username'] ?? '';
               
               final userIdFromToken = _verifyJwt(token);

               if (userIdFromToken != null) {
                 // Track online user
                 _onlineUsers[userIdFromToken] = username;
                 _userSockets[userIdFromToken] = socket.sink;
                 
                 // Notify friends that user came online
                 _notifyFriendsUserOnline(userIdFromToken, username);
                 
                 _log("User $username ($userIdFromToken) came online (Authenticated)");
                 playerId = userIdFromToken; // Support reconnect context
               } else {
                 _log("Unauthorized WebSocket JOIN attempt from $username", level: 'WARNING');
                 socket.sink.add(jsonEncode({"type": "ERROR", "data": "Unauthorized connection"}));
               }
               return; 
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
               
               // CRITICAL FIX: Use authenticated playerId if available 
               String finalPlayerId = playerId ?? DateTime.now().millisecondsSinceEpoch.toString();
               String playerName = _onlineUsers[finalPlayerId] ?? data['playerName'] ?? "Host"; 
               
               // Fetch Avatar
               var userData = _dbService.getUserById(finalPlayerId);
               String? avatar = userData?['avatar'];

               Player newPlayer = Player(finalPlayerId, playerName, avatar, socket);
               _rooms[roomCode]!.players.add(newPlayer);
               playerId = finalPlayerId; // Set current context playerId

               socket.sink.add(jsonEncode({"type": "ROOM_CREATED", "data": roomCode}));
               _broadcastPlayerInfo(_rooms[roomCode]!); // Update lobby
               
               _log("Room Created: $roomCode by $playerName. Rules: ${_rooms[roomCode]!.rules}");
             }
             else if (type == 'JOIN_GAME') {
               String code = data['roomCode'].toString().toUpperCase();
               String name = data['name'];
               
               if (_rooms.containsKey(code)) {
                 currentRoomCode = code;
                 
                 // CRITICAL FIX: Use authenticated playerId if available
                 String finalPlayerId = playerId ?? DateTime.now().millisecondsSinceEpoch.toString();
                 String finalName = _onlineUsers[finalPlayerId] ?? name;

                 // Fetch Avatar
                 var userData = _dbService.getUserById(finalPlayerId);
                 String? avatar = userData?['avatar'];

                 // PREVENT DUPLICATE JOIN
                 bool alreadyIn = _rooms[code]!.players.any((p) => p.id == finalPlayerId);
                 if (!alreadyIn) {
                   Player newPlayer = Player(finalPlayerId, finalName, avatar, socket);
                   _rooms[code]!.players.add(newPlayer);
                   _log("Player $finalName ($finalPlayerId) joined room $code");
                 } else {
                   _log("Player $finalName ($finalPlayerId) already in room $code, updated socket");
                 }
                 
                 playerId = finalPlayerId; // Set current context playerId
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
             
             // --- SOCIAL ACTIONS ---
             else if (type == 'INVITE') {
                String targetUserId = data['targetUserId'];
                String roomCode = data['roomCode'];
                String? ipAddress = data['ipAddress'];
                String senderName = data['senderName'] ?? "Someone";
                String gameType = data['gameType'] ?? 'kadi';

                if (_userSockets.containsKey(targetUserId)) {
                   _userSockets[targetUserId]!.add(jsonEncode({
                      'type': 'GAME_INVITE',
                      'data': {
                         'friendName': senderName,
                         'roomCode': roomCode,
                         'ipAddress': ipAddress ?? '',
                         'gameType': gameType,
                      }
                   }));
                   _log("Routed $gameType invite from $senderName to $targetUserId");
                } else {
                   _log("Invite failed: $targetUserId not online", level: 'WARNING');
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

          if (playerId != null) {
             String username = _onlineUsers[playerId!] ?? "Unknown";
             _onlineUsers.remove(playerId);
             _userSockets.remove(playerId);
             _notifyFriendsUserOffline(playerId!, username);
             _log("User $username ($playerId) went offline");
          }
        }, onError: (error) {
           _log("WebSocket Error: $error", level: 'ERROR');
        });
      },
      // ✅ VITAL FIX: Keep connection alive by pinging every 10 seconds
      pingInterval: Duration(seconds: 10), 
    );

    // Main Pipeline with Health & Auth
    // Static Handler for Uploads
    var staticHandler = createStaticHandler('bin/uploads', defaultDocument: 'index.html'); 

    var handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler((Request request) async {
         if (request.method == 'OPTIONS') {
           return Response.ok('', headers: _corsHeaders);
         }
         
         final path = request.url.path;

         // Static Files
         if (path.startsWith('uploads/')) {
            final p = path.replaceFirst('uploads/', '');
            return staticHandler(request.change(path: p)); 
         }

         if (path == 'health') {
            return Response.ok(jsonEncode({
              'status': 'ok',
              'rooms': _rooms.length,
              'online_users': _onlineUsers.length,
              'version': '13.1.0+43',
              'uptime': DateTime.now().millisecondsSinceEpoch,
            }), headers: {'content-type': 'application/json'});
         }
         
         if (path == 'register' || path == 'login') {
            return _handleAuth(request);
         }
         if (path == 'leaderboard') {
            return _handleLeaderboard(request);
         }
         if (path == 'update_stats') {
            return _handleUpdateStats(request);
         }
         if (path == 'active_rooms') {
            return _handleActiveRooms(request);
         }
         if (path == 'update_profile') {
            return _handleUpdateProfile(request);
         }
         if (path == 'submit_feedback') {
            return _handleFeedback(request);
         }
         if (path == 'forgot_password') {
            return _handleForgotPassword(request);
         }
         if (path == 'reset_password') {
            return _handleResetPassword(request);
         }
         if (path == 'google_login') {
            return _handleGoogleAuth(request);
         }
         if (path == 'friends/request') return _handleFriendRequest(request);
         if (path == 'friends/accept') return _handleFriendAccept(request);
         if (path == 'friends/remove') return _handleFriendRemove(request);
         if (path == 'friends/list') return _handleFriendsList(request);
         if (path == 'friends/search') return _handleFriendSearch(request);
         if (path == 'upload_avatar') return _handleUploadAvatar(request);
         if (path == 'submit_feedback') return _handleSubmitFeedback(request);


         return wsHandler(request);
      });

    // Port selection: Environment variable or default 8080
    final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
    
    // Listen on 0.0.0.0
    var server = await shelf_io.serve(handler, '0.0.0.0', port);
    _log('Game Server running on port ${server.port} (JWT Secret: ${_jwtSecret.substring(0, 3)}...)');
  }

  Future<Response> _handleSubmitFeedback(Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final message = body['message']?.toString().trim() ?? '';
      final userId  = body['userId']?.toString() ?? 'anonymous';

      if (message.isEmpty) {
        return Response(400, body: jsonEncode({'error': 'Message is required'}), headers: {'content-type': 'application/json', ..._corsHeaders});
      }

      final timestamp = DateTime.now().toIso8601String();
      final logLine = '[$timestamp] [$userId] $message\n';

      // Append to feedback.log next to the database
      final logFile = File('feedback.log');
      await logFile.writeAsString(logLine, mode: FileMode.append);

      _log('Feedback received from $userId: ${message.substring(0, message.length.clamp(0, 60))}...');
      return Response.ok(jsonEncode({'success': true}), headers: {'content-type': 'application/json', ..._corsHeaders});
    } catch (e) {
      return Response(500, body: jsonEncode({'error': e.toString()}), headers: {'content-type': 'application/json', ..._corsHeaders});
    }
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
       if (type == 'SAY_NIKO_KADI') {
          int pIndex = room.players.indexWhere((p) => p.id == pid);
          if (pIndex != -1) {
            room.players[pIndex].hasSaidNikoKadi = true;
            room.broadcast("CHAT", {
              "sender": room.players[pIndex].name, 
              "message": "Niko Kadi!",
              "isSystem": false,
              "isNikoKadi": true,
              "playerIndex": pIndex
            });
          }
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
        
        // UPDATE STATS
        _handleWin(room, winner);
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
         // Ace blocks Bomb
         if (room.bombStack > 0 && !isBomb) {
            room.bombStack = 0; room.forcedSuit = null; room.forcedRank = null;
            room.broadcast("CHAT", {"sender": "System", "message": "Bomb Blocked!"});
         } else {
            room.bombStack = 0;
            
            // LOKI/LOCK Blocking Logic (Sync with local engine)
            if (room.forcedSuit != null && room.forcedRank != null) {
               if (player.cardsPlayedThisTurn == 1) {
                  // One-Ace Block: Keep what the current player requested
                  room.forcedSuit = data['requestedSuit'];
                  room.forcedRank = data['requestedRank'];
                  
                  String msg = "Partial Block!";
                  if (room.forcedSuit != null && room.forcedRank == null) msg = "Blocking Rank! Suit ${room.forcedSuit!.toUpperCase()} continues.";
                  if (room.forcedRank != null && room.forcedSuit == null) msg = "Blocking Suit! Rank ${room.forcedRank} continues.";
                  room.broadcast("CHAT", {"sender": "System", "message": msg});
               } else {
                  // Two-Ace Block: Clear everything
                  room.forcedSuit = null;
                  room.forcedRank = null;
                  room.broadcast("CHAT", {"sender": "System", "message": "FULL BLOCK!"});
               }
            } else {
               // Standard Ace Logic / Spades Lock
               if (card.suit == 'spades' && player.hand.length == 1) {
                   CardModel last = player.hand[0];
                   room.forcedSuit = last.suit; 
                   room.forcedRank = last.rank;
                   room.broadcast("CHAT", {"sender": "System", "message": "🔒 LOCKED: ${last.rank} of ${last.suit}"});
               } else {
                   // Standard Request (Suit/Rank)
                   room.forcedSuit = data['requestedSuit'] ?? card.suit;
                   room.forcedRank = data['requestedRank'];
                   room.broadcast("CHAT", {"sender": "System", "message": "Request: ${room.forcedSuit ?? room.forcedRank}"});
               }
            }
         }
      } else {
         // If playing a Bomb, we clear Requests (Override)
         if (isBomb) {
             room.forcedSuit = null;
             room.forcedRank = null;
         }
         // If playing a valid card into a Request, clear it
         else if (room.forcedSuit != null || room.forcedRank != null) {
            room.forcedSuit = null; room.forcedRank = null;
         }
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

     // Multi-drop Check (allow dropping duplicates or bombs)
     if (turnEnds && skip == 0 && player.hand.isNotEmpty) {
        bool canMultiDrop = player.hand.any((c) => c.rank == card.rank);
        bool isBombChain = isBomb && player.hand.any((c) => ['2', '3', 'joker'].contains(c.rank));
        
        if (canMultiDrop || isBombChain) {
           turnEnds = false;
           String msg = canMultiDrop ? "Multi-drop: Play another ${card.rank} or Pick" : "Bomb Chain! Play another Bomb or Pick";
           room.broadcast("CHAT", {"sender": "System", "message": msg});
        }
     }

     // Win Check
     if (player.hand.isEmpty) {
         // Power Card restriction
         // Winning Cards: 4, 5, 6, 7, 9, 10
         // Non-Winning (Power): 2, 3, 8, J, Q, K, A, Joker
         if (['2','3','8','jack','queen','king','ace','joker'].contains(card.rank)) {
            room.broadcast("CHAT", {"sender": "System", "message": "Cannot win with Power Card! Pick 1."});
            _handleKadiPick(room, pIndex, penalty: 1); // Force pick
            return;
         }
        // --- OPTIONAL CARDLESS BLOCKER RULE ---
        if (room.rules['cardlessBlocker'] == true) {
           bool anyoneElseCardless = false;
           for (int i = 0; i < room.players.length; i++) {
             if (i != pIndex && room.players[i].hand.isEmpty) {
               anyoneElseCardless = true;
               break;
             }
           }

           if (anyoneElseCardless) {
              room.broadcast("CHAT", {"sender": "Referee", "message": "Multiple finishers! Win blocked by House Rule."});
              _handleKadiPick(room, pIndex, penalty: 1); // Reduced penalty
              return;
           }
        }
        
        // Niko Kadi Penalty
        if (!player.hasSaidNikoKadi) {
             room.broadcast("CHAT", {"sender": "Referee", "message": "Forgot Niko Kadi! +2 Cards"});
             _handleKadiPick(room, pIndex, penalty: 2);
             return;
        }

        room.broadcast("GAME_OVER", "${player.name} Wins!");
        _log("Game Over in room ${room.code}. Winner: ${player.name}");
        
        // UPDATE STATS
        _handleWin(room, player);
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

      // Ace Request Persistence: Picking does NOT clear the request unless it's a Bomb clear
      // If picking due to penalty/bomb, we usually clear.
      // But if picking because we don't have the suit, the req persists.
      // So only clear if bombStack > 0 (bomb sequence overrides request)
      if (room.bombStack > 0) {
          room.forcedSuit = null; 
          room.forcedRank = null;
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
      
      // Do NOT clear forcedSuit/forcedRank here unconditionally.
      // We already handled clearing it above ONLY if bombStack > 0.
      
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
     // 1. Bomb Override (Bomb can be played on ANY suit/rank/constraint/lock)
     if (['2','3','joker'].contains(card.rank)) return true;

     // 2. Joker Constraint (Highest Priority if not bomb)
     if (room.jokerColorConstraint != null) {
        String color = (['hearts','diamonds','red'].contains(card.suit)) ? 'red' : 'black';
        return color == room.jokerColorConstraint;
     }

     // 3. Bomb Defense
     if (room.bombStack > 0) {
        // Stack already handled by #1
        // Defense: Ace, King, Jack are valid
        if (['ace','king','jack'].contains(card.rank)) return true;
        return false;
     }

     // 4. Question Logic
     if (room.waitingForAnswer) {
        if (card.rank == 'queen' || card.rank == '8') return card.suit == room.topCard!.suit || card.rank == room.topCard!.rank;
        if (['4','5','6','7','9','10'].contains(card.rank)) return card.suit == room.topCard!.suit;
        return false;
     }

     // 5. Ace Counter-Play
     if (card.rank == 'ace') return true;

     // 6. Forced Suit/Rank (Lock)
     if (room.forcedRank != null && room.forcedSuit != null) return card.rank == room.forcedRank && card.suit == room.forcedSuit;
     if (room.forcedRank != null) return card.rank == room.forcedRank;
     if (room.forcedSuit != null) return card.suit == room.forcedSuit;
     
     // 7. Standard Play
     return card.suit == room.topCard!.suit || card.rank == room.topCard!.rank;
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
        {'id': e.value.id, 'name': e.value.name, 'avatar': e.value.avatar, 'index': e.key}
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

  void _notifyFriendsUserOnline(String userId, String username) {
    _broadcastFriendStatus(userId, username, true);
  }

  void _notifyFriendsUserOffline(String userId, String username) {
    _broadcastFriendStatus(userId, username, false);
  }

  void _broadcastFriendStatus(String userId, String username, bool isOnline) {
    try {
      final friends = _dbService.getFriends(userId);
      for (var friend in friends) {
        if (friend['status'] == 'accepted') {
          final friendUserId = friend['userId'];
          if (_userSockets.containsKey(friendUserId)) {
            try {
              _userSockets[friendUserId]!.add(jsonEncode({
                'type': isOnline ? 'FRIEND_ONLINE' : 'FRIEND_OFFLINE',
                'data': {
                  'friendId': userId,
                  'friendName': username,
                }
              }));
            } catch (e) {
              _log("Error sending status notification: $e", level: 'ERROR');
            }
          }
        }
      }
    } catch (e) {
      _log("Error in _broadcastFriendStatus: $e", level: 'ERROR');
    }
  }

  // ==========================================
  //            WIN HANDLING
  // ==========================================

  void _handleWin(GameRoom room, Player winner) {
     // 1. Update DB
     _dbService.incrementWins(winner.id);
     
     int coins = 100;
     // Pot Logic
     if (room.entryFee > 0) {
        coins = room.entryFee * room.players.length; 
        // Or specific pot logic
     }
     
     _dbService.incrementCoins(winner.id, coins);
     
     // 2. Broadcast Validated Stats Update
     // The client will receive this and update its local UserProvider
     winner.socket.sink.add(jsonEncode({
        "type": "STATS_UPDATE",
        "data": {
           "wins": 1, 
           "coins": coins
        }
     }));
  }

  // ==========================================
  //            UPLOAD HANDLING
  // ==========================================

  Future<Response> _handleUploadAvatar(Request request) async {
     if (!request.isMultipart) {
        return Response.badRequest(body: 'Not a multipart request');
     }
     
     // Verify Auth (Optional - usually we check token header)
     final token = request.headers['Authorization']?.replaceAll('Bearer ', '');
     if (token == null) return Response.forbidden('Missing Token');
     
     String? userId;
     try {
       final jwt = JWT.verify(token, SecretKey(_jwtSecret));
       userId = jwt.payload['id'];
     } catch (e) {
       return Response.forbidden('Invalid Token');
     }

     if (userId == null) return Response.forbidden('Invalid User');

     try {
       await for (final part in request.parts) {
         if (part.headers['content-disposition']?.contains('filename=') ?? false) {
            // It's a file
            final filename = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg'; // Force jpg or detect?
            
            // Ensure directory exists
            final directory = Directory('bin/uploads/avatars');
            if (!await directory.exists()) {
               await directory.create(recursive: true);
            }

            final file = File('${directory.path}/$filename');
            final sink = file.openWrite();
            await part.pipe(sink);
            await sink.close();
            
            // Construct URL - assuming server at same host
            // Client needs to know host. We return relative path.
            final url = '/uploads/avatars/$filename';
            
            // Update DB
            _dbService.updateUser(userId, {'avatar': url});
            
            return Response.ok(jsonEncode({'url': url, 'message': 'Avatar Uploaded'}), headers: _corsHeaders);
         }
       }
       return Response.badRequest(body: 'No file found');
     } catch (e) {
       _log('Upload Error: $e', level: 'ERROR');
       return Response.internalServerError(body: 'Upload failed');
     }
  }

}

void main() {
  MultiGameServer()._start();
}