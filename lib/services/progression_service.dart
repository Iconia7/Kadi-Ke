import 'package:shared_preferences/shared_preferences.dart';

class ProgressionService {
  static const String _coinsKey = 'player_coins';
  static const String _unlockedSkinsKey = 'unlocked_skins';
  static const String _unlockedThemesKey = 'unlocked_themes';
  static const String _selectedSkinKey = 'selected_skin';
  static const String _selectedThemeKey = 'selected_theme';
  static const String _totalWinsKey = 'total_wins';
  static const String _totalGamesKey = 'total_games';
  
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
      await _prefs.setInt(_getKey(_coinsKey), 250); 
      await _prefs.setStringList(_getKey(_unlockedSkinsKey), ['classic', 'neon_geometric']); 
      await _prefs.setStringList(_getKey(_unlockedThemesKey), ['midnight_elite', 'green_table']); 
      await _prefs.setString(_getKey(_selectedSkinKey), 'neon_geometric');
      await _prefs.setString(_getKey(_selectedThemeKey), 'midnight_elite');
      await _prefs.setInt(_getKey(_totalWinsKey), 0);
      await _prefs.setInt(_getKey(_totalGamesKey), 0);
    }
  }

  // Helper to generate user-specific keys
  String _getKey(String key) => "$_userIdPrefix$key";

  // --- COINS & STATS ---
  int getCoins() => _prefs.getInt(_getKey(_coinsKey)) ?? 100;
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
  List<String> getUnlockedThemes() => _prefs.getStringList(_getKey(_unlockedThemesKey)) ?? ['green_table'];

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
  String getSelectedTheme() => _prefs.getString(_getKey(_selectedThemeKey)) ?? 'green_table';

  Future<void> selectSkin(String skinId) async => await _prefs.setString(_getKey(_selectedSkinKey), skinId);
  Future<void> selectTheme(String themeId) async => await _prefs.setString(_getKey(_selectedThemeKey), themeId);

  int calculateWinReward(int opponentCount, String difficulty) {
    int base = 50 + (opponentCount - 1) * 15;
    if (difficulty == 'hard') base = (base * 1.5).round();
    return base;
  }
  int getLossReward() => 15;
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