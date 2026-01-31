import 'package:flutter/material.dart' hide ThemeData;
import 'dart:ui';
import '../services/progression_service.dart';
import '../services/theme_service.dart';
import '../services/sound_service.dart';
import '../services/custom_auth_service.dart';
import '../widgets/playing_card_widget.dart'; 

class ShopScreen extends StatefulWidget {
  @override
  _ShopScreenState createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with SingleTickerProviderStateMixin {
  final ProgressionService _progressionService = ProgressionService();
  late TabController _tabController;
  int _coins = 0;
  List<String> _unlockedSkins = [];
  List<String> _unlockedThemes = [];
  String _selectedSkin = '';
  String _selectedTheme = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    // 1. Get User ID from CustomAuthService
    // CustomAuthService should already be initialized in main.dart
    String userId = CustomAuthService().userId ?? "offline";

    // 2. Initialize Progression with User ID
    await _progressionService.initialize(userId: userId);
    
    if (mounted) {
      setState(() {
        _coins = _progressionService.getCoins();
        _unlockedSkins = _progressionService.getUnlockedSkins();
        _unlockedThemes = _progressionService.getUnlockedThemes();
        _selectedSkin = _progressionService.getSelectedSkin();
        _selectedTheme = _progressionService.getSelectedTheme();
      });
    }
  }

  Future<void> _purchaseItem(ShopItem item) async {
    if (_coins >= item.price) {
      bool success = await _progressionService.spendCoins(item.price);
      if (success) {
        if (item.type == ShopItemType.cardSkin) {
          await _progressionService.unlockSkin(item.id);
          await _progressionService.selectSkin(item.id);
        } else {
          await _progressionService.unlockTheme(item.id);
          await _progressionService.selectTheme(item.id);
        }
        
        SoundService.play('win');
        await _loadData();
        _showPurchaseDialog("Purchase Successful", "Item equipped!", true);
      }
    } else {
      SoundService.play('error');
      _showPurchaseDialog("Insufficient Funds", "You need ${item.price - _coins} more coins.", false);
    }
  }

  Future<void> _selectItem(String id, bool isSkin) async {
    if (isSkin) await _progressionService.selectSkin(id);
    else await _progressionService.selectTheme(id);
    
    SoundService.play('place');
    await _loadData();
  }

  void _showPurchaseDialog(String title, String msg, bool success) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: success ? Colors.cyanAccent : Colors.redAccent, width: 1),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(success ? Icons.check_circle_outline : Icons.error_outline, 
                   color: success ? Colors.cyanAccent : Colors.redAccent, size: 50),
              SizedBox(height: 16),
              Text(title, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(msg, textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: success ? Colors.cyanAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: success ? Colors.cyanAccent : Colors.redAccent),
                  shape: StadiumBorder()
                ),
                child: Text("OK"),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Access the current theme for background
    final currentTheme = TableThemes.getTheme(_selectedTheme);
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("MARKETPLACE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
            child: Icon(Icons.arrow_back, size: 18),
          ), 
          onPressed: () => Navigator.pop(context)
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.amber[700]!, Colors.amber[500]!]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 8)],
            ),
            child: Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text("$_coins", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: currentTheme.gradientColors, 
            begin: Alignment.topCenter, 
            end: Alignment.bottomCenter
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: currentTheme.accentColor.withOpacity(0.2),
                    border: Border.all(color: currentTheme.accentColor.withOpacity(0.5)),
                  ),
                  labelColor: currentTheme.accentColor,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                  tabs: [
                    Tab(text: "CARD SKINS"),
                    Tab(text: "TABLES"),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGrid(ShopCatalog.cardSkins, true, currentTheme),
                    _buildGrid(ShopCatalog.tableThemes, false, currentTheme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<ShopItem> items, bool isSkin, ThemeModel theme) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isUnlocked = isSkin ? _unlockedSkins.contains(item.id) : _unlockedThemes.contains(item.id);
        final isSelected = isSkin ? _selectedSkin == item.id : _selectedTheme == item.id;
        
        return GestureDetector(
          onTap: () => isUnlocked ? _selectItem(item.id, isSkin) : _purchaseItem(item),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? theme.accentColor : Colors.white10, 
                width: isSelected ? 2 : 1
              ),
              boxShadow: isSelected ? [BoxShadow(color: theme.accentColor.withOpacity(0.2), blurRadius: 15)] : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: isSkin 
                      ? _buildSkinPreview(item.id) 
                      : _buildThemePreview(item.id),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(item.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
                ),
                SizedBox(height: 12),
                if (isUnlocked)
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.accentColor : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isSelected ? "EQUIPPED" : "OWNED", 
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.greenAccent, 
                        fontSize: 10, fontWeight: FontWeight.bold
                      )
                    ),
                  )
                else
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber, 
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 8)]
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${item.price}", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14)),
                        Icon(Icons.monetization_on, size: 14, color: Colors.black)
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkinPreview(String skinId) {
    final skinData = CardSkins.getSkin(skinId);
    return Transform.scale(
      scale: 0.8,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.1,
            child: PlayingCardWidget(suit: 'spades', rank: 'ace', width: 60, height: 90),
          ),
          Transform.translate(
            offset: Offset(15, 5),
            child: Transform.rotate(
              angle: 0.1,
              child: Container(
                width: 60, height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [skinData.backGradientStart, skinData.backGradientEnd]),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 5)],
                ),
                child: Center(child: Icon(Icons.star, color: Colors.white24, size: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePreview(String themeId) {
    final themeData = TableThemes.getTheme(themeId);
    return Container(
      width: 70, height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: themeData.gradientColors),
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
    );
  }
}