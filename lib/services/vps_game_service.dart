import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'custom_auth_service.dart';
import 'notification_service.dart';
import 'app_config.dart';

/// VPS-based online game service using WebSockets
/// Replaces FirebaseGameService for online multiplayer
class VPSGameService {
  static final VPSGameService _instance = VPSGameService._internal();
  factory VPSGameService() => _instance;
  VPSGameService._internal();

  String get wsUrl => AppConfig.wsUrl;
  String get httpUrl => AppConfig.baseUrl;

  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _gameStreamController = StreamController.broadcast();
  
  Stream<Map<String, dynamic>> get gameStream => _gameStreamController.stream;
  
  final StreamController<String> _tickerStreamController = StreamController<String>.broadcast();
  Stream<String> get tickerStream => _tickerStreamController.stream;

  final StreamController<Map<String, dynamic>> _clanChatStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get clanChatStream => _clanChatStreamController.stream;
  
  // In-memory cache of clan chat messages, keyed by clanId.
  // Persists across screen navigations within the same app session.
  final Map<String, List<Map<String, dynamic>>> _clanChatCache = {};
  static const int _maxCachedMessages = 100;

  /// Returns cached messages for a clan (call before listening to stream)
  List<Map<String, dynamic>> getCachedMessages(String clanId) {
    return List.unmodifiable(_clanChatCache[clanId] ?? []);
  }
  
  String? _currentGameCode;
  int _reconnectDelay = 1000; // Start with 1s
  static const int _maxReconnectDelay = 30000; // Max 30s
  Timer? _reconnectTimer;
  bool _isManuallyClosed = false;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  String? get currentGameCode => _currentGameCode;

  /// Connect to the VPS WebSocket server
  Future<void> connect() async {
    if (_isConnected) return;
    _isManuallyClosed = false;

    print('Connecting to VPS: $wsUrl...');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Mark connected immediately — the handshake is lazy but the socket is
      // open. onDone/onError below will flip it back to false if it fails.
      _isConnected = true;
      _reconnectDelay = 1000;
      print('WebSocket channel opened.');
      
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            
            if (data['type'] == 'ERROR' && data['data'] == 'Unauthorized connection') {
               print('Server rejected WebSocket connection: Unauthorized');
               leaveGame();
               return;
            }

            if (data['type'] == 'GLOBAL_TICKER') {
              _tickerStreamController.add(data['data'].toString());
              return;
            }

            if (data['type'] == 'CLAN_CHAT_MESSAGE') {
              final chatData = Map<String, dynamic>.from(data['data']);
              // Cache the message
              final clanId = chatData['clanId'] as String? ?? '__default__';
              _clanChatCache.putIfAbsent(clanId, () => []);
              _clanChatCache[clanId]!.add(chatData);
              if (_clanChatCache[clanId]!.length > _maxCachedMessages) {
                _clanChatCache[clanId]!.removeAt(0);
              }
              _clanChatStreamController.add(chatData);
              return;
            }

            _gameStreamController.add(data);
          } catch (e) {
            print('Error parsing message: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          print('WebSocket connection closed.');
          if (!_isManuallyClosed) {
            _scheduleReconnect();
          }
        },
        onError: (error) {
          _isConnected = false;
          print('WebSocket error: $error');
          if (!_isManuallyClosed) {
            _scheduleReconnect();
          }
        },
      );

      // Authenticate WebSocket connection
      _authenticate();

    } catch (e) {
      _isConnected = false;
      print('Failed to connect to VPS: $e');
      _scheduleReconnect();
    }
  }

  void _authenticate() async {
    final token = CustomAuthService().token;
    final username = CustomAuthService().username;
    final userId = CustomAuthService().userId;
    print("VPSGameService _authenticate: token=${token != null}, user=$username, id=$userId");

    if (token != null && username != null) {
      String? fcmToken = await NotificationService().getFCMToken();
      
      _channel?.sink.add(jsonEncode({
        'action': 'JOIN',
        'token': token,
        'username': username,
        'userId': userId,
        'fcmToken': fcmToken,
      }));
    } else {
      print("VPSGameService _authenticate: Skipped - token or username is null.");
    }
  }

  void _scheduleReconnect() {
    if (_isManuallyClosed) return;
    
    _reconnectTimer?.cancel();
    print('Scheduling reconnect in ${_reconnectDelay}ms...');
    
    _reconnectTimer = Timer(Duration(milliseconds: _reconnectDelay), () {
      _reconnectDelay = (_reconnectDelay * 2).clamp(1000, _maxReconnectDelay);
      connect();
    });
  }

  /// Create a new online game room
  Future<String> createGame(String gameType, {int entryFee = 0, Map<String, dynamic>? rules}) async {
    await connect();
    
    final completer = Completer<String>();
    late StreamSubscription subscription;

    subscription = gameStream.listen((data) {
      if (data['type'] == 'ROOM_CREATED') {
        _currentGameCode = data['data'];
        completer.complete(_currentGameCode!);
        subscription.cancel();
      }
    });

    String playerName = CustomAuthService().username ?? "Player";
    
    _channel!.sink.add(jsonEncode({
      'type': 'CREATE_GAME',
      'gameType': gameType,
      'entryFee': entryFee,
      'rules': rules,
      'playerName': playerName, // Added player name
    }));

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        subscription.cancel();
        throw Exception('Room creation timeout');
      },
    );
  }

  /// Send a clan chat message
  void sendClanChat(String clanId, String message) {
    print("sendClanChat: isConnected=$_isConnected, clanId=$clanId");
    if (!_isConnected || _channel == null) {
      print("sendClanChat: Not connected — attempting reconnect before send.");
      connect().then((_) {
        // Short delay to let the JOIN handshake complete
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_isConnected && _channel != null) {
            _channel!.sink.add(jsonEncode({
              'type': 'CLAN_CHAT',
              'data': {'clanId': clanId, 'message': message},
            }));
          }
        });
      });
      return;
    }
    _channel!.sink.add(jsonEncode({
      'type': 'CLAN_CHAT',
      'data': {'clanId': clanId, 'message': message},
    }));
  }

  /// Fetch clan chat history from the server (last 50 messages).
  /// Merges with the in-memory cache so duplicates are avoided.
  Future<void> fetchClanChatHistory(String clanId) async {
    try {
      final token = CustomAuthService().token;
      final response = await http.get(
        Uri.parse('$httpUrl/api/clans/chat_history?clanId=$clanId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> msgs = data['messages'] ?? [];
        final existingIds = (_clanChatCache[clanId] ?? [])
            .map((m) => '${m['senderId']}${m['timestamp']}')
            .toSet();
        for (final m in msgs) {
          final msg = Map<String, dynamic>.from(m);
          final key = '${msg['senderId']}${msg['timestamp']}';
          if (!existingIds.contains(key)) {
            _clanChatCache.putIfAbsent(clanId, () => []).add(msg);
          }
        }
        // Sort by timestamp ascending
        _clanChatCache[clanId]?.sort((a, b) =>
            (a['timestamp'] as String).compareTo(b['timestamp'] as String));
      }
    } catch (e) {
      print('fetchClanChatHistory error: $e');
    }
  }

  Future<void> joinGame(String roomCode, String playerName) async {
    await connect();
    _currentGameCode = roomCode;

    _channel!.sink.add(jsonEncode({
      'type': 'JOIN_GAME',
      'roomCode': roomCode,
      'name': playerName,
    }));
  }

  /// Create a new tournament
  Future<Map<String, dynamic>> createTournament(String name, String gameType, int maxPlayers, int entryFee) async {
    await connect();
    
    final completer = Completer<Map<String, dynamic>>();
    late StreamSubscription subscription;

    subscription = gameStream.listen((data) {
      print('gameStream received: $data');
      if (data['type'] == 'TOURNAMENT_CREATED') {
         try {
           // Ensure we safely extract the ID
           var payload = data['data'];
           if (payload is String) payload = jsonDecode(payload);
           
           print('Parsed ID: ${payload['id']}');
           completer.complete(payload);
         } catch (e) {
           print('Error parsing: $e');
           completer.completeError('Failed to parse tournament ID: $e');
         }
         subscription.cancel();
      } else if (data['type'] == 'ERROR') {
        print('Error from server: ${data['data']}');
        completer.completeError(data['data']);
        subscription.cancel();
      }
    });

    String playerName = CustomAuthService().username ?? "Player";
    
    _channel!.sink.add(jsonEncode({
      'type': 'CREATE_TOURNAMENT',
      'name': name,
      'gameType': gameType,
      'maxPlayers': maxPlayers,
      'entryFee': entryFee,
      'playerName': playerName,
    }));

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        subscription.cancel();
        throw Exception('Tournament creation timeout');
      },
    );
  }

  /// Join an existing tournament
  Future<Map<String, dynamic>> joinTournament(String tournamentId) async {
    await connect();
    
    final completer = Completer<Map<String, dynamic>>();
    late StreamSubscription subscription;

    subscription = gameStream.listen((data) {
      if (data['type'] == 'TOURNAMENT_UPDATED') {
         try {
           var payload = data['data'];
           if (payload is String) payload = jsonDecode(payload);
           if (payload['id'] == tournamentId) {
              completer.complete(payload);
              subscription.cancel();
           }
         } catch (e) {
           completer.completeError('Failed to parse tournament data: $e');
           subscription.cancel();
         }
      } else if (data['type'] == 'ERROR') {
        completer.completeError(data['data']);
        subscription.cancel();
      }
    });

    String playerName = CustomAuthService().username ?? "Player";

    _channel!.sink.add(jsonEncode({
      'type': 'JOIN_TOURNAMENT',
      'tournamentId': tournamentId,
      'playerName': playerName,
    }));

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        subscription.cancel();
        throw Exception('Tournament join timeout');
      },
    );
  }

  /// Start a tournament (Host only)
  Future<void> startTournament(String tournamentId) async {
    if (!_isConnected || _channel == null) return;
    
    _channel!.sink.add(jsonEncode({
      'type': 'START_TOURNAMENT',
      'tournamentId': tournamentId,
    }));
  }

  /// Report tournament match result
  Future<void> reportTournamentMatch(String tournamentId, String matchId, String winnerId) async {
    if (!_isConnected || _channel == null) return;
    
    _channel!.sink.add(jsonEncode({
      'type': 'REPORT_TOURNAMENT_MATCH',
      'tournamentId': tournamentId,
      'matchId': matchId,
      'winnerId': winnerId,
    }));
  }

  /// Send a game action to the server
  void sendAction(String type, Map<String, dynamic> data) {
    if (!_isConnected || _channel == null) {
      print('Cannot send action: not connected');
      return;
    }

    _channel!.sink.add(jsonEncode({
      'type': type,
      ...data,
    }));
  }

  /// Send a game invite to a friend
  void sendInvite(String targetUserId, String roomCode, {String? ipAddress, String gameType = 'kadi'}) {
    final senderName = CustomAuthService().username ?? "Someone";
    sendAction('INVITE', {
      'targetUserId': targetUserId,
      'roomCode': roomCode,
      'ipAddress': ipAddress ?? '',
      'senderName': senderName,
      'gameType': gameType,
    });
  }

  /// Leave the current game
  void leaveGame() {
    _isManuallyClosed = true;
    _reconnectTimer?.cancel();
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    _isConnected = false;
    _currentGameCode = null;
  }

  /// Fetch active rooms for matchmaking
  Future<List<Map<String, dynamic>>> getActiveRooms() async {
    try {
      final response = await http.get(Uri.parse('$httpUrl/active_rooms'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      print('Error fetching active rooms: $e');
      return [];
    }
  }

  /// Fetch active tournaments from VPS
  Future<List<Map<String, dynamic>>> getActiveTournaments() async {
    try {
      final response = await http.get(Uri.parse('$httpUrl/active_tournaments'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      print('Error fetching active tournaments: $e');
      return [];
    }
  }

  /// Automated matchmaking: Join an existing room or create a new one
  Future<Map<String, dynamic>> findMatch(String gameType, {int entryFee = 0}) async {
    final rooms = await getActiveRooms();
    
    // Find a room that matches game type and has space
    final match = rooms.firstWhere(
      (r) => r['gameType'] == gameType && r['entryFee'] <= entryFee,
      orElse: () => {},
    );

    if (match.isNotEmpty) {
      String code = match['code'];
      String playerName = CustomAuthService().username ?? "Player";
      await joinGame(code, playerName);
      return {'roomCode': code, 'isHost': false};
    } else {
      // No match found, create a new room
      String code = await createGame(gameType, entryFee: entryFee);
      return {'roomCode': code, 'isHost': true};
    }
  }

  /// Fetch leaderboard from VPS
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    try {
      final response = await http.get(Uri.parse('$httpUrl/leaderboard'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['leaderboard'] ?? []);
      } else {
        print('Leaderboard request failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return [];
    }
  }

  /// Update user stats (wins) on VPS
  Future<void> updateStats({int wins = 1, bool isLan = false}) async {
    try {
      final username = CustomAuthService().username;
      if (username == null) {
        print('Cannot update stats: user not logged in');
        return;
      }

      final token = CustomAuthService().token;
      final response = await http.post(
        Uri.parse('$httpUrl/update_stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'username': username,
          'wins': wins,
          'isLan': isLan,
        }),
      );

      if (response.statusCode != 200) {
        print('Stats update failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating stats: $e');
    }
  }

  /// Submit feedback/report to VPS
  Future<bool> submitFeedback(Map<String, dynamic> reportData) async {
    try {
      final token = CustomAuthService().token;
      final username = CustomAuthService().username;
      
      final response = await http.post(
        Uri.parse('$httpUrl/submit_feedback'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'username': username ?? 'anonymous',
          'userId': CustomAuthService().userId ?? 'unknown',
          ...reportData,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error submitting feedback: $e');
      return false;
    }
  }

  void dispose() {
    leaveGame();
    _gameStreamController.close();
  }
}
