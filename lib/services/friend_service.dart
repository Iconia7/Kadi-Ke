import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/friend_model.dart';
import 'app_config.dart';
import 'custom_auth_service.dart';

class FriendService {
  static final FriendService _instance = FriendService._internal();
  factory FriendService() => _instance;
  FriendService._internal();

  List<Friend> _cachedFriends = [];
  DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Get all friends (from cache or server)
  Future<List<Friend>> getFriendsList({bool forceRefresh = false}) async {
    // Return cache if valid and not forcing refresh
    if (!forceRefresh && 
        _lastCacheUpdate != null && 
        DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiry) {
      return _cachedFriends;
    }

    try {
      final token = CustomAuthService().token;
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/friends/list'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final friendsList = ((data['friends'] ?? []) as List)
            .map((item) => Friend.fromJson(item))
            .toList();
        
        _cachedFriends = friendsList;
        _lastCacheUpdate = DateTime.now();
        return friendsList;
      } else {
        throw Exception('Failed to load friends: ${response.body}');
      }
    } catch (e) {
      print('Error fetching friends: $e');
      return _cachedFriends; // Return cached data on error
    }
  }

  /// Get only online friends
  Future<List<Friend>> getOnlineFriends() async {
    final friends = await getFriendsList();
    return friends.where((f) => f.isOnline && f.status == 'accepted').toList();
  }

  /// Get pending friend requests (incoming)
  Future<List<Friend>> getPendingRequests() async {
    final friends = await getFriendsList();
    return friends.where((f) => f.status == 'pending').toList();
  }

  /// Send friend request
  Future<bool> sendFriendRequest(String targetUsername) async {
    try {
      final token = CustomAuthService().token;
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/friends/request'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'targetUsername': targetUsername}),
      );

      if (response.statusCode == 200) {
        _invalidateCache();
        return true;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to send friend request');
      }
    } catch (e) {
      print('Error sending friend request: $e');
      rethrow;
    }
  }

  /// Accept friend request
  Future<bool> acceptFriendRequest(String userId) async {
    try {
      final token = CustomAuthService().token;
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/friends/accept'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        _invalidateCache();
        return true;
      } else {
        throw Exception('Failed to accept friend request');
      }
    } catch (e) {
      print('Error accepting friend request: $e');
      return false;
    }
  }

  /// Decline/Remove friend
  Future<bool> removeFriend(String userId) async {
    try {
      final token = CustomAuthService().token;
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/friends/remove'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        _invalidateCache();
        return true;
      } else {
        throw Exception('Failed to remove friend');
      }
    } catch (e) {
      print('Error removing friend: $e');
      return false;
    }
  }

  /// Search for users by username
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final token = CustomAuthService().token;
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/friends/search?username=${Uri.encodeComponent(query)}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['users'] ?? []);
      } else {
        throw Exception('Failed to search users');
      }
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  /// Invalidate cache to force refresh
  void _invalidateCache() {
    _lastCacheUpdate = null;
  }

  /// Clear all cached data
  void clearCache() {
    _cachedFriends.clear();
    _lastCacheUpdate = null;
  }
}
