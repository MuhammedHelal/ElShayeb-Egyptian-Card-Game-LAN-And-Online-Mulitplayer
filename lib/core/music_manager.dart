
import 'package:audioplayers/audioplayers.dart';

class MusicManager {
  static final MusicManager _i = MusicManager._();
  factory MusicManager() => _i;
  MusicManager._();

  final _player = AudioPlayer();

  Future<void> setMuted(bool muted) async {
    await _player.setVolume(muted ? 0 : 0.6);
  }
}
