/// Domain Layer - Online Network Service Interface
///
/// Abstract interface for online multiplayer functionality.
/// Decouples game logic from specific backend implementations (Supabase, Firebase, etc).
library;

import 'connection_state.dart';
import 'online_events.dart';

/// Callback for receiving online game events
typedef OnlineEventCallback = void Function(OnlineGameEvent event);

/// Callback for connection state changes
typedef ConnectionStateCallback = void Function(OnlineConnectionState state);

/// Interface for online network operations
abstract class OnlineNetworkService {
  /// Stream of connection state changes
  Stream<OnlineConnectionState> get connectionState;

  /// Stream of game events
  Stream<OnlineGameEvent> get gameEvents;

  /// Current user ID (from auth)
  String? get currentUserId;

  /// Initialize the service
  Future<void> initialize();

  /// Create a new game room
  /// Returns the room ID
  Future<String> createRoom(Map<String, dynamic> initialGameState);

  /// Join an existing room
  Future<void> joinRoom(String roomId, Map<String, dynamic> playerData);

  /// Leave the current room
  Future<void> leaveRoom();

  /// Broadcast a game event to other players in the room
  Future<void> broadcastEvent(OnlineGameEvent event);

  /// Update shared game state (last action, etc)
  Future<void> updateState(Map<String, dynamic> stateData);

  /// Dispose resources
  void dispose();
}
