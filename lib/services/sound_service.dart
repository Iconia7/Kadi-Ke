import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _isMuted = false; // New: Mute state

  static bool get isMuted => _isMuted;

  static void toggleMute() {
    _isMuted = !_isMuted;
  }

  static Future<void> play(String soundName) async {
    if (_isMuted) return; // Don't play if muted
    
    // Stop previous sound to keep it snappy
    await _player.stop(); 
    await _player.play(AssetSource('audio/$soundName.mp3'));
  }
}