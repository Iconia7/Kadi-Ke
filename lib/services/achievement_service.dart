import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon; // Emoji or asset path
  final bool isSecret;

  Achievement({required this.id, required this.title, required this.description, required this.icon, this.isSecret = false});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'description': description, 'icon': icon, 'isSecret': isSecret};
}

class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  final List<Achievement> _allAchievements = [
    Achievement(id: 'first_win', title: 'First Blood', description: 'Win your first game.', icon: '🩸'),
    Achievement(id: 'bomb_squad', title: 'Bomb Squad', description: 'Drop a bomb (2, 3, or Joker) on a stack.', icon: '💣'),
    Achievement(id: 'sniper', title: 'Sniper', description: 'Win a game using an Ace as your last card.', icon: '🎯', isSecret: true),
    Achievement(id: 'rich_kid', title: 'Rich Kid', description: 'Accumulate 1000 Coins.', icon: '💰'),
    Achievement(id: 'chat_master', title: 'Chat Master', description: 'Send 10 chat messages in online games.', icon: '💬'),
    // Friend-based achievements
    Achievement(id: 'social_butterfly', title: 'Social Butterfly', description: 'Play 5 games with friends.', icon: '🦋'),
    Achievement(id: 'squad_goals', title: 'Squad Goals', description: 'Win 3 games with the same friend.', icon: '👥'),
  ];

  // Friend game tracking (for achievements)
  Map<String, int> _friendGameCounts = {}; // friendUserId -> game count
  Map<String, int> _friendWinCounts = {}; // friendUserId -> win count

  List<String> _unlockedIds = [];
  String _userIdPrefix = 'guest_';

  Future<void> initialize({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (userId != null && userId.isNotEmpty && userId != "unknown") {
      _userIdPrefix = "${userId}_";
    } else {
      _userIdPrefix = "guest_";
    }

    _unlockedIds = prefs.getStringList('${_userIdPrefix}unlocked_achievements') ?? [];
    
    // Load friend game tracking
    await _loadFriendTracking();
  }

  List<Achievement> get allAchievements => _allAchievements;
  List<String> get unlockedIds => _unlockedIds;

  int getUnlockedCount() => _unlockedIds.length;

  Future<bool> unlock(String id) async {
    if (_unlockedIds.contains(id)) return false; // Already unlocked

    // Check if valid ID
    if (!_allAchievements.any((a) => a.id == id)) return false;

    _unlockedIds.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('${_userIdPrefix}unlocked_achievements', _unlockedIds);
    return true; // Newly unlocked
  }
  
  bool isUnlocked(String id) => _unlockedIds.contains(id);

  // Friend Game Tracking for Achievements
  Future<void> recordFriendGame(String friendUserId, {bool won = false}) async {
    // Increment game count
    _friendGameCounts[friendUserId] = (_friendGameCounts[friendUserId] ?? 0) + 1;
    
    if (won) {
      _friendWinCounts[friendUserId] = (_friendWinCounts[friendUserId] ?? 0) + 1;
    }

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_userIdPrefix}friend_game_counts', jsonEncode(_friendGameCounts));
    await prefs.setString('${_userIdPrefix}friend_win_counts', jsonEncode(_friendWinCounts));

    // Check for achievements
    await _checkFriendAchievements();
  }

  Future<void> _checkFriendAchievements() async {
    // Social Butterfly: Play 5 games with friends (any friends)
    int totalFriendGames = _friendGameCounts.values.fold(0, (sum, count) => sum + count);
    if (totalFriendGames >= 5) {
      await unlock('social_butterfly');
    }

    // Squad Goals: Win 3 games with the same friend
    for (var wins in _friendWinCounts.values) {
      if (wins >= 3) {
        await unlock('squad_goals');
        break;
      }
    }
  }

  Future<void> _loadFriendTracking() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load friend game counts
    final gameCountsStr = prefs.getString('${_userIdPrefix}friend_game_counts');
    if (gameCountsStr != null) {
      final decoded = jsonDecode(gameCountsStr) as Map<String, dynamic>;
      _friendGameCounts = decoded.map((key, value) => MapEntry(key, value as int));
    }

    // Load friend win counts
    final winCountsStr = prefs.getString('${_userIdPrefix}friend_win_counts');
    if (winCountsStr != null) {
      final decoded = jsonDecode(winCountsStr) as Map<String, dynamic>;
      _friendWinCounts = decoded.map((key, value) => MapEntry(key, value as int));
    }
  }
}
