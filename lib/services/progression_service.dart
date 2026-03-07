import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'vps_game_service.dart';
import '../models/challenge_model.dart';
import 'app_config.dart';
import 'battle_pass_service.dart';
import 'custom_auth_service.dart';
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
  static const String _totalXpKey = 'total_xp';
  static const String _challengesKey = 'daily_challenges';
  static const String _lastChallengeResetKey = 'last_challenge_reset';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _mmrKey = 'player_mmr';
  static const String _rankTierKey = 'player_rank_tier';
  static const String _isPremiumKey = 'is_pass_premium';
  static const String _isUltraKey = 'is_pass_ultra';
  static const String _unlockedEmotesKey = 'unlocked_emotes';
  static const String _unlockedTitlesKey = 'unlocked_titles';
  static const String _unlockedFramesKey = 'unlocked_frames';
  static const String _selectedFrameKey = 'selected_avatar_frame';
  

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
      await _prefs.setInt(_getKey(_totalXpKey), 0);
      await _prefs.setInt(_getKey(_mmrKey), 1000);
      await _prefs.setString(_getKey(_rankTierKey), 'Bronze I');
      await _prefs.setBool(_getKey(_isPremiumKey), false);
      await _prefs.setBool(_getKey(_isUltraKey), false);
      await _prefs.setStringList(_getKey(_unlockedEmotesKey), ['neutral']);
      await _prefs.setStringList(_getKey(_unlockedTitlesKey), ['Rookie']);
      await _prefs.setStringList(_getKey(_unlockedFramesKey), ['default']);
      await _prefs.setString(_getKey(_selectedFrameKey), 'default');
    }
    
    // Proactively fetch and sync from cloud on startup to handle any offline discrepancies
    if (userId != null && userId.isNotEmpty && userId != "unknown") {
      // Delay slightly to ensure services are fully initialized
      Future.delayed(const Duration(seconds: 2), () {
        CustomAuthService().fetchCloudWallet();
      });
    }
  }

  // Helper to generate user-specific keys
  String _getKey(String key) => "$_userIdPrefix$key";

  // --- CLOUD WALLET SYNC ---
  Future<void> syncFromCloud(int coins, int wins, int gamesPlayed, {int xp = 0, int mmr = 1000, String rankTier = 'Bronze I', bool isPremium = false, bool isUltra = false, String? frameId}) async {
    // Only update stats from server if they are higher than local (protection against overwriting offline progress)
    final localWins = getTotalWins();
    if (wins > localWins) {
      await _prefs.setInt(_getKey(_totalWinsKey), wins);
    }

    final localGames = getTotalGames();
    if (gamesPlayed > localGames) {
      await _prefs.setInt(_getKey(_totalGamesKey), gamesPlayed);
    }

    final localCoins = getCoins();
    if (coins > localCoins) {
      await _prefs.setInt(_getKey(_coinsKey), coins);
    }

    final localMMR = getMMR();
    if (mmr > localMMR) {
      await _prefs.setInt(_getKey(_mmrKey), mmr);
      await _prefs.setString(_getKey(_rankTierKey), rankTier);
    }

    await _prefs.setBool(_getKey(_isPremiumKey), isPremium);
    await _prefs.setBool(_getKey(_isUltraKey), isUltra);

    if (frameId != null) {
      await _prefs.setString(_getKey(_selectedFrameKey), frameId);
    }
    
    // Notify Battle Pass Service
    if (isPremium) {
       BattlePassService().setPremiumUnlocked(true, ultra: isUltra);
    }
    
    // Only update XP from server if it's higher than local (server is source of truth)
    final localXP = getXP();
    if (xp > localXP) {
      await _prefs.setInt(_getKey(_totalXpKey), xp);
    }
    
    // Check if we need to push local offline wins to the server
    final currentLocalWins = getTotalWins();
    if (currentLocalWins > wins) {
      final diff = currentLocalWins - wins;
      print("ProgressionService: Found $diff unsynced offline wins. Pushing to server...");
      // Assuming VPSGameService exists and handles this correctly
      // We do this without await so it doesn't block the sync process
      VPSGameService().updateStats(wins: diff, isLan: false);
    }
  }

  // --- COINS & STATS ---
  int getCoins() => _prefs.getInt(_getKey(_coinsKey)) ?? 0;
  Future<void> addCoins(int amount) async {
    final newCoins = getCoins() + amount;
    await _prefs.setInt(_getKey(_coinsKey), newCoins);
    // Push to server in background
    _pushCoinsToServer(newCoins);
  }

  Future<void> _pushCoinsToServer(int coins) async {
    try {
      final token = _prefs.getString('auth_token');
      if (token == null || token.isEmpty) return;
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/update_coins'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'coins': coins}),
      );
    } catch (_) {
      // Silent error
    }
  }
  
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

  int getMMR() => _prefs.getInt(_getKey(_mmrKey)) ?? 1000;
  String getRankTier() => _prefs.getString(_getKey(_rankTierKey)) ?? 'Bronze I';

  Future<void> updateMMRLocal(int newMMR, String newTier) async {
    await _prefs.setInt(_getKey(_mmrKey), newMMR);
    await _prefs.setString(_getKey(_rankTierKey), newTier);
  }

  bool isPremium() => _prefs.getBool(_getKey(_isPremiumKey)) ?? false;
  bool isUltra() => _prefs.getBool(_getKey(_isUltraKey)) ?? false;

  // --- XP & LEVEL SYSTEM ---
  int getXP() => _prefs.getInt(_getKey(_totalXpKey)) ?? 0;
  Future<void> addXP(int amount) async {
    final newXP = getXP() + amount;
    await _prefs.setInt(_getKey(_totalXpKey), newXP);
    
    // SYNC WITH BATTLE PASS (NEW)
    BattlePassService().addXP(amount);

    // Push to server in background (fire-and-forget — offline play still works)
    _pushXPToServer(newXP);
  }

  Future<void> _pushXPToServer(int xp) async {
    try {
      final token = _prefs.getString('auth_token');
      if (token == null || token.isEmpty) return;
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/update_xp'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'xp': xp}),
      );
    } catch (_) {
      // Silent — offline or server down should not break local play
    }
  }

  static const List<Map<String, dynamic>> _levelTiers = [
    {'level': 1, 'title': 'Rookie',       'xp': 0,     'color': 0xFF9E9E9E},
    {'level': 2, 'title': 'Apprentice',   'xp': 200,   'color': 0xFF4CAF50},
    {'level': 3, 'title': 'Skilled',       'xp': 500,   'color': 0xFF2196F3},
    {'level': 4, 'title': 'Elite Player',  'xp': 1000,  'color': 0xFF9C27B0},
    {'level': 5, 'title': 'Card Master',   'xp': 2500,  'color': 0xFFFFD700},
    {'level': 6, 'title': 'Grand Master',  'xp': 5000,  'color': 0xFFF44336},
    {'level': 7, 'title': 'Legend',        'xp': 10000, 'color': 0xFF00E5FF},
  ];

  Map<String, dynamic> getLevel() {
    int xp = getXP();
    Map<String, dynamic> current = _levelTiers.first;
    Map<String, dynamic>? next;

    for (int i = 0; i < _levelTiers.length; i++) {
      if (xp >= _levelTiers[i]['xp']) {
        current = _levelTiers[i];
        next = (i + 1 < _levelTiers.length) ? _levelTiers[i + 1] : null;
      }
    }

    int xpForCurrent = current['xp'] as int;
    int xpForNext = next != null ? next['xp'] as int : xpForCurrent;
    int xpInLevel = xp - xpForCurrent;
    int xpNeeded = xpForNext - xpForCurrent;
    double progress = xpNeeded > 0 ? (xpInLevel / xpNeeded).clamp(0.0, 1.0) : 1.0;

    return {
      'level': current['level'],
      'title': current['title'],
      'color': current['color'],
      'xp': xp,
      'xpForNext': xpForNext > 0 ? xpForNext : xpForCurrent,
      'progress': progress,
      'isMaxLevel': next == null,
    };
  }

  // --- UNLOCKABLES ---
  List<String> getUnlockedSkins() => _prefs.getStringList(_getKey(_unlockedSkinsKey)) ?? ['classic'];
  List<String> getUnlockedThemes() => _prefs.getStringList(_getKey(_unlockedThemesKey)) ?? ['midnight_elite'];
  List<String> getUnlockedEmotes() => _prefs.getStringList(_getKey(_unlockedEmotesKey)) ?? ['neutral'];
  List<String> getUnlockedTitles() => _prefs.getStringList(_getKey(_unlockedTitlesKey)) ?? ['Rookie'];
  List<String> getUnlockedFrames() => _prefs.getStringList(_getKey(_unlockedFramesKey)) ?? ['default'];
  String getSelectedFrame() => _prefs.getString(_getKey(_selectedFrameKey)) ?? 'default';

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

  Future<void> unlockEmote(String emoteId) async {
    List<String> unlocked = getUnlockedEmotes();
    if (!unlocked.contains(emoteId)) {
      unlocked.add(emoteId);
      await _prefs.setStringList(_getKey(_unlockedEmotesKey), unlocked);
    }
  }

  Future<void> unlockTitle(String title) async {
    List<String> unlocked = getUnlockedTitles();
    if (!unlocked.contains(title)) {
      unlocked.add(title);
      await _prefs.setStringList(_getKey(_unlockedTitlesKey), unlocked);
    }
  }

  Future<void> unlockFrame(String frameId) async {
    List<String> unlocked = getUnlockedFrames();
    if (!unlocked.contains(frameId)) {
      unlocked.add(frameId);
      await _prefs.setStringList(_getKey(_unlockedFramesKey), unlocked);
    }
  }

  Future<void> selectFrame(String frameId) async {
    await _prefs.setString(_getKey(_selectedFrameKey), frameId);
    _pushProfileUpdateToServer(selectedFrame: frameId);
  }

  Future<void> _pushProfileUpdateToServer({String? newUsername, String? selectedFrame}) async {
    try {
      final token = _prefs.getString('auth_token');
      final username = _prefs.getString('username');
      if (token == null || token.isEmpty || username == null) return;
      
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/update_profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'oldUsername': username,
          'newUsername': newUsername ?? username,
          'selectedFrame': selectedFrame,
        }),
      );
    } catch (_) {
      // Silent error
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
  final String description;
  final int price;
  final ShopItemType type;
  final ShopRarity rarity;
  final int levelRequired; // 0 = no requirement
  final bool isNew;

  ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.type,
    this.rarity = ShopRarity.common,
    this.levelRequired = 0,
    this.isNew = false,
  });
}

enum ShopItemType { cardSkin, tableTheme }
enum ShopRarity { free, common, rare, epic, legendary }

class ShopCatalog {
  static final List<ShopItem> cardSkins = [
    ShopItem(
      id: 'classic',
      name: 'Classic Blue',
      description: 'The OG. Clean, timeless, and always in style.',
      price: 0,
      type: ShopItemType.cardSkin,
      rarity: ShopRarity.free,
    ),
    ShopItem(
      id: 'neon_geometric',
      name: 'Neon Geometric',
      description: 'Bold neon angles that pop on any table.',
      price: 0,
      type: ShopItemType.cardSkin,
      rarity: ShopRarity.free,
    ),
    ShopItem(
      id: 'matrix',
      name: 'Matrix Digital',
      description: 'Green-on-black digital rain. Hack the game.',
      price: 800,
      type: ShopItemType.cardSkin,
      rarity: ShopRarity.common,
    ),
    ShopItem(
      id: 'cyberpunk',
      name: 'Cyberpunk Purple',
      description: 'Neon purple vibes from a dystopian future.',
      price: 1200,
      type: ShopItemType.cardSkin,
      rarity: ShopRarity.rare,
    ),
    ShopItem(
      id: 'royal_gold',
      name: 'Royal Gold',
      description: 'For those who play like royalty.',
      price: 1500,
      type: ShopItemType.cardSkin,
      rarity: ShopRarity.rare,
    ),
    ShopItem(
      id: 'midnight',
      name: 'Dark Matter',
      description: 'Shadow-forged cards from the void.',
      price: 2000,
      type: ShopItemType.cardSkin,
      rarity: ShopRarity.epic,
    ),
    ShopItem(
      id: 'rainbow',
      name: 'Prism',
      description: 'All the colors of victory in one deck.',
      price: 2500,
      type: ShopItemType.cardSkin,
      rarity: ShopRarity.epic,
    ),
    ShopItem(
      id: 'volcanic',
      name: 'Volcanic Red',
      description: 'Every card burns with the heat of a thousand games.',
      price: 3000,
      type: ShopItemType.cardSkin,
      rarity: ShopRarity.epic,
      isNew: true,
      levelRequired: 3,
    ),
    ShopItem(
      id: 'arctic',
      name: 'Arctic Ice',
      description: 'Icy cool precision. Stay frosty under pressure.',
      price: 3000,
      type: ShopItemType.cardSkin,
      rarity: ShopRarity.epic,
      isNew: true,
      levelRequired: 3,
    ),
    ShopItem(
      id: 'golden_kadi',
      name: 'Golden Kadi',
      description: 'Reserved for legends. The pinnacle of card mastery.',
      price: 5000,
      type: ShopItemType.cardSkin,
      rarity: ShopRarity.legendary,
      isNew: true,
      levelRequired: 5,
    ),
  ];

  static final List<ShopItem> tableThemes = [
    ShopItem(
      id: 'midnight_elite',
      name: 'Midnight Elite',
      description: 'The default. Dark, sleek and premium.',
      price: 0,
      type: ShopItemType.tableTheme,
      rarity: ShopRarity.free,
    ),
    ShopItem(
      id: 'green_table',
      name: 'Vegas Green',
      description: 'Straight from the casino floor.',
      price: 600,
      type: ShopItemType.tableTheme,
      rarity: ShopRarity.common,
    ),
    ShopItem(
      id: 'ocean_blue',
      name: 'Oceanic',
      description: 'Deep-sea calm. Play like you\'re above it all.',
      price: 1000,
      type: ShopItemType.tableTheme,
      rarity: ShopRarity.rare,
    ),
    ShopItem(
      id: 'sunset',
      name: 'Sunset Blvd',
      description: 'Purple skies and golden hour vibes.',
      price: 1500,
      type: ShopItemType.tableTheme,
      rarity: ShopRarity.rare,
    ),
    ShopItem(
      id: 'blood_moon',
      name: 'Blood Moon',
      description: 'When the moon turns red, legends are born.',
      price: 3500,
      type: ShopItemType.tableTheme,
      rarity: ShopRarity.epic,
      isNew: true,
      levelRequired: 4,
    ),
    ShopItem(
      id: 'galaxy',
      name: 'Galaxy',
      description: 'Play among the stars. The universe is your table.',
      price: 5000,
      type: ShopItemType.tableTheme,
      rarity: ShopRarity.legendary,
      isNew: true,
      levelRequired: 5,
    ),
  ];

  /// All items combined for featured / search views
  static List<ShopItem> get all => [...cardSkins, ...tableThemes];

  /// Flagship item to feature prominently at the top
  static ShopItem get featured => cardSkins.firstWhere((i) => i.id == 'golden_kadi');
}
