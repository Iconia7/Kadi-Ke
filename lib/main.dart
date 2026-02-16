import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'screens/splash_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/home_screen.dart';
import 'services/custom_auth_service.dart';
import 'services/notification_service.dart';
import 'services/progression_service.dart';
import 'services/vps_game_service.dart';
import 'screens/game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Lock Orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 2. Initialize Custom Auth Service
  try {
    await CustomAuthService().initialize();
    print("✅ Auth Service Initialized");
  } catch (e) {
    print("❌ Auth Init Error: $e");
  }

  // 3. Initialize Notifications
  try {
    await NotificationService().initialize();
    await NotificationService().scheduleDailyRewardReminder(const TimeOfDay(hour: 10, minute: 0));
    await NotificationService().scheduleDailyChallengeReminder(); // Schedule at 8 PM
    print("✅ Notifications Initialized");
  } catch (e) {
    print("❌ Notification Error: $e");
  }

  // 4. Initialize Progression & Challenges
  try {
    await ProgressionService().initialize();
    await ProgressionService().checkAndResetChallenges();
    print("✅ Progression & Challenges Initialized");
  } catch (e) {
    print("❌ Progression Error: $e");
  }

  runApp(const MyApp());
}

// Global navigator key for notification navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupNotificationListeners();
  }

  void _setupNotificationListeners() {
    // Listen for notification taps
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onNotificationTap,
    );
  }

  @pragma("vm:entry-point")
  static Future<void> _onNotificationTap(ReceivedAction action) async {
    final payload = action.payload;
    if (payload == null) return;

    // Navigate based on notification type
    final String? type = payload['type'];
    
    // Small delay to ensure app is ready
    await Future.delayed(const Duration(milliseconds: 300));

    // Get navigator context
    final context = navigatorKey.currentContext;
    if (context == null) {
      print("⚠️ Navigator context not available");
      return;
    }

    switch (type) {
      case 'game_invite':
        // Navigate to home and show join dialog
        final roomCode = payload['roomCode'];
        final friendName = payload['friendName'];
        final gameType = payload['gameType'] ?? 'kadi';
        print("📬 Game invite from $friendName: $roomCode ($gameType)");
        
        // Navigate to home screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen()),
          (route) => false,
        );
        
        // Show join game dialog
        await Future.delayed(const Duration(milliseconds: 500));
        _showJoinGameDialog(context, roomCode, friendName, gameType);
        break;
        
      case 'friend_online':
        // Navigate to friends screen
        final friendName = payload['friendName'];
        print("👥 Navigating to friends (friend online: $friendName)");
        
        // Navigate directly to Friends Screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const FriendsScreen()),
          (route) => false,
        );
        break;
        
      case 'tournament':
        // Navigate to home (tournaments not yet implemented)
        print("🏆 Tournament notification tapped - navigating to home");
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen()),
          (route) => false,
        );
        break;
        
      case 'challenge_expiry':
      case 'challenge_reminder':
        // Navigate to home screen (challenges tab)
        print("🎯 Challenge notification tapped - navigating to home");
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen()),
          (route) => false,
        );
        break;
        
      case 'streak_reminder':
        // Navigate to home/profile
        print("🔥 Streak reminder tapped - navigating to home");
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen()),
          (route) => false,
        );
        break;
    }
  }

  static void _showJoinGameDialog(BuildContext context, String? roomCode, String? friendName, [String gameType = 'kadi']) {
    if (roomCode == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          friendName != null ? 'Game Invite from $friendName' : 'Game Invite',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Room Code: $roomCode\nGame Mode: ${gameType.toUpperCase()}\n\nJoin this game?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Auto-join: Navigating to $gameType lobby $roomCode
              print("Auto-join: Navigating to $gameType lobby $roomCode");
              
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => GameScreen(
                    isHost: false,
                    hostAddress: 'online',
                    onlineGameCode: roomCode,
                    gameType: gameType,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            child: const Text('Join Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Connect global navigator key
      title: 'Kadi Ke',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark, 
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
          primary: Colors.amber,
          secondary: Colors.deepPurpleAccent,
          surface: const Color(0xFF0F172A),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E293B),
          elevation: 4,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}