import 'package:shared_preferences/shared_preferences.dart';

class SavedOnlineSession {
  final String roomCode;
  final String playerName;
  final String avatarId;

  const SavedOnlineSession({
    required this.roomCode,
    required this.playerName,
    required this.avatarId,
  });
}

abstract class OnlineSessionLocalDataSource {
  SavedOnlineSession? read();

  Future<void> save(SavedOnlineSession session);

  Future<void> clear();
}

class SharedPreferencesOnlineSessionLocalDataSource
    implements OnlineSessionLocalDataSource {
  static const _roomCodeKey = 'online_session.room_code';
  static const _playerNameKey = 'online_session.player_name';
  static const _avatarIdKey = 'online_session.avatar_id';

  final SharedPreferences _preferences;

  const SharedPreferencesOnlineSessionLocalDataSource(this._preferences);

  @override
  SavedOnlineSession? read() {
    final roomCode = _preferences.getString(_roomCodeKey);
    final playerName = _preferences.getString(_playerNameKey);
    final avatarId = _preferences.getString(_avatarIdKey);
    if (roomCode == null || playerName == null || avatarId == null) return null;
    return SavedOnlineSession(
      roomCode: roomCode,
      playerName: playerName,
      avatarId: avatarId,
    );
  }

  @override
  Future<void> save(SavedOnlineSession session) async {
    await Future.wait([
      _preferences.setString(_roomCodeKey, session.roomCode),
      _preferences.setString(_playerNameKey, session.playerName),
      _preferences.setString(_avatarIdKey, session.avatarId),
    ]);
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _preferences.remove(_roomCodeKey),
      _preferences.remove(_playerNameKey),
      _preferences.remove(_avatarIdKey),
    ]);
  }
}
