import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/progression_service.dart';
import '../services/theme_service.dart';
import '../services/custom_auth_service.dart';
import '../services/app_config.dart';
import '../services/achievement_service.dart';
import '../services/feedback_service.dart';
import 'package:in_app_review/in_app_review.dart';

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
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120, height: 120,
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.accentColor.withOpacity(0.5), width: 2),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black26, 
                          image: CustomAuthService().avatar != null 
                             ? DecorationImage(
                                 image: NetworkImage("${CustomAuthService().baseUrl}${CustomAuthService().avatar}"),
                                 fit: BoxFit.cover
                               ) 
                             : null,
                          gradient: CustomAuthService().avatar == null ? LinearGradient(
                            colors: [theme.accentColor, theme.accentColor.withOpacity(0.6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ) : null,
                          boxShadow: [
                            BoxShadow(color: theme.accentColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
                          ],
                        ),
                        child: CustomAuthService().avatar == null 
                           ? Icon(Icons.person, size: 64, color: Colors.black)
                           : null,
                      ),
                    ),
                  ),
                  if (CustomAuthService().userId == "offline")
                     Padding(
                       padding: const EdgeInsets.only(top: 8.0),
                       child: Text("Login to upload avatar", style: TextStyle(color: Colors.white38, fontSize: 10)),
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
                  
                  SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 24),
            SizedBox(width: 16),
            Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Spacer(),
            Icon(Icons.chevron_right, color: Colors.white30),
          ],
        ),
      ),
    );
  }

  void _showFeedbackDialog() {
    final TextEditingController feedbackController = TextEditingController();
    String type = 'Bug Report';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Color(0xFF1E293B),
          title: Text("Submit Feedback", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: type,
                dropdownColor: Color(0xFF2E3E5E),
                isExpanded: true,
                style: TextStyle(color: Colors.white),
                items: ['Bug Report', 'Suggestion', 'Praise', 'Other']
                   .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                   .toList(),
                onChanged: (v) => setDialogState(() => type = v!),
              ),
              SizedBox(height: 16),
              TextField(
                controller: feedbackController,
                maxLines: 4,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Tell us what happened or what you'd like to see...",
                  hintStyle: TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                String msg = feedbackController.text.trim();
                if (msg.isEmpty) return;
                
                Navigator.pop(context);
                bool sent = await FeedbackService().submitFeedback(msg, type);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(sent ? "Thank you for your feedback!" : "Feedback saved locally. Will sync when online."),
                      backgroundColor: sent ? Colors.green : Colors.orange,
                    )
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              child: Text("SUBMIT"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestAppReview() async {
    try {
      final InAppReview inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      } else {
        // Fallback: Open Play Store directly with real package name
        await inAppReview.openStoreListing(appStoreId: 'com.kadi.ke');
      }
    } catch (e) {
      // Gracefully handle if Play Store isn't available
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Play Store review. Try again later.'), backgroundColor: Colors.orange),
        );
      }
    }
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

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
        _uploadAvatar(File(image.path));
    }
  }

  Future<void> _uploadAvatar(File file) async {
      try {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Uploading Avatar...")));
        
        await CustomAuthService().uploadProfilePicture(file);
        
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Avatar Uploaded!")));
            setState(() {}); // Refresh to show new avatar
        }
      } catch (e) {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Failed: $e")));
         }
      }
  }
}