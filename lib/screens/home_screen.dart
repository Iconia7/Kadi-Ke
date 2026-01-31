import 'dart:async'; // Required for StreamSubscription
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:ui';
import 'game_screen.dart'; 
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'profile_screen.dart';
import 'tournament_screen.dart'; // ADDED
import 'leaderboard_screen.dart'; // ADDED
import '../services/custom_auth_service.dart'; // Replaced Firebase Auth
import '../services/vps_game_service.dart';   // Replaced Firebase Game Service

import '../services/progression_service.dart';
import '../services/achievement_service.dart';
import '../services/challenge_service.dart';
import '../widgets/daily_reward_dialog.dart';
import '../widgets/daily_challenge_card.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  String? _myIpAddress;
  late AnimationController _floatingController;
  late Animation<double> _floatingAnimation;
  
  String _selectedGameMode = 'kadi'; // 'kadi' or 'gofish'
  
  bool _isFirebaseReady = false;

  @override
  void initState() {
    super.initState();
    _getIpAddress();
    _initFirebaseCheck();
    
    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    _floatingAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initFirebaseCheck() async {
    try {
      // Just ensure the Game Service is ready (Auth login)
      await CustomAuthService().initialize();
      // Initialize Progression
      String uid = CustomAuthService().userId ?? "offline";
      await ProgressionService().initialize(userId: uid);
      await AchievementService().initialize(userId: uid);
      await ChallengeService().initialize();
      
      if (mounted) {
         setState(() => _isFirebaseReady = true);
         _checkDailyReward();
      }
    } catch (e) {
      print("Auth Service Error: $e");
      // Allow UI to show even if Auth fails (for Offline mode)
      if (mounted) setState(() => _isFirebaseReady = true);
    }
  }

  Future<void> _checkDailyReward() async {
     try {
        var res = await ProgressionService().checkDailyLogin();
        if (res['canClaim'] == true) {
           int reward = res['reward'];
           int streak = res['streak'];
           await ProgressionService().addCoins(reward); // Secure logic
           
           showDialog(
             context: context,
             barrierDismissible: false,
             builder: (c) => DailyRewardDialog(
               streak: streak, 
               reward: reward, 
               onClose: () => Navigator.pop(context),
             )
           );
        }
     } catch (e) {
        print("Daily Reward Error: $e");
     }
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _ipController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _getIpAddress() async {
    final info = NetworkInfo();
    var ip = await info.getWifiIP();
    setState(() {
      _myIpAddress = ip ?? "Unknown";
    });
  }

  // --- ONLINE METHODS (UPDATED FOR RENDER SERVER) ---

  void _startOnlineHost() {
    if (!_isFirebaseReady) return;
    
    // show Betting Dialog FIRST, then Rules
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text("Select Stakes", style: TextStyle(color: Colors.amber)),
        backgroundColor: Color(0xFF1E293B),
        children: [
          _buildStakeOption("Casual (Free)", 0),
          _buildStakeOption("High Stakes (100 Coins)", 100),
          _buildStakeOption("Pro Table (500 Coins)", 500),
        ],
      )
    );
  }

  Widget _buildStakeOption(String title, int fee) {
    return SimpleDialogOption(
       onPressed: () {
          Navigator.pop(context);
          _showRulesConfigDialog(fee); // NEXT: Rules
       },
       child: Padding(
         padding: const EdgeInsets.symmetric(vertical: 8.0),
         child: Row(
            children: [
               Icon(fee == 0 ? Icons.casino_outlined : Icons.monetization_on, color: fee == 0 ? Colors.white70 : Colors.amber),
               SizedBox(width: 12),
               Text(title, style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
         ),
       ),
    );
  }

  void _showRulesConfigDialog(int fee) {
     Map<String, dynamic> rules = {
       'jokerPenalty': 5,
       'queenAction': 'question',
       'allowBombStacking': true
     };

     showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
           builder: (context, setState) {
              return AlertDialog(
                 backgroundColor: Color(0xFF1E293B),
                 title: Text("House Rules", style: TextStyle(color: Colors.white)),
                 content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       SwitchListTile(
                          title: Text("Allow Bomb Stacking?", style: TextStyle(color: Colors.white)),
                          subtitle: Text("Can players reply to a bomb with a bomb?", style: TextStyle(color: Colors.white54, fontSize: 12)),
                          value: rules['allowBombStacking'],
                          activeColor: Colors.green,
                          onChanged: (v) => setState(() => rules['allowBombStacking'] = v),
                       ),
                       ListTile(
                          title: Text("Joker Penalty", style: TextStyle(color: Colors.white)),
                          trailing: DropdownButton<int>(
                             value: rules['jokerPenalty'],
                             dropdownColor: Color(0xFF2E3E5E),
                             style: TextStyle(color: Colors.white),
                             items: [5, 10].map((e) => DropdownMenuItem(value: e, child: Text("Pick $e"))).toList(),
                             onChanged: (v) => setState(() => rules['jokerPenalty'] = v),
                          ),
                       ),
                       ListTile(
                          title: Text("Queen Action", style: TextStyle(color: Colors.white)),
                          trailing: DropdownButton<String>(
                             value: rules['queenAction'],
                             dropdownColor: Color(0xFF2E3E5E),
                             style: TextStyle(color: Colors.white),
                             items: [
                               DropdownMenuItem(value: 'question', child: Text("Question")),
                               DropdownMenuItem(value: 'skip', child: Text("Skip Turn")),
                             ].toList(),
                             onChanged: (v) => setState(() => rules['queenAction'] = v),
                          ),
                       ),
                    ],
                 ),
                 actions: [
                    TextButton(onPressed: () => _createOnlineRoom(fee, rules), child: Text("START GAME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))
                 ],
              );
           }
        )
     );
  }

  void _createOnlineRoom(int fee, Map<String, dynamic> rules) async {
    Navigator.pop(context); // Close Rules Dialog

    if (fee > 0) {
       // Check balance
       int balance = ProgressionService().getCoins();
       if (balance < fee) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Not enough coins! Need $fee.")));
          return;
       }
       ProgressionService().spendCoins(fee); // Pay Entry
    }

    // 1. Show Loading Spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Center(child: CircularProgressIndicator(color: Colors.amber)),
    );

    try {
      // 2. Call VPS Service
      String roomCode = await VPSGameService().createGame(_selectedGameMode, entryFee: fee, rules: rules);
      
      if (mounted) {
        Navigator.pop(context); // Close spinner

        Navigator.push(context, MaterialPageRoute(builder: (context) => 
          GameScreen(
            isHost: true, 
            hostAddress: 'online', 
            onlineGameCode: roomCode,
            gameType: _selectedGameMode, 
          )
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close spinner
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error creating room: $e")));
      }
    }
  }

  void _joinOnlineGame() {
    if (!_isFirebaseReady) return;

    String code = _codeController.text.toUpperCase().trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Code must be 6 characters")));
      return;
    }
    
    // For joining, we can navigate immediately. The GameScreen will handle the connection.
    Navigator.pop(context); // Close dialog
    Navigator.push(context, MaterialPageRoute(builder: (context) => 
      GameScreen(
        isHost: false, 
        hostAddress: 'online', 
        onlineGameCode: code,
        gameType: _selectedGameMode, 
      )
    ));
  }

  // --- LOCAL METHODS ---
  void _startHosting() {
    Navigator.pop(context); 
    Navigator.push(context, MaterialPageRoute(builder: (context) => 
      GameScreen(
        isHost: true, 
        hostAddress: 'localhost',
        gameType: _selectedGameMode,
      )
    ));
  }

  void _joinGame() {
    if (_ipController.text.isNotEmpty) {
      Navigator.pop(context); 
      Navigator.push(context, MaterialPageRoute(builder: (context) => 
        GameScreen(
          isHost: false, 
          hostAddress: _ipController.text,
          gameType: _selectedGameMode,
        )
      ));
    }
  }

  void _startOfflineGame(int aiCount, String difficulty) {
    Navigator.pop(context); 
    Navigator.push(context, MaterialPageRoute(builder: (context) => 
      GameScreen(
        isHost: true, 
        hostAddress: 'offline', 
        aiCount: aiCount,
        gameType: _selectedGameMode,
      )
    ));
  }

  // --- DIALOGS ---
  void _showSinglePlayerDialog() {
    int aiCount = 1;
    String difficulty = "Medium";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF0F1E3A)]),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("SINGLE PLAYER", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text("Mode: ${_selectedGameMode == 'kadi' ? 'Kadi' : 'Go Fish'}", style: TextStyle(color: Colors.amber)),
                    SizedBox(height: 24),
                    Slider(
                      value: aiCount.toDouble(),
                      min: 1, max: 3, divisions: 2,
                      activeColor: Colors.amber,
                      label: "$aiCount Bots",
                      onChanged: (val) => setDialogState(() => aiCount = val.toInt()),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _startOfflineGame(aiCount, difficulty),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: Text("START MATCH", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  void _showMultiplayerDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2E1E5F), Color(0xFF1E1E3A)]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("MULTIPLAYER", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Text("Mode: ${_selectedGameMode == 'kadi' ? 'Kadi' : 'Go Fish'}", style: TextStyle(color: Colors.amber, fontSize: 12)),
              SizedBox(height: 20),
              
              DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      indicatorColor: Colors.amber,
                      tabs: [Tab(text: "ONLINE"), Tab(text: "LOCAL LAN")],
                    ),
                    Container(
                      height: 250,
                      child: TabBarView(
                        children: [
                          // ONLINE TAB
                          _isFirebaseReady 
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _startOnlineHost, // Uses new Logic
                                  icon: Icon(Icons.add),
                                  label: Text("Create Room"),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                                ),
                                SizedBox(height: 20),
                                TextField(
                                  controller: _codeController,
                                  style: TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: "Enter Room Code",
                                    hintStyle: TextStyle(color: Colors.white30),
                                    filled: true,
                                    fillColor: Colors.white10,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                SizedBox(height: 10),
                                ElevatedButton(onPressed: _joinOnlineGame, child: Text("Join Room")),
                              ],
                            )
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: Colors.amber),
                                  SizedBox(height: 10),
                                  Text("Connecting...", style: TextStyle(color: Colors.white54)),
                                ],
                              ),
                            ),
                          // LOCAL TAB
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ListTile(
                                leading: Icon(Icons.wifi, color: Colors.green),
                                title: Text("Host LAN", style: TextStyle(color: Colors.white)),
                                subtitle: Text("IP: $_myIpAddress", style: TextStyle(color: Colors.white54, fontSize: 10)),
                                onTap: _startHosting,
                              ),
                              SizedBox(height: 10),
                              TextField(
                                controller: _ipController,
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: "Host IP",
                                  filled: true,
                                  fillColor: Colors.white10,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              ElevatedButton(onPressed: _joinGame, child: Text("Connect LAN")),
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- MAIN BUILD ---
@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.3,
            colors: [Color(0xFF2E5077), Color(0xFF0F1E3A)],
          ),
        ),
        child: Stack(
          children: [
            // 1. Floating Icon (Background)
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) => Positioned(
                top: 100 + _floatingAnimation.value,
                left: 40,
                child: Opacity(opacity: 0.05, child: Icon(Icons.style, size: 120, color: Colors.white)),
              ),
            ),

            // 2. SETTINGS BUTTON (MOVED HERE - Correct Spot inside Stack)
            Positioned(
              top: 50,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingsScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                  ),
                  child: const Icon(Icons.settings, color: Colors.white, size: 28),
                ),
              ),
            ),

            // 3. Main Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_fill_rounded, size: 64, color: Colors.amber),
                      SizedBox(height: 12),
                      Text("KADI KE", style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 6)),
                      Text("PREMIUM CARD EXPERIENCE", style: TextStyle(color: Colors.blueGrey[200], letterSpacing: 3, fontSize: 12, fontWeight: FontWeight.bold)),
                      
                      SizedBox(height: 40),
                      
                      // GAME MODE SELECTOR
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildModeTab("KADI", _selectedGameMode == 'kadi', () => setState(() => _selectedGameMode = 'kadi')),
                            _buildModeTab("GO FISH", _selectedGameMode == 'gofish', () => setState(() => _selectedGameMode = 'gofish')),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 30),
                      _buildMenuButton("SINGLE PLAYER", Icons.person, Colors.blueAccent, _showSinglePlayerDialog),
                      SizedBox(height: 20),
                      _buildMenuButton("MULTIPLAYER", Icons.groups, Colors.deepPurpleAccent, _showMultiplayerDialog),
                      SizedBox(height: 20),
                      _buildMenuButton("TOURNAMENT", Icons.emoji_events, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (c) => TournamentScreen(gameType: _selectedGameMode)))),
                      SizedBox(height: 20),
                      _buildMenuButton("LEADERBOARD", Icons.bar_chart, Colors.purpleAccent, () => Navigator.push(context, MaterialPageRoute(builder: (c) => LeaderboardScreen()))),
                      SizedBox(height: 60),
                      
                      // Bottom Row (Fixed: Removed the Positioned widget from here)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildIconButton("Shop", Icons.shopping_bag_outlined, Colors.amber, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopScreen()))),
                          SizedBox(width: 40),
                          _buildIconButton("Profile", Icons.account_circle, Colors.greenAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white54, 
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2
          )
        ),
      ),
    );
  }

  Widget _buildMenuButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300,
        height: 70,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(0.8), color.withOpacity(0.4)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 16)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            SizedBox(width: 16),
            Text(label, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
        ),
        SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildChallengesSection() {
    final challenges = ChallengeService().getActiveChallenges();
    final timeUntilRefresh = ChallengeService().getTimeUntilRefresh();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E1E5F).withOpacity(0.6), Color(0xFF1E1E3A).withOpacity(0.6)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.flag, color: Color(0xFF00E5FF), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'DAILY CHALLENGES',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Text(
                'Resets in ${timeUntilRefresh.inHours}h ${timeUntilRefresh.inMinutes % 60}m',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...challenges.map((challenge) => DailyChallengeCard(
            challenge: challenge,
            onClaim: () => _claimChallengeReward(challenge.id),
          )).toList(),
        ],
      ),
    );
  }

  Future<void> _claimChallengeReward(String challengeId) async {
    try {
      final rewards = await ChallengeService().claimReward(challengeId);
      if (rewards != null) {
        // Add coins and XP
        ProgressionService().addCoins(rewards['coins']!);
        // TODO: Add XP system (future enhancement)
        
        setState(() {}); // Refresh UI
        
        // Show reward notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Challenge Complete! +${rewards['coins']} coins'),
              backgroundColor: Color(0xFF00E5FF),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('Error claiming reward: $e');
    }
  }

}