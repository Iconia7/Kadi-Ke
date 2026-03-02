import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'screens/splash_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/home_screen.dart';
import 'services/custom_auth_service.dart';
import 'services/notification_service.dart';
import 'services/progression_service.dart';
import 'services/feedback_service.dart';
import 'screens/game_screen.dart';
import 'screens/tournament_screen.dart';
import 'services/iap_service.dart';
import 'services/ad_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    debugPrint("✅ Firebase Initialized");
  } catch (e) {
    debugPrint("❌ Firebase Init Error: $e");
  }

  // 1. Lock Orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 2. Initialize Custom Auth Service
  try {
    await CustomAuthService().initialize();
    await CustomAuthService().fetchCloudWallet(); // Background sync of coins/wins
    debugPrint("✅ Auth Service Initialized & Wallet Synced");
  } catch (e) {
    debugPrint("❌ Auth Init Error: $e");
  }

  // 3. Initialize Notifications
  try {
    await NotificationService().initialize();
    await NotificationService().scheduleDailyRewardReminder(const TimeOfDay(hour: 10, minute: 0));
    await NotificationService().scheduleDailyChallengeReminder(); // Schedule at 8 PM
    debugPrint("✅ Notifications Initialized");
  } catch (e) {
    debugPrint("❌ Notification Error: $e");
  }

  // 4. Initialize Progression & Challenges
  try {
    await ProgressionService().initialize();
    await ProgressionService().checkAndResetChallenges();
    debugPrint("✅ Progression & Challenges Initialized");
  } catch (e) {
    debugPrint("❌ Progression Error: $e");
  }

  // 5. Sync Feedback
  try {
    FeedbackService().syncCachedFeedback();
  } catch (e) {
    debugPrint("❌ Feedback Sync Error: $e");
  }

  // 6. Initialize IAP (In-App Purchases)
  try {
    await IAPService().initialize();
    debugPrint("✅ IAP Service Initialized");
  } catch (e) {
    debugPrint("❌ IAP Init Error: $e");
  }

  // 7. Initialize Ads
  try {
    await AdService.initialize();
    debugPrint("✅ Ad Service Initialized");
  } catch (e) {
    debugPrint("❌ Ad Init Error: $e");
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

    // 1. Handle Custom Action Buttons first
    final buttonKey = action.buttonKeyPressed;
    if (buttonKey.isNotEmpty) {
       print("🔘 FCM Action Button Tapped: $buttonKey");
       
       if (buttonKey == 'DECLINE' || buttonKey == 'DISMISS') {
         // Awesome Notifications autoDismissible handles removing the push UI
         return; 
       }
       
       if (buttonKey == 'OPEN_LEADERBOARD') {
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (_) => HomeScreen()),
             (route) => false,
           );
           return;
       }
       
       if (buttonKey == 'OPEN_CLAN_HUB') {
           // We route to home first, and let the user open the clan tab manually, or if you have a deep link router, use it.
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (_) => HomeScreen()),
             (route) => false,
           );
           return;
       }
    }

    // 2. Handle standard payloads
    switch (type) {
      case 'game_invite':
        // Navigate to home and show join dialog
        final roomCode = payload['roomCode'];
        final friendName = payload['friendName'];
        final gameType = payload['gameType'] ?? 'kadi';
        print("📬 Game invite from $friendName: $roomCode ($gameType)");
        
        // Navigate to home screen
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen()),
          (route) => false,
        );
        
        // Show join game dialog
        await Future.delayed(const Duration(milliseconds: 500));
        if (context.mounted) {
          _showJoinGameDialog(context, roomCode, friendName, gameType);
        }
        break;
        
      case 'tournament_invite':
        final tRoomCode = payload['roomCode'];
        final tFriendName = payload['friendName'];
        final tGameType = payload['gameType'] ?? 'kadi';
        debugPrint("📬 Tournament invite from $tFriendName: $tRoomCode ($tGameType)");
        
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen()),
          (route) => false,
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
        if (context.mounted) {
           _showJoinTournamentDialog(context, tRoomCode, tFriendName, tGameType);
        }
        break;
        
      case 'friend_online':
        // Navigate to friends screen
        final friendName = payload['friendName'];
        debugPrint("👥 Navigating to friends (friend online: $friendName)");
        
        // Navigate directly to Friends Screen
        if (!context.mounted) return;
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

  static void _showJoinTournamentDialog(BuildContext context, String? roomCode, String? friendName, [String gameType = 'kadi']) {
    if (roomCode == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          friendName != null ? 'Tournament Invite from $friendName' : 'Tournament Invite',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Tournament ID: $roomCode\nGame Mode: ${gameType.toUpperCase()}\n\nEnter the Tournament Lobby?',
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
              print("Auto-join: Navigating to TOURNAMENT lobby $roomCode");
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => TournamentScreen(
                    isHost: false,
                    tournamentId: roomCode,
                    gameType: gameType, 
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Enter Lobby'),
          ),
        ],
      ),
    );
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
              if (gameType.toLowerCase() == 'tournament') {
                 print("Auto-join: Navigating to TOURNAMENT lobby $roomCode");
                 Navigator.of(context).push(
                   MaterialPageRoute(
                     builder: (context) => TournamentScreen(
                       isHost: false,
                       tournamentId: roomCode,
                       gameType: 'kadi', // tournaments default to kadi for now
                     ),
                   ),
                 );
              } else {
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
              }
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
      title: 'Kadi KE',
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