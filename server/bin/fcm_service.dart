import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
  auth.AutoRefreshingAuthClient? _client;
  String? _projectId;
  bool _initialized = false;

  Future<void> initialize() async {
    final file = File('service-account.json');
    if (!await file.exists()) {
      print(
          'FCM Warning: service-account.json not found. Push notifications will be disabled.');
      return;
    }

    try {
      final jsonString = await file.readAsString();
      final credentials = auth.ServiceAccountCredentials.fromJson(jsonString);

      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      _projectId = jsonMap['project_id'];

      _client = await auth.clientViaServiceAccount(credentials, _scopes);
      _initialized = true;
      print('FCM Service initialized for project: $_projectId');
    } catch (e) {
      print('FCM Initialization error: $e');
    }
  }

  Future<bool> sendPushNotification(String fcmToken, String title, String body,
      {String? imageUrl,
      List<Map<String, dynamic>>? actions,
      Map<String, dynamic>? data}) async {
    if (!_initialized || _client == null || _projectId == null) {
      print('FCM Error: Service not initialized. Cannot send push.');
      return false;
    }

    final url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send');

    // Build Data Payload
    Map<String, dynamic> finalData = {};
    if (data != null) {
      finalData.addAll(data..removeWhere((key, value) => value == null));
    }
    if (actions != null && actions.isNotEmpty) {
      finalData['actions'] = jsonEncode(actions);
    }
    
    // Convert all values in data to strings (FCM requirement)
    finalData = finalData.map((key, value) => MapEntry(key, value.toString()));

    final message = {
      'message': {
        'token': fcmToken,
        'notification': {
          'title': title,
          'body': body,
          if (imageUrl != null) 'image': imageUrl,
        },
        if (finalData.isNotEmpty) 'data': finalData,
      }
    };

    try {
      final response = await _client!.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('FCM Send Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('FCM Request Exception: $e');
      return false;
    }
  }
}
