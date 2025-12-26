/// Domain Layer - Game Event Entity
///
/// Represents a discrete event in the game for logging, UI feedback, and animation.
library;

/// Game events that can occur
enum GameEventType {
  playerJoined,
  playerLeft,
  gameStarted,
  cardDealt,
  cardDrawn,

  /// Card stolen event - for animation on non-active players
  cardStolen,
  pairRemoved,
  playerFinished,
  roundEnded,
  gameEnded,
  turnChanged,
  stateSync,
  error,
}

/// A game event for logging and UI feedback
class GameEvent {
  final GameEventType type;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  GameEvent({
    required this.type,
    required this.message,
    this.data,
  }) : timestamp = DateTime.now();

  /// Create from JSON (for network transmission)
  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      type: GameEventType.values[json['eventType'] as int],
      message: json['message'] as String,
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}

/// Callback type for game events
typedef GameEventCallback = void Function(GameEvent event);
