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
    Achievement(id: 'social_butterfly', title: 'Social Butterfly', description: 'Play an Emote in an online game.', icon: '🦋'),
  ];

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
  }

  List<Achievement> get allAchievements => _allAchievements;
  List<String> get unlockedIds => _unlockedIds;

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
}
