import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class OnlineGameService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _streamController = StreamController.broadcast();
  final StreamController<ConnectionStatus> _statusController = StreamController.broadcast();

  Stream<Map<String, dynamic>> get gameStream => _streamController.stream;
  Stream<ConnectionStatus> get connectionStatus => _statusController.stream;
  
  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  ConnectionStatus get currentStatus => _currentStatus;

  // Default Render URL
  String _serverUrl = "wss://kadi-ke.onrender.com"; 

  static final OnlineGameService _instance = OnlineGameService._internal();
  factory OnlineGameService() => _instance;
  OnlineGameService._internal();

  void setServerUrl(String url) {
    if (url.isEmpty) return;
    _serverUrl = url.startsWith('ws') ? url : 'ws://$url';
    print("Server URL set to: $_serverUrl");
  }

  Future<void> createGame(String playerName, String gameType, {int entryFee = 0, Map<String, dynamic>? rules}) async {
    await _connect();
    // Small delay to ensure connection is ready if it was just established
    if (_currentStatus == ConnectionStatus.connected) {
       _send("CREATE_GAME", {
          "gameType": gameType, 
          "entryFee": entryFee,
          "rules": rules ?? {}
       });
    }
  }

  void joinGame(String roomCode, String playerName) async {
    await _connect();
    if (_currentStatus == ConnectionStatus.connected) {
      _send("JOIN_GAME", {"roomCode": roomCode, "name": playerName});
    }
  }

  void sendAction(String type, Map<String, dynamic> data) {
    _send(type, data);
  }

  Future<void> _connect() async {
    if (_channel != null && _channel!.closeCode == null) return;

    _updateStatus(ConnectionStatus.connecting);

    try {
      print("Connecting to: $_serverUrl");
      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      
      // Wait for the connection to actually be open (or fail) based on first event or similar?
      // WebSocketChannel doesn't expose "onOpen" directly easily without package specific impls.
      // We assume it's connected if no error immediately throws. 
      // A ping/pong or initial handshake is better, but for now we set connected.
      _updateStatus(ConnectionStatus.connected);

      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          _streamController.add(data);
        },
        onDone: () {
          print("Disconnected from server");
          _channel = null; 
          _updateStatus(ConnectionStatus.disconnected);
        },
        onError: (error) {
          print("WebSocket Error: $error");
          _channel = null; 
          _updateStatus(ConnectionStatus.disconnected);
        },
      );
      
      // Give it a moment to stabilize
      await Future.delayed(Duration(milliseconds: 500));

    } catch (e) {
      print("Connection Error: $e");
      _channel = null;
      _updateStatus(ConnectionStatus.disconnected);
    }
  }

  void _updateStatus(ConnectionStatus status) {
     _currentStatus = status;
     _statusController.add(status);
  }

  void _send(String type, Map<String, dynamic> data) {
    if (_channel != null && _currentStatus == ConnectionStatus.connected) {
      try {
        _channel!.sink.add(jsonEncode({"type": type, ...data}));
      } catch (e) {
        print("Send Error: $e");
      }
    } else {
      print("Cannot send $type: Not connected.");
    }
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    _updateStatus(ConnectionStatus.disconnected);
  }
}