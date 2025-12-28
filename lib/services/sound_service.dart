import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _isMuted = false; // Mute state

  static bool get isMuted => _isMuted;

  // New method to toggle mute
  static void toggleMute(bool mute) {
    _isMuted = mute;
    if (_isMuted) {
      _player.stop();
    }
  }

  static Future<void> play(String soundName) async {
    if (_isMuted) return; // Stop if muted

    try {
      await _player.stop(); // Stop previous for snappy feel
      // Make sure your assets path is correct (usually 'sounds/' or just name if defined in pubspec)
      await _player.play(AssetSource('sounds/$soundName.mp3'));
    } catch (e) {
      print("Audio Error: $e");
    }
  }
}