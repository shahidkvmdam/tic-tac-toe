import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _player = AudioPlayer();
  bool _enabled = true;
  bool get enabled => _enabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('sound_enabled') ?? true;
    await _player.setVolume(0.8);
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', value);
  }

  Future<void> playTap() => _play('sounds/tap.mp3');
  Future<void> playWin() => _play('sounds/win.mp3');
  Future<void> playLose() => _play('sounds/lose.mp3');
  Future<void> playDraw() => _play('sounds/draw.mp3');
  Future<void> playMessage() => _play('sounds/tap.mp3');

  Future<void> _play(String asset) async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {}
  }

  void dispose() => _player.dispose();
}
