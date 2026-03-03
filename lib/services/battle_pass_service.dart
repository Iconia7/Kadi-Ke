import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'progression_service.dart';
import 'custom_auth_service.dart';

class BattlePassTier {
  final int level;
  final String freeReward;
  final String premiumReward;
  final int xpRequired;
  final RewardType freeType;
  final RewardType premiumType;
  final int freeValue;
  final int premiumValue;

  BattlePassTier({
    required this.level,
    required this.freeReward,
    required this.premiumReward,
    this.xpRequired = 1000,
    required this.freeType,
    required this.premiumType,
    required this.freeValue,
    required this.premiumValue,
  });
}

enum RewardType { coins, xp, skin, theme, emote, title, frame }

class BattlePassService {
  static final BattlePassService _instance = BattlePassService._internal();
  factory BattlePassService() => _instance;
  BattlePassService._internal();

  int _seasonId = 1;
  DateTime _seasonStart = DateTime.now();
  bool _isPremium = false;
  bool _isUltra = false;
  int _currentXP = 0;
  List<int> _claimedFreeTiers = [];
  List<int> _claimedPremiumTiers = [];

  // This replaces the hardcoded tiers list — loaded from server or cache
  List<BattlePassTier> _tiers = [];

  // 50 Tiers for Season 1 — fallback if server is unreachable
  static final List<BattlePassTier> _fallbackTiers = [
    BattlePassTier(level: 1,  freeReward: "100 Coins", premiumReward: "Title: S1 Founder", freeType: RewardType.coins, premiumType: RewardType.title, freeValue: 100, premiumValue: 1),
    BattlePassTier(level: 2,  freeReward: "100 Coins", premiumReward: "500 Coins", freeType: RewardType.coins, premiumType: RewardType.coins, freeValue: 100, premiumValue: 500),
    BattlePassTier(level: 3,  freeReward: "100 Coins", premiumReward: "500 XP", freeType: RewardType.coins, premiumType: RewardType.xp, freeValue: 100, premiumValue: 500),
    BattlePassTier(level: 4,  freeReward: "100 Coins", premiumReward: "500 Coins", freeType: RewardType.coins, premiumType: RewardType.coins, freeValue: 100, premiumValue: 500),
    BattlePassTier(level: 5,  freeReward: "200 Coins", premiumReward: "Skin: Obsidian Shard", freeType: RewardType.coins, premiumType: RewardType.skin, freeValue: 200, premiumValue: 1),
    BattlePassTier(level: 6,  freeReward: "100 Coins", premiumReward: "Emote: GG WP", freeType: RewardType.coins, premiumType: RewardType.emote, freeValue: 100, premiumValue: 1),
    BattlePassTier(level: 7,  freeReward: "100 Coins", premiumReward: "500 Coins", freeType: RewardType.coins, premiumType: RewardType.coins, freeValue: 100, premiumValue: 500),
    BattlePassTier(level: 8,  freeReward: "100 Coins", premiumReward: "Title: Card Sharp", freeType: RewardType.coins, premiumType: RewardType.title, freeValue: 100, premiumValue: 1),
    BattlePassTier(level: 9,  freeReward: "100 Coins", premiumReward: "1000 Coins", freeType: RewardType.coins, premiumType: RewardType.coins, freeValue: 100, premiumValue: 1000),
    BattlePassTier(level: 10, freeReward: "500 Coins", premiumReward: "Frame: Neon Flare", freeType: RewardType.coins, premiumType: RewardType.frame, freeValue: 500, premiumValue: 1),
  ];

  List<BattlePassTier> get tiers => _tiers.isNotEmpty ? _tiers : _fallbackTiers;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // ---------------- Server Fetch ----------------
    await _fetchAndCacheTiersFromServer(prefs);

    // ---------------- Season Management ----------------
    // After fetching, the server is the authority on seasonId & end date.
    // We still keep local fallback timing in case of offline.
    final int startTimeMs = prefs.getInt('bp_season_start_ms') ?? 0;
    if (startTimeMs == 0) {
      _seasonStart = DateTime.now();
      await prefs.setInt('bp_season_start_ms', _seasonStart.millisecondsSinceEpoch);
      await prefs.setInt('bp_season_id', _seasonId);
    } else {
      _seasonStart = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
      final localSeason = prefs.getInt('bp_season_id') ?? 1;
      
      // If server returned a newer season, reset local progress
      if (_seasonId > localSeason) {
        _currentXP = 0;
        _claimedFreeTiers = [];
        _claimedPremiumTiers = [];
        _isPremium = false;
        _isUltra = false;
        _seasonStart = DateTime.now();

        await prefs.setInt('bp_season_id', _seasonId);
        await prefs.setInt('bp_season_start_ms', _seasonStart.millisecondsSinceEpoch);
        await prefs.setInt('bp_total_xp', 0);
        await prefs.setStringList('bp_claimed_free', []);
        await prefs.setStringList('bp_claimed_premium', []);
        await prefs.setBool('is_pass_premium', false);
        await prefs.setBool('is_pass_ultra', false);
      } else {
        _seasonId = localSeason;
      }
    }

    _isPremium = ProgressionService().isPremium();
    _isUltra = ProgressionService().isUltra();
    _currentXP = prefs.getInt('bp_total_xp') ?? 0;
    _claimedFreeTiers = (prefs.getStringList('bp_claimed_free') ?? []).map(int.parse).toList();
    _claimedPremiumTiers = (prefs.getStringList('bp_claimed_premium') ?? []).map(int.parse).toList();
  }

  Future<void> _fetchAndCacheTiersFromServer(SharedPreferences prefs) async {
    try {
      final baseUrl = CustomAuthService().baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/battlepass/season'),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final season = data['season'] as Map<String, dynamic>;
        final tiersRaw = data['tiers'] as List<dynamic>;

        _seasonId = season['id'] as int;
        final endDate = DateTime.tryParse(season['end_date'] as String? ?? '') ?? DateTime.now().add(const Duration(days: 30));
        _seasonStart = endDate.subtract(const Duration(days: 30));

        _tiers = tiersRaw.map<BattlePassTier>((t) {
          final m = t as Map<String, dynamic>;
          return BattlePassTier(
            level: m['level'] as int,
            freeReward: m['free_reward'] as String,
            premiumReward: m['premium_reward'] as String,
            xpRequired: (m['xp_required'] as int?) ?? 1000,
            freeType: _parseRewardType(m['free_type'] as String),
            premiumType: _parseRewardType(m['premium_type'] as String),
            freeValue: m['free_value'] as int,
            premiumValue: m['premium_value'] as int,
          );
        }).toList();

        // Cache for offline use
        await prefs.setString('bp_tiers_cache', response.body);
        await prefs.setInt('bp_cached_season_id', _seasonId);
      }
    } catch (_) {
      // Network failed — load from cache
      final cached = prefs.getString('bp_tiers_cache');
      if (cached != null) {
        try {
          final data = jsonDecode(cached) as Map<String, dynamic>;
          final season = data['season'] as Map<String, dynamic>;
          final tiersRaw = data['tiers'] as List<dynamic>;
          _seasonId = season['id'] as int;
          _tiers = tiersRaw.map<BattlePassTier>((t) {
            final m = t as Map<String, dynamic>;
            return BattlePassTier(
              level: m['level'] as int,
              freeReward: m['free_reward'] as String,
              premiumReward: m['premium_reward'] as String,
              xpRequired: (m['xp_required'] as int?) ?? 1000,
              freeType: _parseRewardType(m['free_type'] as String),
              premiumType: _parseRewardType(m['premium_type'] as String),
              freeValue: m['free_value'] as int,
              premiumValue: m['premium_value'] as int,
            );
          }).toList();
        } catch (_) {
          // Cache also broken — fallback tiers will be used via getter
        }
      }
    }
  }

  static RewardType _parseRewardType(String raw) {
    return RewardType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => RewardType.coins,
    );
  }

  int get seasonId => _seasonId;
  
  String get seasonCountdown {
    final now = DateTime.now();
    final end = _seasonStart.add(const Duration(days: 30));
    final diff = end.difference(now);
    
    if (diff.isNegative) return "Ending Soon...";
    
    if (diff.inDays > 0) {
      return "${diff.inDays}d ${diff.inHours % 24}h Left";
    } else if (diff.inHours > 0) {
      return "${diff.inHours}h ${diff.inMinutes % 60}m Left";
    } else {
      return "${diff.inMinutes}m Left";
    }
  }

  bool get isPremium => _isPremium;
  bool get isUltra => _isUltra;
  int get currentXP => _currentXP;

  int get currentLevel {
    int xp = _currentXP;
    for (int i = 0; i < tiers.length; i++) {
       if (xp < tiers[i].xpRequired) return tiers[i].level;
       xp -= tiers[i].xpRequired;
    }
    return tiers.length;
  }

  double get progressToNextLevel {
    int xp = _currentXP;
    for (int i = 0; i < tiers.length; i++) {
       if (xp < tiers[i].xpRequired) return xp / tiers[i].xpRequired;
       xp -= tiers[i].xpRequired;
    }
    return 1.0;
  }

  Future<void> addXP(int xp) async {
    _currentXP += xp;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bp_total_xp', _currentXP);
  }

  Future<void> setPremiumUnlocked(bool unlocked, {bool ultra = false}) async {
    _isPremium = unlocked;
    if (ultra) _isUltra = true;
    // Local backup handled by ProgressionService too
  }

  bool isTierClaimed(int level, bool premium) {
    return premium ? _claimedPremiumTiers.contains(level) : _claimedFreeTiers.contains(level);
  }

  Future<bool> claimTier(int level, bool premium) async {
    if (level > currentLevel) return false;
    if (premium && !_isPremium) return false;
    if (isTierClaimed(level, premium)) return false;

    final tier = tiers[level - 1];
    final type = premium ? tier.premiumType : tier.freeType;
    final value = premium ? tier.premiumValue : tier.freeValue;

    // Award reward
    if (type == RewardType.coins) {
       await ProgressionService().addCoins(value);
    } else if (type == RewardType.xp) {
       await ProgressionService().addXP(value);
    } else if (type == RewardType.skin) {
       final skinId = premium ? tier.premiumReward.split(': ').last.toLowerCase().replaceAll(' ', '_') : tier.freeReward.split(': ').last.toLowerCase().replaceAll(' ', '_');
       await ProgressionService().unlockSkin(skinId);
    } else if (type == RewardType.theme) {
       final themeId = premium ? tier.premiumReward.split(': ').last.toLowerCase().replaceAll(' ', '_') : tier.freeReward.split(': ').last.toLowerCase().replaceAll(' ', '_');
       await ProgressionService().unlockTheme(themeId);
    } else if (type == RewardType.emote) {
       final emoteId = premium ? tier.premiumReward.split(': ').last.toLowerCase().replaceAll(' ', '_') : tier.freeReward.split(': ').last.toLowerCase().replaceAll(' ', '_');
       await ProgressionService().unlockEmote(emoteId);
    } else if (type == RewardType.title) {
       final title = premium ? tier.premiumReward.split(': ').last : tier.freeReward.split(': ').last;
       await ProgressionService().unlockTitle(title);
    } else if (type == RewardType.frame) {
       final frameId = premium ? tier.premiumReward.split(': ').last.toLowerCase().replaceAll(' ', '_') : tier.freeReward.split(': ').last.toLowerCase().replaceAll(' ', '_');
       await ProgressionService().unlockFrame(frameId);
    }

    if (premium) {
      _claimedPremiumTiers.add(level);
    } else {
      _claimedFreeTiers.add(level);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bp_claimed_free', _claimedFreeTiers.map((e) => e.toString()).toList());
    await prefs.setStringList('bp_claimed_premium', _claimedPremiumTiers.map((e) => e.toString()).toList());
    
    return true;
  }
}
