/// Core - Settings Repository
///
/// Persists app settings using SharedPreferences.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Keys for SharedPreferences
class _SettingsKeys {
  static const musicEnabled = 'music_enabled';
  static const sfxEnabled = 'sfx_enabled';
  static const vibrationEnabled = 'vibration_enabled';
  static const musicVolume = 'music_volume';
  static const sfxVolume = 'sfx_volume';
  static const playerName = 'player_name';
  static const avatarId = 'avatar_id';
  static const localeCode = 'locale_code';
}

/// Repository for app settings persistence
class SettingsRepository {
  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  // ============ Music ============

  bool get isMusicEnabled => _prefs.getBool(_SettingsKeys.musicEnabled) ?? true;

  Future<void> setMusicEnabled(bool enabled) async {
    await _prefs.setBool(_SettingsKeys.musicEnabled, enabled);
  }

  double get musicVolume => _prefs.getDouble(_SettingsKeys.musicVolume) ?? 0.5;

  Future<void> setMusicVolume(double volume) async {
    await _prefs.setDouble(_SettingsKeys.musicVolume, volume);
  }

  // ============ Sound Effects ============

  bool get isSfxEnabled => _prefs.getBool(_SettingsKeys.sfxEnabled) ?? true;

  Future<void> setSfxEnabled(bool enabled) async {
    await _prefs.setBool(_SettingsKeys.sfxEnabled, enabled);
  }

  double get sfxVolume => _prefs.getDouble(_SettingsKeys.sfxVolume) ?? 0.8;

  Future<void> setSfxVolume(double volume) async {
    await _prefs.setDouble(_SettingsKeys.sfxVolume, volume);
  }

  // ============ Vibration ============

  bool get isVibrationEnabled =>
      _prefs.getBool(_SettingsKeys.vibrationEnabled) ?? true;

  Future<void> setVibrationEnabled(bool enabled) async {
    await _prefs.setBool(_SettingsKeys.vibrationEnabled, enabled);
  }

  // ============ Player Profile ============

  String get playerName =>
      _prefs.getString(_SettingsKeys.playerName) ?? 'Player';

  Future<void> setPlayerName(String name) async {
    await _prefs.setString(_SettingsKeys.playerName, name);
  }

  String get avatarId => _prefs.getString(_SettingsKeys.avatarId) ?? 'avatar_1';

  Future<void> setAvatarId(String id) async {
    await _prefs.setString(_SettingsKeys.avatarId, id);
  }

  // ============ Locale ============

  /// Returns saved locale code, null if not set (use device default)
  String? get localeCode => _prefs.getString(_SettingsKeys.localeCode);

  Future<void> setLocaleCode(String? code) async {
    if (code == null) {
      await _prefs.remove(_SettingsKeys.localeCode);
    } else {
      await _prefs.setString(_SettingsKeys.localeCode, code);
    }
  }
}
