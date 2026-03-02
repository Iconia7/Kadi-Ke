import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/progression_service.dart';
import '../services/theme_service.dart';
import '../services/sound_service.dart';
import '../services/custom_auth_service.dart';
import '../services/iap_service.dart';
import '../services/ad_service.dart';
import '../widgets/playing_card_widget.dart';

class ShopScreen extends StatefulWidget {
  @override
  _ShopScreenState createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  final ProgressionService _progressionService = ProgressionService();
  late TabController _tabController;

  int _coins = 0;
  int _playerLevel = 1;
  List<String> _unlockedSkins = [];
  List<String> _unlockedThemes = [];
  String _selectedSkin = '';
  String _selectedTheme = '';

  // Palette
  static const _bg      = Color(0xFF0F111A);
  static const _surface = Color(0xFF1A1F38);
  static const _card    = Color(0xFF1E2540);
  static const _amber   = Color(0xFFFFB300);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();

    // Wire IAP purchase result to show UI feedback
    IAPService().onPurchaseResult = (message, success) {
      if (mounted) {
        _showResult(success,
          title: success ? 'Purchase Complete!' : 'Purchase Failed',
          message: message,
          icon: success ? Icons.check_circle_rounded : Icons.error_rounded,
        );
        if (success) _loadData(); // Refresh coin balance
      }
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userId = CustomAuthService().userId ?? 'offline';
    await _progressionService.initialize(userId: userId);
    if (mounted) {
      setState(() {
        _coins         = _progressionService.getCoins();
        _playerLevel   = _progressionService.getLevel()['level'] as int;
        _unlockedSkins = _progressionService.getUnlockedSkins();
        _unlockedThemes= _progressionService.getUnlockedThemes();
        _selectedSkin  = _progressionService.getSelectedSkin();
        _selectedTheme = _progressionService.getSelectedTheme();
      });
    }
  }

  Future<void> _purchaseItem(ShopItem item) async {
    final isSkin = item.type == ShopItemType.cardSkin;

    // Level check
    if (item.levelRequired > _playerLevel) {
      _showResult(false,
        title: 'Level Required',
        message: 'Reach Level ${item.levelRequired} to unlock this item.',
        icon: Icons.lock_rounded,
      );
      return;
    }

    if (_coins < item.price) {
      SoundService.play('error');
      _showResult(false,
        title: 'Insufficient Coins',
        message: 'You need ${item.price - _coins} more coins.',
        icon: Icons.monetization_on_rounded,
      );
      return;
    }

    final success = await _progressionService.spendCoins(item.price);
    if (success) {
      if (isSkin) {
        await _progressionService.unlockSkin(item.id);
        await _progressionService.selectSkin(item.id);
      } else {
        await _progressionService.unlockTheme(item.id);
        await _progressionService.selectTheme(item.id);
      }
      SoundService.play('win');
      await _loadData();
      _showResult(true,
        title: '${item.name} Unlocked!',
        message: 'Auto-equipped. Enjoy the new look! ✨',
        icon: Icons.check_circle_rounded,
        rarity: item.rarity,
      );
    }
  }

  Future<void> _selectItem(String id, bool isSkin) async {
    if (isSkin) await _progressionService.selectSkin(id);
    else await _progressionService.selectTheme(id);
    SoundService.play('place');
    await _loadData();
  }

  void _showResult(bool success, {
    required String title,
    required String message,
    required IconData icon,
    ShopRarity? rarity,
  }) {
    final rarityColor = _rarityColor(rarity ?? ShopRarity.common);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: success ? rarityColor : Colors.redAccent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (success ? rarityColor : Colors.redAccent).withOpacity(0.25),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (success ? rarityColor : Colors.redAccent).withOpacity(0.15),
                  border: Border.all(
                    color: (success ? rarityColor : Colors.redAccent).withOpacity(0.4),
                  ),
                ),
                child: Icon(icon,
                    color: success ? rarityColor : Colors.redAccent, size: 40),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.4)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(
                    color: (success ? rarityColor : Colors.redAccent).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: success ? rarityColor : Colors.redAccent,
                        width: 1),
                  ),
                  child: Text('OK',
                      style: TextStyle(
                          color: success ? rarityColor : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCoinBundles() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              decoration: BoxDecoration(
                color: _bg.withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, spreadRadius: 10),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 50, height: 5,
                    margin: const EdgeInsets.only(bottom: 25),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _amber.withOpacity(0.1),
                          border: Border.all(color: _amber.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.stars_rounded, color: _amber, size: 28),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('COIN MARKET',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  letterSpacing: 1.2)),
                          Text('Boost your balance instantly',
                              style: TextStyle(color: Colors.white38, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 30),

                  // Free coins via rewarded ad
                  _coinBundle(
                    amount: 500,
                    price: 'FREE',
                    label: 'DAILY REWARD',
                    icon: Icons.play_circle_outline_rounded,
                    gradient: const [Color(0xFF00C853), Color(0xFF69F0AE)],
                    isFree: true,
                    onTap: () {
                      Navigator.pop(ctx);
                      AdService().showRewardedAd(
                        onRewarded: () async {
                          await _progressionService.addCoins(500);
                          await _loadData();
                          if (mounted) _showResult(true,
                            title: '+500 Coins!',
                            message: 'Thanks for watching! Coins added.',
                            icon: Icons.monetization_on_rounded,
                          );
                        },
                        onFailed: () {
                          if (mounted) _showResult(false,
                            title: 'Ad Not Ready',
                            message: 'No ad available right now. Try again later.',
                            icon: Icons.videocam_off_rounded,
                          );
                        },
                      );
                    },
                  ),
                  
                  const SizedBox(height: 15),
                  
                  _coinBundle(
                    amount: 1000, 
                    price: 'KES 200', 
                    label: 'STARTER PACK',
                    icon: Icons.offline_bolt_rounded, 
                    gradient: const [Color(0xFF00B0FF), Color(0xFF00E5FF)],
                    onTap: () { Navigator.pop(ctx); IAPService().purchaseCoins('kadi_coins_1000'); },
                  ),
                  
                  const SizedBox(height: 15),
                  
                  _coinBundle(
                    amount: 2500, 
                    price: 'KES 300', 
                    label: 'MOST POPULAR',
                    icon: Icons.auto_awesome_rounded, 
                    gradient: const [Color(0xFFFFB300), Color(0xFFFFD54F)],
                    badge: "HOT DEAL 🔥",
                    onTap: () { Navigator.pop(ctx); IAPService().purchaseCoins('kadi_coins_2500'); },
                  ),
                  
                  const SizedBox(height: 15),
                  
                  _coinBundle(
                    amount: 5000, 
                    price: 'KES 600', 
                    label: 'LEGEND BUNDLE',
                    icon: Icons.workspace_premium_rounded, 
                    gradient: const [Color(0xFFD500F9), Color(0xFFF50057)],
                    badge: "BEST VALUE 👑",
                    onTap: () { Navigator.pop(ctx); IAPService().purchaseCoins('kadi_coins_5000'); },
                  ),
                  
                  const SizedBox(height: 25),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          IAPService().available ? Icons.security_rounded : Icons.info_outline_rounded, 
                          color: Colors.white30, size: 16
                        ),
                        const SizedBox(width: 10),
                        Text(
                          IAPService().available
                              ? 'Secure encrypted Checkout via Google Play'
                              : 'Service unavailable in your region',
                          style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _coinBundle({
    required int amount,
    required String price,
    required String label,
    required IconData icon,
    required List<Color> gradient,
    String? badge,
    bool isFree = false,
    VoidCallback? onTap,
  }) {
    final primaryColor = gradient[0];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        child: Row(
          children: [
            // Icon Container with gradient
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryColor.withOpacity(0.2), Colors.transparent]),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: primaryColor, size: 30),
            ),
            const SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(badge, style: TextStyle(color: primaryColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                  Text('$amount Coins',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                  Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            
            // Purchase Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Text(price,
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final featured = ShopCatalog.featured;

    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('MARKETPLACE',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                fontSize: 16,
                color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12)),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Coin display
          GestureDetector(
            onTap: _showCoinBundles,
            child: Container(
              margin: const EdgeInsets.only(right: 6, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFFB300), Color(0xFFFF8F00)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: _amber.withOpacity(0.35), blurRadius: 8)
                ],
              ),
              child: Row(children: [
                const Icon(Icons.monetization_on, color: Colors.black, size: 15),
                const SizedBox(width: 5),
                Text('$_coins',
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 13)),
              ]),
            ),
          ),
          // + Get coins
          GestureDetector(
            onTap: _showCoinBundles,
            child: Container(
              margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _amber.withOpacity(0.4)),
              ),
              child: const Icon(Icons.add, color: _amber, size: 18),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Featured Banner ──────────────────────────────
          _buildFeaturedBanner(featured),

          // ── Tabs ────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: _amber.withOpacity(0.15),
                border: Border.all(color: _amber.withOpacity(0.5)),
              ),
              labelColor: _amber,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12),
              tabs: const [
                Tab(text: 'CARD SKINS'),
                Tab(text: 'TABLES'),
              ],
            ),
          ),

          // ── Grid ────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGrid(ShopCatalog.cardSkins, true),
                _buildGrid(ShopCatalog.tableThemes, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Featured Banner ──────────────────────────────────────────

  Widget _buildFeaturedBanner(ShopItem item) {
    final skin = CardSkins.getSkin(item.id);
    final isUnlocked = _unlockedSkins.contains(item.id);
    return GestureDetector(
      onTap: () => isUnlocked ? _selectItem(item.id, true) : _purchaseItem(item),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 96, 16, 12),
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [skin.backGradientStart.withOpacity(0.8), skin.backGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: _amber.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(color: _amber.withOpacity(0.2), blurRadius: 20),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 20),
            // Fanned card preview
            SizedBox(
              width: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(angle: -0.18,
                    child: _miniCard(skin, 50, 72)),
                  Transform.translate(offset: const Offset(10, 3),
                    child: Transform.rotate(angle: 0.08,
                      child: _miniCard(skin, 50, 72))),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _amber.withOpacity(0.5)),
                    ),
                    child: const Text('⭐ FEATURED',
                        style: TextStyle(
                            color: _amber,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5)),
                  ),
                  const SizedBox(height: 6),
                  Text(item.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text(item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isUnlocked) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _amber,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: _amber.withOpacity(0.4), blurRadius: 8)],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${item.price}',
                          style: const TextStyle(
                              color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
                      const SizedBox(width: 4),
                      const Icon(Icons.monetization_on, size: 13, color: Colors.black),
                    ]),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                    ),
                    child: const Text('OWNED',
                        style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _miniCard(CardSkinModel skin, double w, double h) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [skin.backGradientStart, skin.backGradientEnd],
        ),
        border: Border.all(color: Colors.white30, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
      ),
      child: const Center(
        child: Icon(Icons.star, color: Colors.white24, size: 16),
      ),
    );
  }

  // ── Item Grid ────────────────────────────────────────────────

  Widget _buildGrid(List<ShopItem> items, bool isSkin) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isUnlocked = isSkin
            ? _unlockedSkins.contains(item.id)
            : _unlockedThemes.contains(item.id);
        final isSelected = isSkin
            ? _selectedSkin == item.id
            : _selectedTheme == item.id;
        final isLocked  = item.levelRequired > _playerLevel;
        final rColor    = _rarityColor(item.rarity);

        return GestureDetector(
          onTap: () {
            if (isLocked && !isUnlocked) {
              _showResult(false,
                title: '🔒 Locked',
                message: 'Reach Level ${item.levelRequired} to unlock ${item.name}.',
                icon: Icons.lock_rounded,
              );
              return;
            }
            isUnlocked ? _selectItem(item.id, isSkin) : _purchaseItem(item);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? rColor : rColor.withOpacity(0.2),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: rColor.withOpacity(0.25), blurRadius: 14)]
                  : [],
            ),
            child: Stack(
              children: [
                // Card content
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Preview
                    Expanded(
                      child: Center(
                        child: isSkin
                            ? _buildSkinPreview(item.id)
                            : _buildThemePreview(item.id),
                      ),
                    ),
                    // Name + description
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                      child: Column(
                        children: [
                          Text(item.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 3),
                          Text(item.description,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10, height: 1.2),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    // Price / status button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildItemButton(item, isUnlocked, isSelected, isLocked, rColor),
                    ),
                  ],
                ),

                // ── Rarity badge (top-left) ──
                Positioned(
                  top: 10, left: 10,
                  child: _rarityBadge(item.rarity),
                ),

                // ── NEW badge (top-right) ──
                if (item.isNew && !isUnlocked)
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent[700],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('NEW',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5)),
                    ),
                  ),

                // ── Level-lock overlay ──
                if (isLocked && !isUnlocked)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        color: Colors.black.withOpacity(0.6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.lock_rounded, color: Colors.white70, size: 28),
                            const SizedBox(height: 6),
                            Text('Level ${item.levelRequired}',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            const Text('required',
                                style: TextStyle(color: Colors.white38, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemButton(ShopItem item, bool isUnlocked, bool isSelected, bool isLocked, Color rColor) {
    if (isUnlocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? rColor : Colors.greenAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? rColor : Colors.greenAccent.withOpacity(0.4)),
        ),
        child: Text(
          isSelected ? 'EQUIPPED' : 'EQUIP',
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.greenAccent,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      );
    }
    if (item.price == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
        ),
        child: const Text('FREE',
            style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: rColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rColor.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: rColor.withOpacity(0.2), blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${item.price}',
              style: TextStyle(
                  color: rColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12)),
          const SizedBox(width: 3),
          Icon(Icons.monetization_on, size: 12, color: rColor),
        ],
      ),
    );
  }

  // ── Previews ─────────────────────────────────────────────────

  Widget _buildSkinPreview(String skinId) {
    final skin = CardSkins.getSkin(skinId);
    return SizedBox(
      height: 90,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.rotate(angle: -0.18,
            child: _miniCard(skin, 48, 70)),
          _miniCard(skin, 48, 70),
          Transform.translate(
            offset: const Offset(16, 4),
            child: Transform.rotate(angle: 0.18,
              child: PlayingCardWidget(suit: 'hearts', rank: 'ace', width: 48, height: 70)),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePreview(String themeId) {
    final t = TableThemes.getTheme(themeId);
    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [t.gradientColors.first, t.gradientColors.last],
          radius: 0.9,
        ),
        border: Border.all(color: t.accentColor.withOpacity(0.7), width: 2),
        boxShadow: [BoxShadow(color: t.accentColor.withOpacity(0.3), blurRadius: 12)],
      ),
      child: Center(
        child: Container(
          width: 30, height: 22,
          decoration: BoxDecoration(
            color: t.tableColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  // ── Rarity helpers ────────────────────────────────────────────

  Color _rarityColor(ShopRarity rarity) {
    switch (rarity) {
      case ShopRarity.free:      return Colors.white54;
      case ShopRarity.common:    return Colors.lightBlueAccent;
      case ShopRarity.rare:      return Colors.purpleAccent;
      case ShopRarity.epic:      return Colors.orangeAccent;
      case ShopRarity.legendary: return _amber;
    }
  }

  Widget _rarityBadge(ShopRarity rarity) {
    final label = rarity.name.toUpperCase();
    final color = _rarityColor(rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8)),
    );
  }
}