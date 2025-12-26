/// Core - Constants and Endpoints
library;

class Endpoints {
  /// WebSocket server URL for online multiplayer
  /// Replace with your actual server URL in production
  static const gameSocket = 'wss://elshayeb-server.example.com/ws';

  /// Heartbeat interval in seconds
  static const heartbeatIntervalSeconds = 10;

  /// Connection timeout in seconds
  static const connectionTimeoutSeconds = 15;

  /// Maximum reconnection attempts
  static const maxReconnectAttempts = 5;
}

/// Asset paths
class AssetPaths {
  // Cards
  static const cardsDir = 'assets/cards/';
  static const cardBack = 'assets/cards/back.svg';

  // Sounds
  static const soundsDir = 'assets/sounds/';
  static const dealSound = 'assets/sounds/deal.mp3';
  static const playSound = 'assets/sounds/play.mp3';
  static const flipSound = 'assets/sounds/flip.mp3';
  static const matchSound = 'assets/sounds/match.mp3';
  static const winSound = 'assets/sounds/win.mp3';
  static const loseSound = 'assets/sounds/lose.mp3';

  // Music
  static const musicDir = 'assets/music/';
  static const backgroundMusic = 'assets/music/background.mp3';
}

/// App constants
class AppConstants {
  static const appName = 'El-Shayeb';
  static const maxPlayers = 6;
  static const minPlayers = 2;
  static const roomCodeLength = 4;

  // Animation durations in milliseconds
  static const dealAnimationDuration = 300;
  static const flipAnimationDuration = 400;
  static const cardMoveAnimationDuration = 500;
  static const matchAnimationDuration = 600;
}

/// Scoring constants
class ScoringConstants {
  static const firstPlace = 100;
  static const secondPlace = 60;
  static const thirdPlace = 40;
  static const fourthPlace = 20;
  static const fifthPlace = 10;
  static const shayebPenalty = -50;
}
