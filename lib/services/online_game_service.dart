import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class OnlineGameService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _streamController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get gameStream => _streamController.stream;

  // --- FIX 1: CORRECT URL FORMAT (Removed 'https://') ---
  final String _serverUrl = "wss://kadi-ke.onrender.com"; 

  static final OnlineGameService _instance = OnlineGameService._internal();
  factory OnlineGameService() => _instance;
  OnlineGameService._internal();

// Update this method to be async
  Future<void> createGame(String playerName, String gameType) async {
    _connect();
    
    // ✅ CRITICAL FIX: Wait 1 second for the socket to fully open
    // This allows the WebSocket handshake to complete before we send data.
    await Future.delayed(Duration(seconds: 1));
    
    _send("CREATE_GAME", {"gameType": gameType});
  }

  void joinGame(String roomCode, String playerName) {
    _connect();
    _send("JOIN_GAME", {"roomCode": roomCode, "name": playerName});
  }

  void sendAction(String type, Map<String, dynamic> data) {
    _send(type, data);
  }

  void _connect() {
    // If already connected, don't reconnect
    if (_channel != null && _channel!.closeCode == null) return;

    try {
      print("Connecting to: $_serverUrl");
      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      
      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          _streamController.add(data);
        },
        onDone: () {
          print("Disconnected from server");
          _channel = null; // --- FIX 2: Reset so we can reconnect later
        },
        onError: (error) {
          print("WebSocket Error: $error");
          _channel = null; // --- FIX 2: Reset on error
        },
      );
    } catch (e) {
      print("Connection Error: $e");
      _channel = null;
    }
  }

  void _send(String type, Map<String, dynamic> data) {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode({"type": type, ...data}));
      } catch (e) {
        print("Send Error: $e");
      }
    } else {
      print("Cannot send $type: Not connected.");
      // Optional: Auto-reconnect here if you want to be aggressive
      _connect(); 
    }
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
  }
}