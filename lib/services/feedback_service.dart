import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'vps_game_service.dart';

class FeedbackService {
  static const String _offlineFeedbackKey = 'offline_feedback_reports';

  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  /// Submit feedback to the server. If offline, cache it locally.
  Future<bool> submitFeedback(String message, String type) async {
    final report = {
      'message': message,
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      final success = await VPSGameService().submitFeedback(report);
      if (success) {
        print("✅ Feedback submitted successfully to VPS");
        return true;
      }
    } catch (e) {
      print("⚠️ VPS Feedback submission failed, caching locally: $e");
    }

    // Cache locally if failed
    await _cacheFeedbackLocally(report);
    return false;
  }

  Future<void> _cacheFeedbackLocally(Map<String, dynamic> report) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> cached = prefs.getStringList(_offlineFeedbackKey) ?? [];
    cached.add(jsonEncode(report));
    await prefs.setStringList(_offlineFeedbackKey, cached);
  }

  /// Try to sync any locally cached feedback to the server
  Future<void> syncCachedFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> cached = prefs.getStringList(_offlineFeedbackKey) ?? [];
    if (cached.isEmpty) return;

    print("🔄 Syncing ${cached.length} cached feedback reports...");
    List<String> failedToSync = [];

    for (String reportStr in cached) {
      try {
        final report = jsonDecode(reportStr);
        final success = await VPSGameService().submitFeedback(report);
        if (!success) failedToSync.add(reportStr);
      } catch (e) {
        failedToSync.add(reportStr);
      }
    }

    await prefs.setStringList(_offlineFeedbackKey, failedToSync);
    if (failedToSync.isEmpty) {
      print("✅ All cached feedback synced successfully");
    } else {
      print("⚠️ Failed to sync ${failedToSync.length} reports. Retrying later.");
    }
  }
}
