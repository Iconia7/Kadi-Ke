import 'package:flutter/material.dart';
import '../services/progression_service.dart';
import '../services/theme_service.dart';
import '../services/firebase_game_service.dart';

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
    // 1. Ensure Firebase is ready and get User ID
    await FirebaseGameService().initialize();
    String userId = FirebaseGameService().currentUserId;

    // 2. Initialize Progression with User ID
    await _progressionService.initialize(userId: userId);
    
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
            colors: theme.gradientColors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(height: 20),
              // Avatar Section
              Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [theme.accentColor, Colors.blueAccent]),
                  boxShadow: [BoxShadow(color: theme.accentColor.withOpacity(0.4), blurRadius: 20)],
                  border: Border.all(color: Colors.white, width: 2)
                ),
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
              SizedBox(height: 16),
              Text("Player One", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                child: Text("Rookie Card Player", style: TextStyle(color: theme.accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 40),
              
              // Stats Grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: EdgeInsets.all(20),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _buildStatCard("Total Coins", "$_coins", Icons.monetization_on, Colors.amber),
                    _buildStatCard("Wins", "$_totalWins", Icons.emoji_events, Colors.greenAccent),
                    _buildStatCard("Games Played", "$_totalGames", Icons.casino, Colors.blueAccent),
                    _buildStatCard("Win Rate", "${_winRate.toStringAsFixed(1)}%", Icons.pie_chart, Colors.purpleAccent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10)]
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          SizedBox(height: 12),
          Text(value, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}