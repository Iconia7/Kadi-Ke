import 'dart:async'; // Required for StreamSubscription
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'game_screen.dart'; 
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'profile_screen.dart';
import 'tournament_screen.dart'; // ADDED
import 'leaderboard_screen.dart'; // ADDED
import 'tutorial_screen.dart';
import 'friends_screen.dart';
import '../services/custom_auth_service.dart'; // Replaced Firebase Auth
import '../services/vps_game_service.dart';   // Replaced Firebase Game Service
import '../services/notification_service.dart';
import '../services/friend_service.dart';

import '../services/progression_service.dart';
import '../services/achievement_service.dart';
// Removed redundant ChallengeService
import '../models/challenge_model.dart';
import '../models/friend_model.dart';
import '../widgets/daily_reward_dialog.dart';
import '../widgets/daily_challenge_card.dart';
import '../widgets/challenge_dialog.dart';
import '../widgets/friend_invite_bottom_sheet.dart';

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
  StreamSubscription? _gameSubscription;
  
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
      await ProgressionService().checkAndResetChallenges(); // Unified
      
         if (mounted) {
            setState(() => _isFirebaseReady = true);
            _checkDailyReward();
            _checkDailyChallenges(); // NEW: Check for daily challenges auto-popup
            _setupGlobalListeners();
            NotificationService().scheduleDailyChallengeReminder(); // NEW: Schedule daily notif
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
    _gameSubscription?.cancel();
    _floatingController.dispose();
    _ipController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _setupGlobalListeners() async {
     // Connect to VPS for global notifications (invites, friend status)
     await VPSGameService().connect();
     _gameSubscription?.cancel();
     _gameSubscription = VPSGameService().gameStream.listen(_handleGlobalMessage);
     
     // Check for Streak Reminder
     _checkStreakReminder();
  }

  void _handleGlobalMessage(Map<String, dynamic> message) {
     final type = message['type'];
     final data = message['data'];
     
     switch (type) {
        case 'GAME_INVITE':
           NotificationService().showGameInviteNotification(
              data['friendName'], 
              data['roomCode'],
              ipAddress: data['ipAddress'],
              gameType: data['gameType'] ?? 'kadi',
           );
           break;
        case 'FRIEND_ONLINE':
           NotificationService().showFriendOnlineNotification(
              data['friendName'], 
              data['friendId'],
           );
           break;
        case 'FRIEND_REQUEST':
           NotificationService().showFriendRequestNotification(
              data['friendName'], 
              data['friendId'],
           );
           break;
        case 'FRIEND_ACCEPT':
           NotificationService().showFriendAcceptNotification(
              data['friendName'],
           );
           break;
        case 'FRIEND_OFFLINE':
           // Optional: Handle offline status if needed
           break;
     }
  }

  Future<void> _checkStreakReminder() async {
     try {
        final prefs = await SharedPreferences.getInstance();
        final streak = prefs.getInt('current_streak') ?? 0;
        final lastLogin = prefs.getString('last_login_time');
        
        if (streak > 0 && lastLogin != null) {
           final lastDate = DateTime.parse(lastLogin);
           final now = DateTime.now();
           
           // If it's been more than 12 hours since last login, show a reminder
           if (now.difference(lastDate).inHours > 12 && now.day != lastDate.day) {
              NotificationService().showStreakReminderNotification(streak);
           }
        }
     } catch (e) {
        print("Streak Reminder Error: $e");
     }
  }

  Future<String> _getIpAddress() async {
    final info = NetworkInfo();
    var ip = await info.getWifiIP();
    if (mounted) {
      setState(() {
        _myIpAddress = ip ?? "Unknown";
      });
    }
    return ip ?? "Unknown";
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
          if (_selectedGameMode == 'gofish') {
             _createOnlineRoom(fee, {}); // No rules for Go Fish
          } else {
             _showRulesConfigDialog(fee); // Kadi Rules
          }
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

        // Show friend invite option
        await _showFriendInvitePrompt(roomCode, null);

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

  void _quickMatch() {
    _showLobbyDialog();
  }

  void _showLobbyDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("GAME LOBBY", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    IconButton(icon: Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: VPSGameService().getActiveRooms(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: Colors.amber));
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sensor_door_outlined, size: 64, color: Colors.white24),
                            SizedBox(height: 16),
                            Text("No open rooms found", style: TextStyle(color: Colors.white54)),
                            SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _startQuickMatchAutomated,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                              child: Text("CREATE QUICK ROOM"),
                            )
                          ],
                        ),
                      );
                    }

                    final rooms = snapshot.data!;
                    return ListView.builder(
                      itemCount: rooms.length,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        final fee = room['entryFee'] ?? 0;
                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: fee > 0 ? Colors.amber : Colors.blueAccent,
                              child: Icon(fee > 0 ? Icons.monetization_on : Icons.casino, color: Colors.black, size: 20),
                            ),
                            title: Text("Room: ${room['code']}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text("${room['gameType'].toString().toUpperCase()} • ${room['players']} Players", style: TextStyle(color: Colors.white54, fontSize: 12)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min, // Fix Overflow
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(fee > 0 ? "$fee Coins" : "FREE", style: TextStyle(color: fee > 0 ? Colors.amber : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                                SizedBox(height: 2),
                                SizedBox(
                                  height: 24, 
                                  child: ElevatedButton(
                                    onPressed: () => _joinRoomFromLobby(room['code'].toString()),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text("JOIN", style: TextStyle(fontSize: 10)),
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _startQuickMatchAutomated,
                    icon: Icon(Icons.bolt),
                    label: Text("QUICK START ANY"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber,
                      side: BorderSide(color: Colors.amber),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _joinRoomFromLobby(String roomCode) {
    Navigator.pop(context); // Close lobby
    Navigator.push(context, MaterialPageRoute(builder: (context) => 
      GameScreen(
        isHost: false, 
        hostAddress: 'online', 
        onlineGameCode: roomCode,
        gameType: _selectedGameMode, 
      )
    ));
  }

  Future<void> _startQuickMatchAutomated() async {
     Navigator.pop(context); // Close lobby
     
     // 1. Show Loading Spinner
     showDialog(
       context: context,
       barrierDismissible: false,
       builder: (c) => Center(child: CircularProgressIndicator(color: Colors.amber)),
     );
 
     try {
       // 2. Automated Matchmaking
       final result = await VPSGameService().findMatch(_selectedGameMode, entryFee: 0);
       String roomCode = result['roomCode'];
       bool isHost = result['isHost'];
       
       if (mounted) {
         Navigator.pop(context); // Close spinner
 
         Navigator.push(context, MaterialPageRoute(builder: (context) => 
           GameScreen(
             isHost: isHost, 
             hostAddress: 'online', 
             onlineGameCode: roomCode,
             gameType: _selectedGameMode, 
           )
         ));
       }
     } catch (e) {
       if (mounted) {
         Navigator.pop(context); // Close spinner
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Matchmaking failed: $e")));
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
  void _startHosting() async {
    Navigator.pop(context);
    
    // Get IP for LAN invite
    String myIp = await _getIpAddress();
    
    // Show friend invite option
    await _showFriendInvitePrompt(null, myIp);
    
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
              insetPadding: EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1E293B).withOpacity(0.9),
                          Color(0xFF0F172A).withOpacity(0.95),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white12, width: 1.5),
                    ),
                    padding: EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "SINGLE PLAYER",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close, color: Colors.white54, size: 20),
                            ),
                          ],
                        ),
                        Divider(color: Colors.white10, height: 30),
                        
                        // Game Mode Badge
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFF00E5FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(0xFF00E5FF).withOpacity(0.3)),
                          ),
                          child: Text(
                            "MODE: ${_selectedGameMode.toUpperCase()}",
                            style: TextStyle(
                              color: Color(0xFF00E5FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        SizedBox(height: 30),

                        // Bot Count Selection
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "NUMBER OF BOTS",
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [1, 2, 3].map((count) {
                            bool isSelected = aiCount == count;
                            return GestureDetector(
                              onTap: () => setDialogState(() => aiCount = count),
                              child: Container(
                                width: (MediaQuery.of(context).size.width - 150) / 3,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isSelected ? Color(0xFF00E5FF).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: isSelected ? Color(0xFF00E5FF) : Colors.white10,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "$count",
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white60,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 24),

                        // Difficulty Selection
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "DIFFICULTY",
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: ["Easy", "Medium", "Hard"].map((diff) {
                            bool isSelected = difficulty == diff;
                            return GestureDetector(
                              onTap: () => setDialogState(() => difficulty = diff),
                              child: Container(
                                width: (MediaQuery.of(context).size.width - 150) / 3,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? Color(0xFF00E5FF).withOpacity(0.5) : Colors.white10,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  diff.toUpperCase(),
                                  style: TextStyle(
                                    color: isSelected ? Color(0xFF00E5FF) : Colors.white38,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 40),

                        // Action Button
                        Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF00E5FF).withOpacity(0.2),
                                blurRadius: 15,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => _startOfflineGame(aiCount, difficulty),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF00E5FF),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              "START MATCH",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMultiplayerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1E293B).withOpacity(0.9),
                          Color(0xFF0F172A).withOpacity(0.95),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white12, width: 1.5),
                    ),
                    padding: EdgeInsets.all(24),
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "MULTIPLAYER",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(Icons.close, color: Colors.white54, size: 20),
                              ),
                            ],
                          ),
                          Divider(color: Colors.white10, height: 20),
                          
                          // TabBar
                          Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: TabBar(
                              indicator: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color: Color(0xFF00E5FF).withOpacity(0.2),
                                border: Border.all(color: Color(0xFF00E5FF).withOpacity(0.5)),
                              ),
                              labelColor: Color(0xFF00E5FF),
                              unselectedLabelColor: Colors.white38,
                              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
                              tabs: [Tab(text: "ONLINE"), Tab(text: "LOCAL LAN")],
                            ),
                          ),
                          SizedBox(height: 20),

                          SizedBox(
                            height: 300,
                            child: TabBarView(
                              children: [
                                // ONLINE TAB
                                _buildOnlineTab(),
                                // LOCAL TAB
                                _buildLocalTab(),
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
          },
        );
      },
    );
  }

  Widget _buildOnlineTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_isFirebaseReady)
          Column(
            children: [
              CircularProgressIndicator(color: Color(0xFF00E5FF)),
              SizedBox(height: 16),
              Text("Connecting to Game Services...", style: TextStyle(color: Colors.white54, fontSize: 13)),
            ],
          )
        else ...[
          // Create Button
          _buildActionButton(
            onPressed: _startOnlineHost,
            icon: Icons.add_circle_outline,
            label: "CREATE PRIVATE ROOM",
            isPrimary: true,
          ),
          SizedBox(height: 30),
          // Join Section
          Text("OR JOIN WITH CODE", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
          SizedBox(height: 16),
          _buildCodeInput(),
          SizedBox(height: 16),
          _buildActionButton(
            onPressed: _joinOnlineGame,
            icon: Icons.login_outlined,
            label: "JOIN ROOM",
            isPrimary: false,
          ),
        ],
      ],
    );
  }

  Widget _buildLocalTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Host Section
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.wifi, color: Colors.greenAccent, size: 24),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("HOST LOCAL GAME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text("Your IP: $_myIpAddress", style: TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _startHosting,
                    child: Text("START", style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
        Text("OR CONNECT VIA IP", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
        SizedBox(height: 16),
        _buildIpInput(),
        SizedBox(height: 16),
        _buildActionButton(
          onPressed: _joinGame,
          icon: Icons.lan_outlined,
          label: "CONNECT TO HOST",
          isPrimary: false,
        ),
      ],
    );
  }

  Widget _buildActionButton({required VoidCallback onPressed, required IconData icon, required String label, bool isPrimary = false}) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: isPrimary ? [
          BoxShadow(
            color: Color(0xFF00E5FF).withOpacity(0.2),
            blurRadius: 12,
            offset: Offset(0, 4),
          )
        ] : [],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Color(0xFF00E5FF) : Colors.white.withOpacity(0.1),
          foregroundColor: isPrimary ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildCodeInput() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: _codeController,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 4, fontSize: 18),
        decoration: InputDecoration(
          hintText: "ROOM CODE",
          hintStyle: TextStyle(color: Colors.white24, letterSpacing: 1, fontSize: 12),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildIpInput() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: _ipController,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 16),
        decoration: InputDecoration(
          hintText: "192.168.1.100",
          hintStyle: TextStyle(color: Colors.white24, letterSpacing: 1, fontSize: 12),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E293B),
              Color(0xFF0F172A),
              Color(0xFF1E1B4B),
            ],
          ),
        ),
        child: Stack(
          children: [
            // 0. Animated Background Glows
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withOpacity(0.05),
                  boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.1), blurRadius: 100, spreadRadius: 50)],
                ),
              ),
            ),
            // 1. Floating Icon (Background)
            AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) => Positioned(
                top: 100 + _floatingAnimation.value,
                left: 40,
                child: Opacity(opacity: 0.05, child: Icon(Icons.style, size: 120, color: Colors.white)),
              ),
            ),

            // 2. HEADER ACTIONS & STATS
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Challenges Button
                  GestureDetector(
                    onTap: () => showDialog(context: context, builder: (c) => const ChallengeDialog()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.military_tech, color: Colors.amber, size: 16),
                            SizedBox(width: 4),
                            Text("CHALLENGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                            if (ProgressionService().hasUnclaimedChallenges()) ...[
                               SizedBox(width: 6),
                               Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                               )
                            ]
                          ],
                        ),
                      ),
                  ),

                  Row(
                    children: [
                      // Coins Display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("🪙", style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              "${ProgressionService().getCoins()}",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Friends Button
                      FutureBuilder<List<Friend>>(
                        future: FriendService().getOnlineFriends(),
                        builder: (context, snapshot) {
                          final onlineCount = snapshot.data?.length ?? 0;
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => FriendsScreen()),
                              );
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                  Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Icon(Icons.people_outline, color: Colors.white, size: 20),
                                ),
                                if (onlineCount > 0)
                                  Positioned(
                                    right: -2,
                                    top: -2,
                                    child: Container(
                                      padding: EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Color(0xFF1E293B), width: 1.5),
                                      ),
                                      constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                                      child: Center(
                                        child: Text(
                                          '$onlineCount',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      // Tutorial Button
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => TutorialScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.help_outline, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Settings Button
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SettingsScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.settings, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 3. Main Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/Kadi.png',
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                      
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
                      
                      const SizedBox(height: 30),
                      
                      // QUICK MATCH (NEW PREMIUM BUTTON)
                      _buildQuickMatchButton(),
                      
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildModernMenuCard("SOLO", Icons.person, Colors.blueAccent, _showSinglePlayerDialog),
                          const SizedBox(width: 16),
                          _buildModernMenuCard("BATTLE", Icons.groups, Colors.deepPurpleAccent, _showMultiplayerDialog),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildModernMenuCard("LEVELS", Icons.emoji_events, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (c) => TournamentScreen(gameType: _selectedGameMode)))),
                          const SizedBox(width: 16),
                          _buildModernMenuCard("RANK", Icons.bar_chart, Colors.purpleAccent, () => Navigator.push(context, MaterialPageRoute(builder: (c) => LeaderboardScreen()))),
                        ],
                      ),
                      const SizedBox(height: 40),
                      
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

  Widget _buildQuickMatchButton() {
    return GestureDetector(
      onTap: _quickMatch,
      child: Container(
        width: 320,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.amber, Colors.orangeAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 20, offset: Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                right: -20, top: -20,
                child: Icon(Icons.flash_on, size: 100, color: Colors.white.withOpacity(0.2)),
              ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt, color: Colors.black, size: 32),
                    SizedBox(width: 12),
                    Text("QUICK MATCH", style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernMenuCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 152,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              splashColor: color.withOpacity(0.3),
              highlightColor: color.withOpacity(0.1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  SizedBox(height: 12),
                  Text(label, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkDailyChallenges() async {
      try {
         // Auto-show logic: If unviewed challenges exist, show dialog
         if (ProgressionService().hasUnclaimedChallenges()) {
             await Future.delayed(const Duration(seconds: 1)); // Small delay for UX
             if (mounted) {
                showDialog(
                   context: context, 
                   builder: (c) => const ChallengeDialog()
                ).then((_) {
                   // Mark as viewed when closed
                   ProgressionService().markDailyChallengesAsViewed().then((_) {
                      if(mounted) setState((){}); // Refresh to hide badge
                   });
                });
             }
         }
      } catch (e) {
         print("Error checking daily challenges: $e");
      }
  }

  Widget _buildIconButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Column(
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12),
          ),
          child: Material(
            color: Colors.transparent,
            shape: CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: CircleBorder(),
              splashColor: color.withOpacity(0.3),
              child: Center(
                child: Icon(icon, color: color, size: 30),
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildChallengesSection() {
    final challenges = ProgressionService().getChallenges();
    final timeUntilRefresh = ProgressionService().getTimeUntilRefresh();
    
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
      final success = await ProgressionService().claimChallengeReward(challengeId);
      if (success) {
        // Find challenge for reward amount (or pass it in)
        final challenge = ProgressionService().getChallenges().firstWhere((c) => c.id == challengeId);
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

  /// Show friend invite prompt after room creation
  Future<void> _showFriendInvitePrompt(String? roomCode, String? ipAddress) async {
    // 1. Ask User if they want to invite
    final bool? shouldInvite = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Color(0xFF00E5FF)),
            SizedBox(width: 12),
            Text('Invite Friends?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Want to invite your friends to this game?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            child: const Text('Invite'),
          ),
        ],
      ),
    );

    // 2. If Yes, Show Bottom Sheet and WAIT for it to close
    if (shouldInvite == true) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => FriendInviteBottomSheet(
          roomCode: roomCode,
          ipAddress: ipAddress,
          gameMode: _selectedGameMode,
        ),
      );
    }
    // 3. Return (then navigation happens)
  }

}