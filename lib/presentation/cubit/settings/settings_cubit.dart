/// Presentation Layer - Settings Cubit
///
/// Manages application settings state.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/core.dart';

/// Settings state
class SettingsState extends Equatable {
  final bool isMusicEnabled;
  final bool isSfxEnabled;
  final bool isVibrationEnabled;
  final double musicVolume;
  final double sfxVolume;
  final String playerName;
  final String avatarId;
  final String? localeCode; // null = use device default

  const SettingsState({
    this.isMusicEnabled = true,
    this.isSfxEnabled = true,
    this.isVibrationEnabled = true,
    this.musicVolume = 0.5,
    this.sfxVolume = 0.8,
    this.playerName = 'Player',
    this.avatarId = 'avatar_1',
    this.localeCode,
  });

  SettingsState copyWith({
    bool? isMusicEnabled,
    bool? isSfxEnabled,
    bool? isVibrationEnabled,
    double? musicVolume,
    double? sfxVolume,
    String? playerName,
    String? avatarId,
    String? localeCode,
    bool clearLocaleCode = false,
  }) {
    return SettingsState(
      isMusicEnabled: isMusicEnabled ?? this.isMusicEnabled,
      isSfxEnabled: isSfxEnabled ?? this.isSfxEnabled,
      isVibrationEnabled: isVibrationEnabled ?? this.isVibrationEnabled,
      musicVolume: musicVolume ?? this.musicVolume,
      sfxVolume: sfxVolume ?? this.sfxVolume,
      playerName: playerName ?? this.playerName,
      avatarId: avatarId ?? this.avatarId,
      localeCode: clearLocaleCode ? null : (localeCode ?? this.localeCode),
    );
  }

  @override
  List<Object?> get props => [
        isMusicEnabled,
        isSfxEnabled,
        isVibrationEnabled,
        musicVolume,
        sfxVolume,
        playerName,
        avatarId,
        localeCode,
      ];
}

/// Settings Cubit
class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository _repository;
  final AudioManager _audioManager;
  final HapticManager _hapticManager;

  SettingsCubit({
    required SettingsRepository repository,
    required AudioManager audioManager,
    required HapticManager hapticManager,
  })  : _repository = repository,
        _audioManager = audioManager,
        _hapticManager = hapticManager,
        super(const SettingsState());

  /// Load settings from storage
  Future<void> loadSettings() async {
    emit(SettingsState(
      isMusicEnabled: _repository.isMusicEnabled,
      isSfxEnabled: _repository.isSfxEnabled,
      isVibrationEnabled: _repository.isVibrationEnabled,
      musicVolume: _repository.musicVolume,
      sfxVolume: _repository.sfxVolume,
      playerName: _repository.playerName,
      avatarId: _repository.avatarId,
      localeCode: _repository.localeCode,
    ));

    // Apply to managers
    await _audioManager.setMusicEnabled(_repository.isMusicEnabled);
    _audioManager.setSfxEnabled(_repository.isSfxEnabled);
    await _audioManager.setMusicVolume(_repository.musicVolume);
    await _audioManager.setSfxVolume(_repository.sfxVolume);
    _hapticManager.setEnabled(_repository.isVibrationEnabled);
  }

  /// Toggle music
  Future<void> toggleMusic() async {
    final newValue = !state.isMusicEnabled;
    await _repository.setMusicEnabled(newValue);
    await _audioManager.setMusicEnabled(newValue);
    emit(state.copyWith(isMusicEnabled: newValue));
  }

  /// Toggle sound effects
  Future<void> toggleSfx() async {
    final newValue = !state.isSfxEnabled;
    await _repository.setSfxEnabled(newValue);
    _audioManager.setSfxEnabled(newValue);
    emit(state.copyWith(isSfxEnabled: newValue));
  }

  /// Toggle vibration
  Future<void> toggleVibration() async {
    final newValue = !state.isVibrationEnabled;
    await _repository.setVibrationEnabled(newValue);
    _hapticManager.setEnabled(newValue);
    emit(state.copyWith(isVibrationEnabled: newValue));
  }

  /// Set music volume
  Future<void> setMusicVolume(double volume) async {
    await _repository.setMusicVolume(volume);
    await _audioManager.setMusicVolume(volume);
    emit(state.copyWith(musicVolume: volume));
  }

  /// Set SFX volume
  Future<void> setSfxVolume(double volume) async {
    await _repository.setSfxVolume(volume);
    await _audioManager.setSfxVolume(volume);
    emit(state.copyWith(sfxVolume: volume));
  }

  /// Set player name
  Future<void> setPlayerName(String name) async {
    await _repository.setPlayerName(name);
    emit(state.copyWith(playerName: name));
  }

  /// Set avatar
  Future<void> setAvatarId(String id) async {
    await _repository.setAvatarId(id);
    emit(state.copyWith(avatarId: id));
  }

  /// Set locale code (null to use device default)
  Future<void> setLocaleCode(String? code) async {
    await _repository.setLocaleCode(code);
    if (code == null) {
      emit(state.copyWith(clearLocaleCode: true));
    } else {
      emit(state.copyWith(localeCode: code));
    }
  }
}
