// Abstract interface for network communication.
// Allows swapping between LAN (TCP) and Online (WebSocket) implementations.

import '../../domain/entities/entities.dart';

typedef StateUpdateCallback = void Function(GameState state);
typedef PlayerActionCallback = void Function(Map<String, dynamic> action);
typedef ConnectionChangeCallback = void Function(
    String playerId, bool connected);
typedef RoomDiscoveryCallback = void Function(List<RoomInfo> rooms);

abstract class NetworkManager {
  StateUpdateCallback? onStateUpdate;

  PlayerActionCallback? onPlayerAction;

  ConnectionChangeCallback? onConnectionChange;

  RoomDiscoveryCallback? onRoomDiscovered;

  GameEventCallback? onGameEvent;

  bool get isConnected;

  bool get isHosting;

  Future<void> startHosting(GameState initialState);
  Future<void> stopHosting();

  /// Connect to a host as a client
  Future<void> connectToHost(String address, int port, Player player);

  /// Disconnect from host
  Future<void> disconnect();

  /// Broadcast state to all clients (host only)
  Future<void> broadcastState(GameState state);

  /// Broadcast a discrete game event to all clients (host only)
  Future<void> broadcastEvent(GameEvent event);

  /// Send an action to the host (client only)
  Future<void> sendAction(Map<String, dynamic> action);

  /// Start discovering rooms on the network (LAN only)
  Future<void> startDiscovery();

  /// Stop discovering rooms
  Future<void> stopDiscovery();

  /// Get the host address and port for sharing
  String? get hostAddress;
  int? get hostPort;

  /// Dispose resources
  void dispose();
}
