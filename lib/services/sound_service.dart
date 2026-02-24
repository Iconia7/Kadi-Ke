import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final AudioPlayer _sfxPlayer = AudioPlayer();
  static final AudioPlayer _bgmPlayer = AudioPlayer();
  static bool _isMuted = false; 

  static bool get isMuted => _isMuted;

  static void toggleMute(bool mute) {
    _isMuted = mute;
    if (_isMuted) {
      _sfxPlayer.stop();
      _bgmPlayer.stop();
    }
  }

  static Future<void> play(String soundName) async {
    if (_isMuted) return;

    try {
      await _sfxPlayer.stop(); 
      String actualFile = soundName;
      if (soundName == 'throw') actualFile = 'place';
      if (soundName == 'error') actualFile = 'deal';
      if (soundName == 'pop') actualFile = 'deal';

      await _sfxPlayer.play(AssetSource('audio/$actualFile.mp3'));
    } catch (e) {
      print("Audio Error (SFX): $e");
    }
  }

  static Future<void> playBGM(String musicName) async {
    if (_isMuted) return;

    try {
      // Loop BGM
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource('audio/bgm/$musicName.mp3'), volume: 0.5);
    } catch (e) {
      print("Audio Error (BGM): $e");
    }
  }

  static Future<void> stopBGM() async {
    await _bgmPlayer.stop();
  }
}