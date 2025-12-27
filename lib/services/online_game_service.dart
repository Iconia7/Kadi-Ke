import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class OnlineGameService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _streamController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get gameStream => _streamController.stream;

  // REPLACE WITH YOUR RENDER/HEROKU URL AFTER DEPLOYMENT
  // Local testing: 'ws://10.0.2.2:8080' (Android Emulator) or 'ws://localhost:8080'
  final String _serverUrl = "wss://your-app-name.onrender.com"; 

  static final OnlineGameService _instance = OnlineGameService._internal();
  factory OnlineGameService() => _instance;
  OnlineGameService._internal();

  void createGame(String playerName, String gameType) {
    _connect();
    _send("CREATE_GAME", {"gameType": gameType});
    // Wait for ROOM_CREATED response, then Join automatically
    // Ideally you handle this via the stream in the UI
  }

  void joinGame(String roomCode, String playerName) {
    _connect();
    _send("JOIN_GAME", {"roomCode": roomCode, "name": playerName});
  }

  void sendAction(String type, Map<String, dynamic> data) {
    _send(type, data);
  }

  void _connect() {
    if (_channel != null) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          _streamController.add(data);
        },
        onDone: () => print("Disconnected from server"),
        onError: (error) => print("WebSocket Error: $error"),
      );
    } catch (e) {
      print("Connection Error: $e");
    }
  }

  void _send(String type, Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({"type": type, ...data}));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}