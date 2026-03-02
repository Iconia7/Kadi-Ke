import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'progression_service.dart';

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

  bool _isPremium = false;
  bool _isUltra = false;
  int _currentXP = 0;
  List<int> _claimedFreeTiers = [];
  List<int> _claimedPremiumTiers = [];

  // 50 Tiers for Season 1
  final List<BattlePassTier> tiers = [
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
    // Tiers 11-20
    BattlePassTier(level: 11, freeReward: "100 Coins", premiumReward: "500 XP", freeType: RewardType.coins, premiumType: RewardType.xp, freeValue: 100, premiumValue: 500),
    BattlePassTier(level: 12, freeReward: "100 Coins", premiumReward: "Title: Duelist", freeType: RewardType.coins, premiumType: RewardType.title, freeValue: 100, premiumValue: 1),
    BattlePassTier(level: 13, freeReward: "100 Coins", premiumReward: "500 Coins", freeType: RewardType.coins, premiumType: RewardType.coins, freeValue: 100, premiumValue: 500),
    BattlePassTier(level: 14, freeReward: "100 Coins", premiumReward: "Emote: Thinking", freeType: RewardType.coins, premiumType: RewardType.emote, freeValue: 100, premiumValue: 1),
    BattlePassTier(level: 15, freeReward: "300 Coins", premiumReward: "Skin: Nebula Swirl", freeType: RewardType.coins, premiumType: RewardType.skin, freeValue: 300, premiumValue: 1),
    BattlePassTier(level: 16, freeReward: "100 Coins", premiumReward: "500 Coins", freeType: RewardType.coins, premiumType: RewardType.coins, freeValue: 100, premiumValue: 500),
    BattlePassTier(level: 17, freeReward: "100 Coins", premiumReward: "Title: Strategist", freeType: RewardType.coins, premiumType: RewardType.title, freeValue: 100, premiumValue: 1),
    BattlePassTier(level: 18, freeReward: "100 Coins", premiumReward: "500 XP", freeType: RewardType.coins, premiumType: RewardType.xp, freeValue: 100, premiumValue: 500),
    BattlePassTier(level: 19, freeReward: "100 Coins", premiumReward: "1000 Coins", freeType: RewardType.coins, premiumType: RewardType.coins, freeValue: 100, premiumValue: 1000),
    BattlePassTier(level: 20, freeReward: "500 Coins", premiumReward: "Frame: Galaxy Pulse", freeType: RewardType.coins, premiumType: RewardType.frame, freeValue: 500, premiumValue: 1),
    // Tiers 21-30
    BattlePassTier(level: 21, freeReward: "100 Coins", premiumReward: "Emote: Salty", freeType: RewardType.coins, premiumType: RewardType.emote, freeValue: 100, premiumValue: 1),
    BattlePassTier(level: 22, freeReward: "100 Coins", premiumReward: "500 Coins", freeType: RewardType.coins, premiumType: RewardType.coins, freeValue: 100, premiumValue: 500),
    BattlePassTier(level: 23, freeReward: "100 Coins", premiumReward: "Title: Kadi King", freeType: RewardType.coins, premiumType: RewardType.title, freeValue: 100, premiumValue: 1),
    BattlePassTier(level: 24, freeReward: "100 Coins", premiumReward: "500 XP", freeType: RewardType.coins, premiumType: RewardType.xp, freeValue: 100, premiumValue: 500),
    BattlePassTier(level: 25, freeReward: "400 Coins", premiumReward: "Frame: Royal Gold", freeType: RewardType.coins, premiumType: RewardType.frame, freeValue: 400, premiumValue: 1),
    BattlePassTier(level: 26, freeReward: "100 Coins", premiumReward: "500 Coins", freeType: RewardType.coins, premiumType: RewardType.coins, freeValue: 100, premiumValue: 500),
    BattlePassTier(level: 27, freeReward: "100 Coins", premiumReward: "Emote: Mind Blown", freeType: RewardType.coins, premiumType: RewardType.emote, freeValue: 100, premiumValue: 1),
    BattlePassTier(level: 28, freeReward: "100 Coins", premiumReward: "500 XP", freeType: RewardType.coins, premiumType: RewardType.xp, freeValue: 100, premiumValue: 500),
    BattlePassTier(level: 29, freeReward: "100 Coins", premiumReward: "Title: Untouchable", freeType: RewardType.coins, premiumType: RewardType.title, freeValue: 100, premiumValue: 1),
    BattlePassTier(level: 30, freeReward: "1000 Coins", premiumReward: "Theme: Galaxy", freeType: RewardType.coins, premiumType: RewardType.theme, freeValue: 1000, premiumValue: 1),
    // Tiers 31-50 (Procedural fallback for brevity, but with better targets)
    ...List.generate(20, (i) {
      int level = i + 31;
      bool isSpecial = level % 5 == 0;
      bool isFinal = level == 50;
      
      return BattlePassTier(
        level: level,
        freeReward: isFinal ? "2500 Coins" : (isSpecial ? "1000 Coins" : "200 Coins"),
        premiumReward: isFinal ? "Skin: Hologram Chrome" : (isSpecial ? (level == 40 ? "Frame: Obsidian Void" : "Emote: Flex") : "1500 Coins"),
        freeType: RewardType.coins,
        premiumType: isFinal ? RewardType.skin : (isSpecial ? (level == 40 ? RewardType.frame : RewardType.emote) : RewardType.coins),
        freeValue: isFinal ? 2500 : (isSpecial ? 1000 : 200),
        premiumValue: isFinal ? 1 : (isSpecial ? 1 : 1500),
      );
    }),
  ];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = ProgressionService().isPremium();
    _isUltra = ProgressionService().isUltra();
    _currentXP = prefs.getInt('bp_total_xp') ?? 0;
    _claimedFreeTiers = (prefs.getStringList('bp_claimed_free') ?? []).map(int.parse).toList();
    _claimedPremiumTiers = (prefs.getStringList('bp_claimed_premium') ?? []).map(int.parse).toList();
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
