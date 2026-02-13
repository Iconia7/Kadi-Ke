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
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  String? get currentGameCode => _currentGameCode;

  /// Connect to the VPS WebSocket server
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _gameStreamController.add(data);
          } catch (e) {
            print('Error parsing message: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          print('WebSocket connection closed');
        },
        onError: (error) {
          _isConnected = false;
          print('WebSocket error: $error');
        },
      );
    } catch (e) {
      _isConnected = false;
      print('Failed to connect to VPS: $e');
      rethrow;
    }
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

  /// Leave the current game
  void leaveGame() {
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

      final response = await http.post(
        Uri.parse('$httpUrl/update_stats'),
        headers: {'Content-Type': 'application/json'},
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
