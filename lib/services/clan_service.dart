import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/clan_model.dart';
import 'app_config.dart';
import 'custom_auth_service.dart';

class ClanService {
  static final ClanService _instance = ClanService._internal();
  factory ClanService() => _instance;
  ClanService._internal();

  String get baseUrl => AppConfig.baseUrl;

  Map<String, String> get _headers {
    final token = CustomAuthService().token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Create a new clan (costs 2000 coins)
  Future<Map<String, dynamic>> createClan(String name, String tag, String description, int entryFee) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/clans/create'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'tag': tag,
          'description': description,
          'entryFee': entryFee,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data; // returns {'success': true, 'clanId': '...', 'tag': '...'}
      } else {
        throw Exception(data['error'] ?? 'Failed to create clan');
      }
    } catch (e) {
      throw Exception('Create clan error: $e');
    }
  }

  /// Join an existing clan
  Future<void> joinClan(String clanId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/clans/join'),
        headers: _headers,
        body: jsonEncode({'clanId': clanId}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(data['error'] ?? 'Failed to join clan');
      }
    } catch (e) {
      if (e is FormatException) throw Exception('Network error');
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  /// Leave current clan
  Future<void> leaveClan() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/clans/leave'),
        headers: _headers,
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(data['error'] ?? 'Failed to leave clan');
      }
    } catch (e) {
      throw Exception('Leave clan error: $e');
    }
  }

  /// Fetch a list of top active clans
  Future<List<Clan>> searchClans() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/clans/search'),
        headers: _headers,
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final List<dynamic> clanList = data['clans'] ?? [];
        return clanList.map((json) => Clan.fromJson(json)).toList();
      } else {
        throw Exception(data['error'] ?? 'Failed to search clans');
      }
    } catch (e) {
      throw Exception('Search clan error: $e');
    }
  }

  /// Get specific clan details (including members)
  Future<Clan> getClanDetails(String clanId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/clans/details?id=$clanId'),
        headers: _headers,
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return Clan.fromJson(data);
      } else {
        throw Exception(data['error'] ?? 'Failed to get clan details');
      }
    } catch (e) {
      throw Exception('Get clan details error: $e');
    }
  }

  /// Get the current user's clan details
  Future<Clan?> getMyClan() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/clans/my_clan'),
        headers: _headers,
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return Clan.fromJson(data);
      } else if (response.statusCode == 404) {
        return null; // The user is not in a clan
      } else {
        throw Exception(data['error'] ?? 'Failed to get my clan');
      }
    } catch (e) {
      throw Exception('Get my clan error: $e');
    }
  }

  /// Owner kicks a member from the clan
  Future<void> kickMember(String targetUserId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/clans/kick'),
        headers: _headers,
        body: jsonEncode({'targetUserId': targetUserId}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(data['error'] ?? 'Failed to kick member');
      }
    } catch (e) {
      throw Exception('Kick member error: $e');
    }
  }

  /// Owner deletes the clan entirely
  Future<void> deleteClan() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/clans/delete'),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(data['error'] ?? 'Failed to delete clan');
      }
    } catch (e) {
      throw Exception('Delete clan error: $e');
    }
  }
}
