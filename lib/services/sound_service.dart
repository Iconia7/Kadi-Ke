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
      
      // Remap missing sounds to existing ones
      String actualFile = soundName;
      if (soundName == 'throw') actualFile = 'place';
      if (soundName == 'error') actualFile = 'deal';
      if (soundName == 'pop') actualFile = 'deal';

      await _player.play(AssetSource('audio/$actualFile.mp3'));
    } catch (e) {
      print("Audio Error: $e");
    }
  }
}