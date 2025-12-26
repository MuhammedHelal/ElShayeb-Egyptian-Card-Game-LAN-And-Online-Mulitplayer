/// Core - Audio Manager
///
/// Centralized audio management for music and sound effects.
/// Supports muting, volume control, and proper resource management.
library;

import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';

/// Sound effect types
enum SoundEffect {
  deal,
  play,
  flip,
  match,
  win,
  lose,
}

/// Centralized audio manager singleton
class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  // Background music player
  final AudioPlayer _musicPlayer = AudioPlayer();

  // Sound effect players (pool for overlapping sounds)
  final List<AudioPlayer> _sfxPlayers = List.generate(5, (_) => AudioPlayer());
  int _currentSfxPlayer = 0;

  // State
  bool _isMusicEnabled = true;
  bool _isSfxEnabled = true;
  double _musicVolume = 0.5;
  double _sfxVolume = 0.8;
  bool _isInitialized = false;

  /// Initialize the audio manager
  Future<void> init() async {
    if (_isInitialized) return;

    // Configure music player for looping
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(_musicVolume);

    // Configure SFX players
    for (final player in _sfxPlayers) {
      await player.setReleaseMode(ReleaseMode.release);
      await player.setVolume(_sfxVolume);
    }

    _isInitialized = true;
  }

  /// Start background music
  Future<void> playBackgroundMusic() async {
    if (!_isMusicEnabled) return;

    try {
      await _musicPlayer.stop();
      await _musicPlayer.setSource(AssetSource('music/background.mp3'));
      await _musicPlayer.resume();
    } catch (e) {
      log('Error playing background music: $e');
    }
  }

  /// Stop background music
  Future<void> stopBackgroundMusic() async {
    await _musicPlayer.stop();
  }

  /// Pause background music
  Future<void> pauseBackgroundMusic() async {
    await _musicPlayer.pause();
  }

  /// Resume background music
  Future<void> resumeBackgroundMusic() async {
    if (!_isMusicEnabled) return;
    await _musicPlayer.resume();
  }

  /// Play a sound effect
  Future<void> playSoundEffect(SoundEffect effect) async {
    if (!_isSfxEnabled) return;

    final assetPath = _getSoundAssetPath(effect);
    if (assetPath == null) return;

    try {
      final player = _sfxPlayers[_currentSfxPlayer];
      _currentSfxPlayer = (_currentSfxPlayer + 1) % _sfxPlayers.length;

      await player.stop();
      await player.setSource(AssetSource(assetPath));
      await player.resume();
    } catch (e) {
      log('Error playing sound effect: $e');
    }
  }

  /// Get asset path for sound effect
  String? _getSoundAssetPath(SoundEffect effect) {
    switch (effect) {
      case SoundEffect.deal:
        return 'sounds/deal.mp3';
      case SoundEffect.play:
        return 'sounds/play.mp3';
      case SoundEffect.flip:
        return 'sounds/deal.mp3'; // Use deal sound as flip
      case SoundEffect.match:
        return 'sounds/play.mp3'; // Use play sound as match
      case SoundEffect.win:
        return 'sounds/play.mp3'; // Use play sound as win
      case SoundEffect.lose:
        return 'sounds/deal.mp3'; // Use deal sound as lose
    }
  }

  /// Enable/disable music
  Future<void> setMusicEnabled(bool enabled) async {
    _isMusicEnabled = enabled;

    if (enabled) {
      await resumeBackgroundMusic();
    } else {
      await pauseBackgroundMusic();
    }
  }

  /// Enable/disable sound effects
  void setSfxEnabled(bool enabled) {
    _isSfxEnabled = enabled;
  }

  /// Set music volume (0.0 to 1.0)
  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume.clamp(0.0, 1.0);
    await _musicPlayer.setVolume(_musicVolume);
  }

  /// Set SFX volume (0.0 to 1.0)
  Future<void> setSfxVolume(double volume) async {
    _sfxVolume = volume.clamp(0.0, 1.0);
    for (final player in _sfxPlayers) {
      await player.setVolume(_sfxVolume);
    }
  }

  /// Getters for current state
  bool get isMusicEnabled => _isMusicEnabled;
  bool get isSfxEnabled => _isSfxEnabled;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  /// Dispose all resources
  Future<void> dispose() async {
    await _musicPlayer.dispose();
    for (final player in _sfxPlayers) {
      await player.dispose();
    }
  }
}
