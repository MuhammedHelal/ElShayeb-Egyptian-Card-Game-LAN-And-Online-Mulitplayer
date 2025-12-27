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

  /// Fallback/legacy message (English) - used for network transmission
  final String message;

  /// Localization key for the message (e.g., 'event_player_joined')
  final String? messageKey;

  /// Parameters for message interpolation (e.g., {'name': 'Player1'})
  final Map<String, String>? messageParams;

  final Map<String, dynamic>? data;
  final DateTime timestamp;

  GameEvent({
    required this.type,
    required this.message,
    this.messageKey,
    this.messageParams,
    this.data,
  }) : timestamp = DateTime.now();

  /// Create from JSON (for network transmission)
  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      type: GameEventType.values[json['eventType'] as int],
      message: json['message'] as String,
      messageKey: json['messageKey'] as String?,
      messageParams: json['messageParams'] != null
          ? Map<String, String>.from(json['messageParams'] as Map)
          : null,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON for network transmission
  Map<String, dynamic> toJson() {
    return {
      'eventType': type.index,
      'message': message,
      if (messageKey != null) 'messageKey': messageKey,
      if (messageParams != null) 'messageParams': messageParams,
      if (data != null) 'data': data,
    };
  }
}

/// Callback type for game events
typedef GameEventCallback = void Function(GameEvent event);
