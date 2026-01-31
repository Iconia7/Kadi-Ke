import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Model for a daily challenge
class Challenge {
  final String id;
  final String title;
  final String description;
  final String type; // 'wins', 'cards_played', 'bombs_played', 'quick_win'
  final int goal;
  final int coinReward;
  final int xpReward;
  int progress;
  bool claimed;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.goal,
    required this.coinReward,
    required this.xpReward,
    this.progress = 0,
    this.claimed = false,
  });

  bool get isCompleted => progress >= goal;
  double get progressPercent => (progress / goal).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type,
    'goal': goal,
    'coinReward': coinReward,
    'xpReward': xpReward,
    'progress': progress,
    'claimed': claimed,
  };

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    type: json['type'],
    goal: json['goal'],
    coinReward: json['coinReward'],
    xpReward: json['xpReward'],
    progress: json['progress'] ?? 0,
    claimed: json['claimed'] ?? false,
  );
}

/// Service for managing daily challenges
class ChallengeService {
  static final ChallengeService _instance = ChallengeService._internal();
  factory ChallengeService() => _instance;
  ChallengeService._internal();

  List<Challenge> _activeChallenges = [];
  DateTime? _lastRefresh;
  
  // Challenge templates
  static final List<Map<String, dynamic>> _challengeTemplates = [
    {
      'title': 'Winning Streak',
      'description': 'Win 3 games',
      'type': 'wins',
      'goal': 3,
      'coinReward': 100,
      'xpReward': 50,
    },
    {
      'title': 'Bomb Squad',
      'description': 'Play 10 bomb cards (2, 3, Joker)',
      'type': 'bombs_played',
      'goal': 10,
      'coinReward': 75,
      'xpReward': 30,
    },
    {
      'title': 'Speed Demon',
      'description': 'Win a game in under 5 minutes',
      'type': 'quick_win',
      'goal': 1,
      'coinReward': 150,
      'xpReward': 75,
    },
    {
      'title': 'Card Master',
      'description': 'Play 50 cards in total',
      'type': 'cards_played',
      'goal': 50,
      'coinReward': 80,
      'xpReward': 40,
    },
    {
      'title': 'Triple Threat',
      'description': 'Win 5 games',
      'type': 'wins',
      'goal': 5,
      'coinReward': 200,
      'xpReward': 100,
    },
  ];

  Future<void> initialize() async {
    await _loadChallenges();
    await _checkDailyRefresh();
  }

  Future<void> _loadChallenges() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('daily_challenges');
    final refreshDate = prefs.getString('challenges_refresh_date');
    
    if (data != null) {
      final List<dynamic> json = jsonDecode(data);
      _activeChallenges = json.map((c) => Challenge.fromJson(c)).toList();
    }
    
    if (refreshDate != null) {
      _lastRefresh = DateTime.parse(refreshDate);
    }
  }

  Future<void> _saveChallenges() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_activeChallenges.map((c) => c.toJson()).toList());
    await prefs.setString('daily_challenges', data);
    
    if (_lastRefresh != null) {
      await prefs.setString('challenges_refresh_date', _lastRefresh!.toIso8601String());
    }
  }

  Future<void> _checkDailyRefresh() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (_lastRefresh == null || _lastRefresh!.isBefore(today)) {
      await _generateNewChallenges();
      _lastRefresh = today;
      await _saveChallenges();
    }
  }

  Future<void> _generateNewChallenges() async {
    _activeChallenges.clear();
    
    // Shuffle and pick 3 random challenges
    final templates = List.from(_challengeTemplates)..shuffle();
    final selected = templates.take(3);
    
    for (var i = 0; i < selected.length; i++) {
      final template = selected.elementAt(i);
      _activeChallenges.add(Challenge(
        id: 'daily_${DateTime.now().millisecondsSinceEpoch}_$i',
        title: template['title'],
        description: template['description'],
        type: template['type'],
        goal: template['goal'],
        coinReward: template['coinReward'],
        xpReward: template['xpReward'],
      ));
    }
  }

  List<Challenge> getActiveChallenges() => List.unmodifiable(_activeChallenges);

  /// Update challenge progress
  Future<void> updateProgress(String type, {int amount = 1}) async {
    bool updated = false;
    
    for (var challenge in _activeChallenges) {
      if (challenge.type == type && !challenge.claimed) {
        challenge.progress += amount;
        updated = true;
      }
    }
    
    if (updated) {
      await _saveChallenges();
    }
  }

  /// Claim reward for completed challenge
  Future<Map<String, int>?> claimReward(String challengeId) async {
    final challenge = _activeChallenges.firstWhere(
      (c) => c.id == challengeId,
      orElse: () => throw Exception('Challenge not found'),
    );
    
    if (!challenge.isCompleted || challenge.claimed) {
      return null;
    }
    
    challenge.claimed = true;
    await _saveChallenges();
    
    return {
      'coins': challenge.coinReward,
      'xp': challenge.xpReward,
    };
  }

  /// Get time until next refresh
  Duration getTimeUntilRefresh() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }
}
