import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'app_config.dart';

class CustomAuthService {
  static final CustomAuthService _instance = CustomAuthService._internal();
  factory CustomAuthService() => _instance;
  CustomAuthService._internal();

  String get baseUrl => AppConfig.baseUrl;
  
  String? _token;
  String? _userId;
  String? _username;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  String? get token => _token;
  String? get userId => _userId;
  String? get username => _username;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _userId = prefs.getString('user_id');
    _username = prefs.getString('username');
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
        _token = data['token'];
        _username = data['username'] ?? googleUser.displayName;

        await _saveCredentials();
      } else {
        throw Exception('Google login failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Google Sign-In error: $e');
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

  Future<void> updateProfile(String newUsername) async {
    if (_username == null) throw Exception('Not logged in');
    
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
  }
}
