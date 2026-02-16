import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'custom_auth_service.dart';
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
      
      // Wait for a small moment to verify connection
      // WebSocketChannel.connect is lazy, it doesn't wait for the handshake.
      
      _channel!.stream.listen(
        (message) {
          if (!_isConnected) {
            _isConnected = true;
            _reconnectDelay = 1000; // Reset delay on successful message
            print('Connected to VPS successfully.');
          }
          
          try {
            final data = jsonDecode(message);
            
            if (data['type'] == 'ERROR' && data['data'] == 'Unauthorized connection') {
               print('Server rejected WebSocket connection: Unauthorized');
               leaveGame();
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

  void _authenticate() {
    final token = CustomAuthService().token;
    final username = CustomAuthService().username;
    final userId = CustomAuthService().userId;

    if (token != null && username != null) {
      _channel?.sink.add(jsonEncode({
        'action': 'JOIN',
        'token': token,
        'username': username,
        'userId': userId,
      }));
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

  /// Join an existing game room
  Future<void> joinGame(String roomCode, String playerName) async {
    await connect();
    _currentGameCode = roomCode;

    _channel!.sink.add(jsonEncode({
      'type': 'JOIN_GAME',
      'roomCode': roomCode,
      'name': playerName,
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
  Future<void> updateStats({int wins = 1}) async {
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
        }),
      );

      if (response.statusCode != 200) {
        print('Stats update failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating stats: $e');
    }
  }

  void dispose() {
    leaveGame();
    _gameStreamController.close();
  }
}
