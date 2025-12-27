/// Data Layer - Network Messages
///
/// Defines the protocol for network communication between host and clients.
library;

import 'dart:convert';
import '../../domain/entities/entities.dart';

/// Message types for the network protocol
enum MessageType {
  /// Host broadcasts full game state
  stateSync,

  /// Client sends an action (draw card)
  playerAction,

  /// Client requests to join
  joinRequest,

  /// Host confirms join
  joinConfirm,

  /// Host rejects join
  joinReject,

  /// Heartbeat to check connection
  heartbeat,

  /// Player disconnected
  disconnected,

  /// Error message
  error,

  /// Discrete game event (like card stolen animation)
  gameEvent,
}

/// Network message wrapper
class NetworkMessage {
  final MessageType type;
  final Map<String, dynamic> payload;
  final String? senderId;
  final DateTime timestamp;

  NetworkMessage({
    required this.type,
    required this.payload,
    this.senderId,
  }) : timestamp = DateTime.now();

  /// Create a state sync message (host -> clients)
  factory NetworkMessage.stateSync(GameState state) {
    return NetworkMessage(
      type: MessageType.stateSync,
      payload: {'state': state.toJson()},
    );
  }

  /// Create a player action message (client -> host)
  factory NetworkMessage.playerAction(
      Map<String, dynamic> action, String playerId) {
    return NetworkMessage(
      type: MessageType.playerAction,
      payload: action,
      senderId: playerId,
    );
  }

  /// Create a join request message
  factory NetworkMessage.joinRequest(Player player) {
    return NetworkMessage(
      type: MessageType.joinRequest,
      payload: {'player': player.toJson()},
      senderId: player.id,
    );
  }

  /// Create a join confirm message
  factory NetworkMessage.joinConfirm(GameState state) {
    return NetworkMessage(
      type: MessageType.joinConfirm,
      payload: {'state': state.toJson()},
    );
  }

  /// Create a join reject message
  factory NetworkMessage.joinReject(String reason) {
    return NetworkMessage(
      type: MessageType.joinReject,
      payload: {'reason': reason},
    );
  }

  /// Create a heartbeat message
  factory NetworkMessage.heartbeat(String playerId) {
    return NetworkMessage(
      type: MessageType.heartbeat,
      payload: {},
      senderId: playerId,
    );
  }

  /// Create a disconnect message
  factory NetworkMessage.disconnected(String playerId) {
    return NetworkMessage(
      type: MessageType.disconnected,
      payload: {'playerId': playerId},
      senderId: playerId,
    );
  }

  /// Create a game event message (host -> clients)
  factory NetworkMessage.gameEvent(
      GameEventType eventType, String message, Map<String, dynamic>? data) {
    return NetworkMessage(
      type: MessageType.gameEvent,
      payload: {
        'eventType': eventType.index,
        'message': message,
        'data': data,
      },
    );
  }

  /// Encode to JSON string for transmission
  String encode() {
    return jsonEncode({
      'type': type.index,
      'payload': payload,
      'senderId': senderId,
      'timestamp': timestamp.toIso8601String(),
    });
  }

  /// Decode from JSON string
  factory NetworkMessage.decode(String data) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    return NetworkMessage(
      type: MessageType.values[json['type'] as int],
      payload: json['payload'] as Map<String, dynamic>,
      senderId: json['senderId'] as String?,
    );
  }
}
