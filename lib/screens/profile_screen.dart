import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/progression_service.dart';
import '../services/theme_service.dart';
import '../services/custom_auth_service.dart';
import '../services/achievement_service.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProgressionService _progressionService = ProgressionService();
  int _coins = 0;
  int _totalWins = 0;
  int _totalGames = 0;
  double _winRate = 0.0;
  String _currentThemeId = 'midnight_elite';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    // 1. Get User ID from CustomAuthService
    // Note: ensure CustomAuthService is initialized in main.dart
    String userId = CustomAuthService().userId ?? "offline";

    // 2. Initialize Progression with User ID
    await _progressionService.initialize(userId: userId);
    await AchievementService().initialize();
    
    if (mounted) {
      setState(() {
        _coins = _progressionService.getCoins();
        _totalWins = _progressionService.getTotalWins();
        _totalGames = _progressionService.getTotalGames();
        _winRate = _progressionService.getWinRate();
        _currentThemeId = _progressionService.getSelectedTheme();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = TableThemes.getTheme(_currentThemeId);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
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
        title: Text("PLAYER STATS", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Stack(
          children: [
            // Background Pattern
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            SafeArea(
              child: Column(
                children: [
                  SizedBox(height: 20),
                  // Avatar Section
                  Container(
                    width: 120, height: 120,
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.accentColor.withOpacity(0.5), width: 2),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [theme.accentColor, theme.accentColor.withOpacity(0.6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(color: theme.accentColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
                        ],
                      ),
                      child: Icon(Icons.person, size: 64, color: Colors.black),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(CustomAuthService().username ?? "Player One", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.accentColor.withOpacity(0.1), 
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.accentColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      _totalWins > 50 ? "CARD MASTER" : (_totalWins > 10 ? "ELITE PLAYER" : "ROOKIE"), 
                      style: TextStyle(color: theme.accentColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)
                    ),
                  ),
                  SizedBox(height: 40),
                  
                  // Stats Grid
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 1.1,
                      children: [
                        _buildModernStatCard("Total Coins", "$_coins", Icons.monetization_on, Colors.amber),
                        _buildModernStatCard("Wins", "$_totalWins", Icons.emoji_events, Colors.greenAccent),
                        _buildModernStatCard("Played", "$_totalGames", Icons.casino, Colors.blueAccent),
                        _buildModernStatCard("Win Rate", "${_winRate.toStringAsFixed(1)}%", Icons.pie_chart, Colors.purpleAccent),
                      ],
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("ACHIEVEMENTS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 14)),
                        Text("${AchievementService().getUnlockedCount()} / ${AchievementService().allAchievements.length}", style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  
                  Container(
                    height: 120,
                    margin: EdgeInsets.only(bottom: 24),
                    child: ListView.builder(
                       scrollDirection: Axis.horizontal,
                       padding: EdgeInsets.symmetric(horizontal: 20),
                       physics: BouncingScrollPhysics(),
                       itemCount: AchievementService().allAchievements.length,
                       itemBuilder: (context, index) {
                          final achievement = AchievementService().allAchievements[index];
                          final isUnlocked = AchievementService().isUnlocked(achievement.id);
                          
                          return Container(
                             width: 100,
                             margin: EdgeInsets.only(right: 16),
                             decoration: BoxDecoration(
                                color: isUnlocked ? Colors.white.withOpacity(0.05) : Colors.black12,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: isUnlocked ? theme.accentColor.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
                             ),
                             child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                   Text(isUnlocked ? achievement.icon : "🔒", style: TextStyle(fontSize: 32)),
                                   SizedBox(height: 8),
                                   Padding(
                                     padding: const EdgeInsets.symmetric(horizontal: 8),
                                     child: Text(
                                       isUnlocked ? achievement.title.toUpperCase() : "LOCKED", 
                                       textAlign: TextAlign.center,
                                       style: TextStyle(color: isUnlocked ? Colors.white : Colors.white24, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                                       maxLines: 1,
                                       overflow: TextOverflow.ellipsis
                                     ),
                                   )
                                ],
                             ),
                          );
                       },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernStatCard(String title, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              SizedBox(height: 12),
              Text(value, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text(title.toUpperCase(), style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }
}