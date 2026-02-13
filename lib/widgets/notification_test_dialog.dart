import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// Notification Testing Utility
/// Add this to your settings screen for testing notifications
class NotificationTestDialog extends StatelessWidget {
  const NotificationTestDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Test Notifications',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Friend Online Test
            _buildTestButton(
              context,
              '🟢 Friend Online',
              () async {
                await NotificationService().showFriendOnlineNotification(
                  'TestFriend',
                  'test123',
                );
                Navigator.pop(context);
              },
            ),
            
            // Game Invite Test
            _buildTestButton(
              context,
              '🎮 Game Invite',
              () async {
                await NotificationService().showGameInviteNotification(
                  'PlayerOne',
                  'TEST123',
                );
                Navigator.pop(context);
              },
            ),
            
            // Tournament Alert Test
            _buildTestButton(
              context,
              '🏆 Tournament Alert',
              () async {
                await NotificationService().showTournamentAlert(
                  'Weekend Championship',
                  10,
                );
                Navigator.pop(context);
              },
            ),
            
            // Challenge Expiry Test
            _buildTestButton(
              context,
              '⏰ Challenge Expiry',
              () async {
                await NotificationService().showChallengeExpiryWarning(3);
                Navigator.pop(context);
              },
            ),
            
            // Streak Reminder Test
            _buildTestButton(
              context,
              '🔥 Streak Reminder',
              () async {
                await NotificationService().showStreakReminderNotification(7);
                Navigator.pop(context);
              },
            ),
            
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(BuildContext context, String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
