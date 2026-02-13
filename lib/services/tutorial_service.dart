import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static final TutorialService _instance = TutorialService._internal();
  factory TutorialService() => _instance;
  TutorialService._internal();

  static const String _tutorialCompleteKey = 'tutorial_completed';
  static const String _tutorialStepKey = 'tutorial_current_step';

  /// Check if user has completed the tutorial
  Future<bool> hasCompletedTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tutorialCompleteKey) ?? false;
  }

  /// Determine if tutorial should be shown
  Future<bool> shouldShowTutorial() async {
    return !(await hasCompletedTutorial());
  }

  /// Mark tutorial as complete
  Future<void> markTutorialComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialCompleteKey, true);
    await prefs.setInt(_tutorialStepKey, 5); // All steps complete
  }

  /// Get current tutorial step (0-5)
  Future<int> getCurrentStep() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_tutorialStepKey) ?? 0;
  }

  /// Update current tutorial step
  Future<void> setCurrentStep(int step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_tutorialStepKey, step);
  }

  /// Reset tutorial (for testing or "Watch Again" feature)
  Future<void> resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialCompleteKey, false);
    await prefs.setInt(_tutorialStepKey, 0);
  }
}
