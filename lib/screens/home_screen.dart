import 'dart:async'; // Required for StreamSubscription
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:ui';
import 'game_screen.dart'; 
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'profile_screen.dart';
import '../services/firebase_game_service.dart'; // Keep for Auth/Profile
import '../services/online_game_service.dart';   // ADD THIS for Game Logic

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
    _initFirebase();
    
    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    _floatingAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );
  }

Future<void> _initFirebase() async {
  try {
    await FirebaseGameService().initialize();
    if (mounted) {
      setState(() {
        _isFirebaseReady = true;
      });
    }
  } catch (e) {
    print("Firebase init error in HomeScreen: $e");
    // Still set to true after a delay to show UI, or show error message
    if (mounted) {
      setState(() {
        _isFirebaseReady = true; // Allow UI to show even if Firebase failed
      });
    }
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
    
    // 1. Show Loading Spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Center(child: CircularProgressIndicator(color: Colors.amber)),
    );

    // 2. Listen for Server Response
    StreamSubscription? subscription;
    bool hasNavigated = false; // Flag to ensure we don't act twice

    subscription = OnlineGameService().gameStream.listen((data) {
      if (data['type'] == 'ROOM_CREATED') {
        hasNavigated = true;
        
        // 3. Server replied! Get the code
        String roomCode = data['data'];
        subscription?.cancel(); // Stop listening
        
        if (mounted) {
          Navigator.pop(context); // Close spinner

          // 4. Navigate to Game Screen
          Navigator.push(context, MaterialPageRoute(builder: (context) => 
            GameScreen(
              isHost: true, 
              hostAddress: 'online', 
              onlineGameCode: roomCode,
              gameType: _selectedGameMode, 
            )
          ));
        }
      }
    });

    // ✅ ADD THIS: Safety Timeout (15 Seconds)
    // If the server doesn't reply in 15s, stop spinning.
    Future.delayed(Duration(seconds: 15), () {
      if (!hasNavigated && mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close spinner
        subscription?.cancel(); // Stop listening
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Server is waking up... Please press Create again!"),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          )
        );
      }
    });

    // 5. Send Request (Now calls the async version from step 1)
    OnlineGameService().createGame("Player", _selectedGameMode); 
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
                      SizedBox(height: 60),
                      
                      // Bottom Row (Fixed: Removed the Positioned widget from here)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildIconButton("Shop", Icons.shopping_bag_outlined, Colors.amber, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopScreen()))),
                          SizedBox(width: 40),
                          _buildIconButton("Profile", Icons.bar_chart_rounded, Colors.greenAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen()))),
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
}