/// Domain Layer - Online Game Events
///
/// Backend-agnostic event models for multiplayer interactions.
library;

/// Base class for all online game events
abstract class OnlineGameEvent {
  final String type;
  final Map<String, dynamic> data;
  final String? senderId;
  final DateTime timestamp;

  const OnlineGameEvent({
    required this.type,
    required this.data,
    this.senderId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
      'senderId': senderId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory OnlineGameEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final senderId = json['senderId'] as String?;
    final timestampStr = json['timestamp'] as String?;
    final timestamp =
        timestampStr != null ? DateTime.parse(timestampStr) : DateTime.now();

    return GenericGameEvent(
      type: type,
      data: data,
      senderId: senderId,
      timestamp: timestamp,
    );
  }
}

/// Generic implementation for events
class GenericGameEvent extends OnlineGameEvent {
  const GenericGameEvent({
    required super.type,
    required super.data,
    super.senderId,
    required super.timestamp,
  });
}

/// Predefined event types
class OnlineEventTypes {
  static const String playerJoined = 'player_joined';
  static const String playerLeft = 'player_left';
  static const String stateSync = 'state_sync';
  static const String gameAction = 'game_action'; // e.g. draw, shuffle
  static const String systemMessage = 'system_message';
  static const String error = 'error';
}
