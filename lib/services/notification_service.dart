import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_stat_ace', // Using custom icon from drawable
      [
        // Basic notifications (legacy)
        NotificationChannel(
          channelGroupKey: 'basic_group',
          channelKey: 'basic_channel',
          channelName: 'Basic Notifications',
          channelDescription: 'General game notifications',
          defaultColor: const Color(0xFF00E5FF),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
        ),
        
        // Social notifications (friends, invites)
        NotificationChannel(
          channelGroupKey: 'social_group',
          channelKey: 'social_channel',
          channelName: 'Social',
          channelDescription: 'Friend activity and game invites',
          defaultColor: const Color(0xFF00E5FF),
          ledColor: Colors.green,
          importance: NotificationImportance.High,
          playSound: true,
          enableVibration: true,
        ),
        
        // Event notifications (tournaments, challenges)
        NotificationChannel(
          channelGroupKey: 'events_group',
          channelKey: 'events_channel',
          channelName: 'Events',
          channelDescription: 'Tournament alerts and challenge reminders',
          defaultColor: const Color(0xFFFF6B35),
          ledColor: Colors.orange,
          importance: NotificationImportance.High,
          playSound: true,
        ),
        
        // Progress notifications (streaks, achievements)
        NotificationChannel(
          channelGroupKey: 'progress_group',
          channelKey: 'progress_channel',
          channelName: 'Progress',
          channelDescription: 'Streak reminders and achievements',
          defaultColor: const Color(0xFFFFD700),
          ledColor: Colors.amber,
          importance: NotificationImportance.Default,
        ),
      ],
      debug: true,
    );

    // Request permissions
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  Future<void> requestPermission() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  Future<void> scheduleDailyRewardReminder(TimeOfDay time) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1,
        channelKey: 'basic_channel',
        title: 'Daily Reward Ready! 🎁',
        body: 'Your daily coins are waiting for you. Come and claim them now!',
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        hour: time.hour,
        minute: time.minute,
        second: 0,
        millisecond: 0,
        repeats: true,
      ),
    );
  }

  Future<void> showGameVictoryNotification(int coins) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 2,
        channelKey: 'basic_channel',
        title: 'Victory! 🏆',
        body: 'You won the match and earned $coins coins!',
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  // ==========================================
  //    ENHANCED NOTIFICATIONS (Phase 3)
  // ==========================================

  /// Check if a specific notification type is enabled in user preferences
  Future<bool> _isNotificationEnabled(String prefKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? true; // Default: enabled
  }

  /// Friend Online Notification
  Future<void> showFriendOnlineNotification(String friendName, String friendId) async {
    if (!await _isNotificationEnabled('notif_pref_friend_activity')) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 10,
        channelKey: 'social_channel',
        title: '🟢 $friendName is online!',
        body: 'Tap to invite them to a game',
        notificationLayout: NotificationLayout.Default,
        payload: {
          'type': 'friend_online',
          'friendId': friendId,
          'friendName': friendName,
        },
      ),
    );
  }

  /// Game Invite Notification with action buttons
  Future<void> showGameInviteNotification(
    String friendName, 
    String roomCode, {
    String? ipAddress,  // Optional for LAN mode
  }) async {
    if (!await _isNotificationEnabled('notif_pref_game_invites')) return;

    final isLanMode = ipAddress != null && ipAddress.isNotEmpty;
    final body = isLanMode 
        ? 'Join via IP: $ipAddress' 
        : 'Room Code: $roomCode';

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 11,
        channelKey: 'social_channel',
        title: '🎮 Game Invite from $friendName',
        body: body,
        notificationLayout: NotificationLayout.Default,
        payload: {
          'type': 'game_invite',
          'roomCode': roomCode,
          'ipAddress': ipAddress ?? '',
          'friendName': friendName,
        },
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'JOIN',
          label: 'Join Game',
          actionType: ActionType.Default,
          autoDismissible: true,
        ),
        NotificationActionButton(
          key: 'DECLINE',
          label: 'Decline',
          actionType: ActionType.DismissAction,
          autoDismissible: true,
        ),
      ],
    );
  }

  /// Tournament Starting Alert
  Future<void> showTournamentAlert(String tournamentName, int minutesUntilStart) async {
    if (!await _isNotificationEnabled('notif_pref_tournaments')) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 12,
        channelKey: 'events_channel',
        title: '🏆 Tournament Starting Soon!',
        body: '$tournamentName starts in $minutesUntilStart minutes',
        notificationLayout: NotificationLayout.Default,
        payload: {
          'type': 'tournament',
          'name': tournamentName,
          'minutesUntilStart': minutesUntilStart.toString(),
        },
      ),
    );
  }

  /// Challenge Expiry Warning
  Future<void> showChallengeExpiryWarning(int hoursRemaining) async {
    if (!await _isNotificationEnabled('notif_pref_challenges')) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 13,
        channelKey: 'events_channel',
        title: '⏰ Challenge Expiring Soon!',
        body: '${hoursRemaining}h left to complete your daily challenges',
        notificationLayout: NotificationLayout.Default,
        payload: {
          'type': 'challenge_expiry',
          'hoursRemaining': hoursRemaining.toString(),
        },
      ),
    );
  }

  /// Streak Reminder Notification
  Future<void> showStreakReminderNotification(int currentStreak) async {
    if (!await _isNotificationEnabled('notif_pref_streaks')) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 14,
        channelKey: 'progress_channel',
        title: '🔥 Don\'t Break Your Streak!',
        body: 'You\'re on a $currentStreak-day streak. Play today!',
        notificationLayout: NotificationLayout.Default,
        payload: {
          'type': 'streak_reminder',
          'streak': currentStreak.toString(),
        },
      ),
    );
  }

  /// Schedule Daily Challenge Reminder (8 PM)
  Future<void> scheduleDailyChallengeReminder() async {
    if (!await _isNotificationEnabled('notif_pref_challenges')) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 15,
        channelKey: 'events_channel',
        title: '🎯 Daily Challenge Reset Soon!',
        body: 'Your daily challenges reset in 1 hour. Complete them now!',
        notificationLayout: NotificationLayout.Default,
        payload: {'type': 'challenge_reminder'},
      ),
      schedule: NotificationCalendar(
        hour: 20, // 8 PM
        minute: 0,
        second: 0,
        repeats: true,
      ),
    );
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllScheduledNotifications() async {
    await AwesomeNotifications().cancelAllSchedules();
  }

  /// Cancel specific notification by ID
  Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
  }
}
