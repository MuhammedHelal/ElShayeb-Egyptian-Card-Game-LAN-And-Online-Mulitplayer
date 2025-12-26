/// Data Layer - Network Manager Interface
///
/// Abstract interface for network communication.
/// Allows swapping between LAN (TCP) and Online (WebSocket) implementations.
library;

import '../../domain/entities/entities.dart';

/// Callback types for network events
typedef StateUpdateCallback = void Function(GameState state);
typedef PlayerActionCallback = void Function(Map<String, dynamic> action);
typedef ConnectionChangeCallback = void Function(
    String playerId, bool connected);
typedef RoomDiscoveryCallback = void Function(List<RoomInfo> rooms);

/// Abstract network manager interface
abstract class NetworkManager {
  /// Callback when state is updated (clients receive from host)
  StateUpdateCallback? onStateUpdate;

  /// Callback when a player action is received (host receives from clients)
  PlayerActionCallback? onPlayerAction;

  /// Callback when connection status changes
  ConnectionChangeCallback? onConnectionChange;

  /// Callback when rooms are discovered (LAN only)
  RoomDiscoveryCallback? onRoomDiscovered;

  /// Whether currently connected
  bool get isConnected;

  /// Whether this instance is hosting
  bool get isHosting;

  /// Start hosting a game (creates server)
  Future<void> startHosting(GameState initialState);

  /// Stop hosting
  Future<void> stopHosting();

  /// Connect to a host as a client
  Future<void> connectToHost(String address, int port, Player player);

  /// Disconnect from host
  Future<void> disconnect();

  /// Broadcast state to all clients (host only)
  Future<void> broadcastState(GameState state);

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
