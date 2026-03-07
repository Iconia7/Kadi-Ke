import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app_config.dart';
import 'progression_service.dart';

class CustomAuthService {
  static final CustomAuthService _instance = CustomAuthService._internal();
  factory CustomAuthService() => _instance;
  CustomAuthService._internal();

  String get baseUrl => AppConfig.baseUrl;
  
  String? _token;
  String? _userId;
  String? _username;
  String? _avatar;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  String? get token => _token;
  String? get userId => _userId;
  String? get username => _username;
  String? get avatar => _avatar;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _userId = prefs.getString('user_id');
    _username = prefs.getString('username');
    _avatar = prefs.getString('avatar');
  }

  Future<void> register(String username, String password, {String? email}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'email': email,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['error'] != null) {
          throw Exception(data['error']);
        }

        _userId = data['userId'];
        _username = username;
        _token = data['token']; 
        _avatar = data['avatar'];

        await ProgressionService().syncFromCloud(
          data['coins'] ?? 0,
          data['wins'] ?? 0,
          data['gamesPlayed'] ?? 0,
          xp: data['xp'] ?? 0,
          isPremium: data['isPremium'] ?? false,
          isUltra: data['isUltra'] ?? false,
          frameId: data['frameId'],
        );

        await _saveCredentials();
      } else {
        throw Exception('Registration failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  Future<void> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['error'] != null) {
          throw Exception(data['error']);
        }

        _userId = data['userId'];
        _token = data['token'];
        _username = username;
        await ProgressionService().syncFromCloud(
          data['coins'] ?? 0,
          data['wins'] ?? 0,
          data['gamesPlayed'] ?? 0,
          xp: data['xp'] ?? 0,
          isPremium: data['isPremium'] ?? false,
          isUltra: data['isUltra'] ?? false,
        );

        await _saveCredentials();
      } else {
        throw Exception('Login failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  Future<String> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot_password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) throw Exception(data['error']);
        // Returns the message (and debug token if any)
        return data['message'] + (data['debug_token'] != null ? "\nDebug Code: ${data['debug_token']}" : "");
      } else {
        throw Exception('Request failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<void> resetPassword(String email, String token, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset_password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'token': token,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) throw Exception(data['error']);
      } else {
        throw Exception('Request failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User cancelled

      final response = await http.post(
        Uri.parse('$baseUrl/google_login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'googleId': googleUser.id,
          'email': googleUser.email,
          'displayName': googleUser.displayName,
          'photoUrl': googleUser.photoUrl,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['error'] != null) {
          throw Exception(data['error']);
        }

        _userId = data['userId'];
        _username = data['username'];
        _token = data['token'];
        await ProgressionService().syncFromCloud(
          data['coins'] ?? 0,
          data['wins'] ?? 0,
          data['gamesPlayed'] ?? 0,
          xp: data['xp'] ?? 0,
          isPremium: data['isPremium'] ?? false,
          isUltra: data['isUltra'] ?? false,
        );

        await _saveCredentials();
      } else {
        throw Exception('Google login failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Google Sign-In error: $e');
    }
  }

  Future<void> fetchCloudWallet() async {
    if (_token == null || _userId == null) return;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync_wallet'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          await ProgressionService().syncFromCloud(
            data['coins'] ?? 0,
            data['wins'] ?? 0,
            data['gamesPlayed'] ?? 0,
            xp: data['xp'] ?? 0,
            isPremium: data['isPremium'] ?? false,
            isUltra: data['isUltra'] ?? false,
            frameId: data['frameId'],
          );
        }
      }
    } catch (_) {
      // Silent pass for background sync
    }
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _username = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('username');
  }

  Future<String> uploadProfilePicture(File image) async {
    if (_token == null) throw Exception('Not logged in');

    try {
      var uri = Uri.parse('$baseUrl/upload_avatar');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $_token';
      
      request.files.add(await http.MultipartFile.fromPath(
        'avatar',
        image.path,
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        _avatar = data['url'];
        await _saveCredentials();
        return _avatar!;
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  Future<void> updateProfile(String newUsername) async {
    if (_token == null) throw Exception('Not logged in');
    
    // We remove the `_username == null` check because users stuck as "Guest Player" 
    // might have a null username locally, but we still want them to be able to set it.
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'oldUsername': _username,
          'newUsername': newUsername,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          throw Exception(data['error']);
        }
        
        _username = newUsername;
        await _saveCredentials();
      } else {
        throw Exception('Update failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Update error: $e');
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString('auth_token', _token!);
    if (_userId != null) await prefs.setString('user_id', _userId!);
    if (_username != null) await prefs.setString('username', _username!);
    if (_avatar != null) await prefs.setString('avatar', _avatar!);
  }
}
