import 'package:shared_preferences/shared_preferences.dart';
import '../models/challenge_model.dart';
import 'dart:convert';
import 'dart:math';

class ProgressionService {
  static const String _coinsKey = 'player_coins';
  static const String _unlockedSkinsKey = 'unlocked_skins';
  static const String _unlockedThemesKey = 'unlocked_themes';
  static const String _selectedSkinKey = 'selected_skin';
  static const String _selectedThemeKey = 'selected_theme';
  static const String _totalWinsKey = 'total_wins';
  static const String _totalGamesKey = 'total_games';
  static const String _challengesKey = 'daily_challenges';
  static const String _lastChallengeResetKey = 'last_challenge_reset';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  

  static final ProgressionService _instance = ProgressionService._internal();
  factory ProgressionService() => _instance;
  ProgressionService._internal();

  late SharedPreferences _prefs;
  bool _initialized = false;
  String _userIdPrefix = 'guest_'; // Default prefix

  // Updated initialize to accept userId
  Future<void> initialize({String? userId}) async {
    _prefs = await SharedPreferences.getInstance();
    
    if (userId != null && userId.isNotEmpty && userId != "unknown") {
      _userIdPrefix = "${userId}_";
    } else {
      _userIdPrefix = "guest_";
    }
    
    _initialized = true;
    
    // Initialize default data for this specific user if missing
    if (!_prefs.containsKey(_getKey(_coinsKey))) {
      await _prefs.setInt(_getKey(_coinsKey), 0); // Production default is 0
      await _prefs.setStringList(_getKey(_unlockedSkinsKey), ['classic']); 
      await _prefs.setStringList(_getKey(_unlockedThemesKey), ['midnight_elite']); 
      await _prefs.setString(_getKey(_selectedSkinKey), 'classic');
      await _prefs.setString(_getKey(_selectedThemeKey), 'midnight_elite');
      await _prefs.setInt(_getKey(_totalWinsKey), 0);
      await _prefs.setInt(_getKey(_totalGamesKey), 0);
    }
  }

  // Helper to generate user-specific keys
  String _getKey(String key) => "$_userIdPrefix$key";

  // --- COINS & STATS ---
  int getCoins() => _prefs.getInt(_getKey(_coinsKey)) ?? 0;
  Future<void> addCoins(int amount) async => await _prefs.setInt(_getKey(_coinsKey), getCoins() + amount);
  
  Future<bool> spendCoins(int amount) async {
    int current = getCoins();
    if (current >= amount) {
      await _prefs.setInt(_getKey(_coinsKey), current - amount);
      return true;
    }
    return false;
  }

  int getTotalWins() => _prefs.getInt(_getKey(_totalWinsKey)) ?? 0;
  int getTotalGames() => _prefs.getInt(_getKey(_totalGamesKey)) ?? 0;
  
  double getWinRate() {
    int games = getTotalGames();
    if (games == 0) return 0.0;
    return (getTotalWins() / games) * 100;
  }

  Future<void> recordGameResult(bool won) async {
    await _prefs.setInt(_getKey(_totalGamesKey), getTotalGames() + 1);
    if (won) await _prefs.setInt(_getKey(_totalWinsKey), getTotalWins() + 1);
  }

  // --- UNLOCKABLES ---
  List<String> getUnlockedSkins() => _prefs.getStringList(_getKey(_unlockedSkinsKey)) ?? ['classic'];
  List<String> getUnlockedThemes() => _prefs.getStringList(_getKey(_unlockedThemesKey)) ?? ['midnight_elite'];

  Future<void> unlockSkin(String skinId) async {
    List<String> unlocked = getUnlockedSkins();
    if (!unlocked.contains(skinId)) {
      unlocked.add(skinId);
      await _prefs.setStringList(_getKey(_unlockedSkinsKey), unlocked);
    }
  }

  Future<void> unlockTheme(String themeId) async {
    List<String> unlocked = getUnlockedThemes();
    if (!unlocked.contains(themeId)) {
      unlocked.add(themeId);
      await _prefs.setStringList(_getKey(_unlockedThemesKey), unlocked);
    }
  }

  String getSelectedSkin() => _prefs.getString(_getKey(_selectedSkinKey)) ?? 'classic';
  String getSelectedTheme() => _prefs.getString(_getKey(_selectedThemeKey)) ?? 'midnight_elite';

  Future<void> selectSkin(String skinId) async => await _prefs.setString(_getKey(_selectedSkinKey), skinId);
  Future<void> selectTheme(String themeId) async => await _prefs.setString(_getKey(_selectedThemeKey), themeId);

  bool areNotificationsEnabled() => _prefs.getBool(_getKey(_notificationsEnabledKey)) ?? true;
  Future<void> setNotificationsEnabled(bool enabled) async => await _prefs.setBool(_getKey(_notificationsEnabledKey), enabled);

  int calculateWinReward(int opponentCount, String difficulty) {
    int base = 50 + (opponentCount - 1) * 15;
    if (difficulty == 'hard') base = (base * 1.5).round();
    return base;
  }
  int getLossReward() => 15;

  // --- DAILY STREAK LOGIC ---
  static const String _lastLoginKey = 'last_login_time';
  static const String _streakKey = 'current_streak';

  Future<Map<String, dynamic>> checkDailyLogin() async {
    final now = DateTime.now();
    final lastTimeStr = _prefs.getString(_getKey(_lastLoginKey));
    int streak = _prefs.getInt(_getKey(_streakKey)) ?? 0;

    if (lastTimeStr == null) {
      // First time
      streak = 1;
      await _logLogin(now, streak);
      return {'streak': streak, 'reward': 100, 'canClaim': true};
    }

    final lastTime = DateTime.parse(lastTimeStr);
    
    // Check if same day
    if (_isSameDay(now, lastTime)) {
       return {'streak': streak, 'reward': 0, 'canClaim': false};
    }

    // Check if consecutive (yesterday)
    if (_isYesterday(now, lastTime)) {
       streak++;
    } else {
       // Missed a day
       streak = 1;
    }

    // Cap streak reward logic or purely visual? 
    // Let's cap visual streak at nothing, but reward grows.
    int reward = 100 + ((streak - 1) * 20);
    if (reward > 500) reward = 500; // Cap daily max

    await _logLogin(now, streak);
    return {'streak': streak, 'reward': reward, 'canClaim': true};
  }

  Future<void> _logLogin(DateTime when, int streak) async {
    await _prefs.setString(_getKey(_lastLoginKey), when.toIso8601String());
    await _prefs.setInt(_getKey(_streakKey), streak);
  }

  // --- CHALLENGES ---
  List<ChallengeModel> getChallenges() {
    final String? jsonStr = _prefs.getString(_getKey(_challengesKey));
    if (jsonStr == null) return [];
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded.map((item) => ChallengeModel.fromJson(item)).toList();
  }

  Future<void> saveChallenges(List<ChallengeModel> challenges) async {
    final String jsonStr = jsonEncode(challenges.map((c) => c.toJson()).toList());
    await _prefs.setString(_getKey(_challengesKey), jsonStr);
  }

  Future<void> checkAndResetChallenges() async {
    final now = DateTime.now();
    final lastResetStr = _prefs.getString(_getKey(_lastChallengeResetKey));
    
    if (lastResetStr == null || !_isSameDay(now, DateTime.parse(lastResetStr))) {
      await _generateNewChallenges();
      await _prefs.setString(_getKey(_lastChallengeResetKey), now.toIso8601String());
    }
  }

  Future<void> _generateNewChallenges() async {
    final random = Random();
    
    final List<Map<String, dynamic>> templatePool = [
      {
        'title': 'Victor',
        'description': (int goal) => 'Win $goal Games',
        'type': ChallengeType.winGames,
        'goalRange': [2, 5],
        'baseReward': 100,
      },
      {
        'title': 'Competitor',
        'description': (int goal) => 'Play $goal Games',
        'type': ChallengeType.playGames,
        'goalRange': [5, 10],
        'baseReward': 80,
      },
      {
        'title': 'Strategist',
        'description': (int goal) => 'Play $goal Special Cards',
        'type': ChallengeType.playSpecialCards,
        'goalRange': [5, 15],
        'baseReward': 120,
      },
      {
        'title': 'Flashy',
        'description': (int goal) => 'Use emotes $goal times',
        'type': ChallengeType.useEmote,
        'goalRange': [5, 12],
        'baseReward': 60,
      },
      {
        'title': 'The Professional',
        'description': (int goal) => 'Say "Niko Kadi" $goal times',
        'type': ChallengeType.sayNikoKadi,
        'goalRange': [3, 6],
        'baseReward': 150,
      },
      {
        'title': 'Survivor',
        'description': (int goal) => 'Draw $goal cards in total',
        'type': ChallengeType.drawCards,
        'goalRange': [10, 25],
        'baseReward': 90,
      },
      {
        'title': 'Pyrotechnic',
        'description': (int goal) => 'Stack bombs $goal times',
        'type': ChallengeType.bombStack,
        'goalRange': [2, 4],
        'baseReward': 200,
      },
      {
        'title': 'Blitz',
        'description': (int goal) => 'Win a game in under 2 mins',
        'type': ChallengeType.fastWin,
        'goalRange': [1, 1],
        'baseReward': 250,
      },
    ];

    // Shuffle and pick 3 unique random challenges
    templatePool.shuffle(random);
    final List<ChallengeModel> newChallenges = [];
    
    for (int i = 0; i < 3; i++) {
      final template = templatePool[i];
      final List<int> range = template['goalRange'];
      final int goal = range[0] + random.nextInt(range[1] - range[0] + 1);
      final int reward = (template['baseReward'] as int) + (goal * 5); // Scaling reward

      newChallenges.add(
        ChallengeModel(
          id: '${template['title'].toString().toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}_$i',
          title: template['title'],
          description: (template['description'] as Function)(goal),
          type: template['type'],
          goal: goal,
          reward: reward,
        ),
      );
    }

    await saveChallenges(newChallenges);
  }

  Future<void> updateChallengeProgress(ChallengeType type, int amount) async {
    List<ChallengeModel> challenges = getChallenges();
    bool changed = false;
    for (var challenge in challenges) {
      if (challenge.type == type && !challenge.isClaimed) {
        challenge.progress = min(challenge.goal, challenge.progress + amount);
        changed = true;
      }
    }
    if (changed) {
      await saveChallenges(challenges);
    }
  }

  Future<bool> claimChallengeReward(String id) async {
    List<ChallengeModel> challenges = getChallenges();
    for (var challenge in challenges) {
      if (challenge.id == id && challenge.isCompleted && !challenge.isClaimed) {
        challenge.isClaimed = true;
        await addCoins(challenge.reward);
        await saveChallenges(challenges);
        return true;
      }
    }
    return false;
  }

  // --- CHALLENGE NOTIFICATION STATE ---
  static const String _challengesViewedDateKey = 'challenges_viewed_date';

  bool hasUnclaimedChallenges() {
    List<ChallengeModel> challenges = getChallenges();
    // 1. Check for completed but unclaimed rewards
    bool hasRewards = challenges.any((c) => c.isCompleted && !c.isClaimed);
    if (hasRewards) return true;

    // 2. Check if new challenges have been viewed today
    final now = DateTime.now();
    final lastViewedStr = _prefs.getString(_getKey(_challengesViewedDateKey));
    if (lastViewedStr == null) return true;

    final lastViewed = DateTime.parse(lastViewedStr);
    return !_isSameDay(now, lastViewed);
  }

  Future<void> markDailyChallengesAsViewed() async {
    final now = DateTime.now();
    await _prefs.setString(_getKey(_challengesViewedDateKey), now.toIso8601String());
  }

  Duration getTimeUntilRefresh() {
    final lastResetStr = _prefs.getString(_getKey(_lastChallengeResetKey));
    if (lastResetStr == null) return Duration.zero;
    
    final lastReset = DateTime.parse(lastResetStr);
    final nextReset = DateTime(lastReset.year, lastReset.month, lastReset.day + 1);
    final now = DateTime.now();
    
    if (now.isAfter(nextReset)) return Duration.zero;
    return nextReset.difference(now);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isYesterday(DateTime now, DateTime past) {
    final yesterday = now.subtract(Duration(days: 1));
    return _isSameDay(yesterday, past);
  }
}

class ShopItem {
  final String id;
  final String name;
  final int price;
  final ShopItemType type;
  ShopItem({required this.id, required this.name, required this.price, required this.type});
}

enum ShopItemType { cardSkin, tableTheme }

class ShopCatalog {
  static final List<ShopItem> cardSkins = [
    ShopItem(id: 'classic', name: 'Classic Blue', price: 0, type: ShopItemType.cardSkin),
    ShopItem(id: 'neon_geometric', name: 'Neon Geometric', price: 0, type: ShopItemType.cardSkin),
    ShopItem(id: 'cyberpunk', name: 'Cyberpunk Purple', price: 250, type: ShopItemType.cardSkin),
    ShopItem(id: 'royal_gold', name: 'Royal Gold', price: 300, type: ShopItemType.cardSkin),
    ShopItem(id: 'matrix', name: 'Matrix Digital', price: 200, type: ShopItemType.cardSkin),
    ShopItem(id: 'midnight', name: 'Dark Matter', price: 350, type: ShopItemType.cardSkin),
    ShopItem(id: 'rainbow', name: 'Prism', price: 400, type: ShopItemType.cardSkin),
  ];

  static final List<ShopItem> tableThemes = [
    ShopItem(id: 'midnight_elite', name: 'Midnight Elite', price: 0, type: ShopItemType.tableTheme),
    ShopItem(id: 'green_table', name: 'Vegas Green', price: 100, type: ShopItemType.tableTheme),
    ShopItem(id: 'ocean_blue', name: 'Oceanic', price: 150, type: ShopItemType.tableTheme),
    ShopItem(id: 'sunset', name: 'Sunset Blvd', price: 200, type: ShopItemType.tableTheme),
  ];
}