/// Data Layer - Online Network Manager (Adapter)
///
/// Adapts the generic NetworkManager interface (used by Game Controller)
/// to the OnlineNetworkService interface (implemented by Supabase/Firebase).
library;

import 'dart:async';
import 'dart:developer';

import '../../domain/entities/entities.dart';
import '../../injection_container.dart';
import 'connection_state.dart';
import 'network_manager.dart';
import 'online_events.dart';
import 'online_network_service.dart';

class OnlineNetworkManager implements NetworkManager {
  final OnlineNetworkService _networkService;

  // Local state to track game context
  bool _isHosting = false;
  String? _localPlayerId;
  String? _currentRoomId;

  StreamSubscription? _eventSub;
  StreamSubscription? _connectionSub;

  OnlineNetworkManager({
    OnlineNetworkService? networkService,
  }) : _networkService = networkService ?? getIt<OnlineNetworkService>();

  @override
  StateUpdateCallback? onStateUpdate;

  @override
  PlayerActionCallback? onPlayerAction;

  @override
  GameEventCallback? onGameEvent;

  @override
  ConnectionChangeCallback? onConnectionChange;

  @override
  RoomDiscoveryCallback? onRoomDiscovered;

  @override
  bool get isConnected => _currentRoomId != null; // Simplified logic

  @override
  bool get isHosting => _isHosting;

  @override
  String? get hostAddress =>
      _currentRoomId; // In online mode, hostAddress is the Room Code

  @override
  int? get hostPort => null;

  /// Start hosting a game
  @override
  Future<void> startHosting(GameState initialState) async {
    try {
      _isHosting = true;
      _localPlayerId = initialState.hostId;

      await _networkService.initialize();
      _setupListeners();

      // Create room via service
      final roomId = await _networkService.createRoom({
        'roomCode': initialState.roomCode,
        'hostName': initialState.players.first.name,
        'hostId': initialState.hostId,
        'initialState': initialState.toJson(),
      });

      _currentRoomId = roomId;

      // Initial broadcast
      await broadcastState(initialState);
    } catch (e) {
      log('Error start hosting: $e');
      _isHosting = false;
      rethrow;
    }
  }

  /// Connect to a host (Join Room)
  @override
  Future<void> connectToHost(String address, int port, Player player) async {
    try {
      _isHosting = false;
      _localPlayerId = player.id;

      // address is the room code/id in online mode
      final roomId = address;

      await _networkService.initialize();
      _setupListeners();

      await _networkService.joinRoom(roomId, {
        'name': player.name,
        'id': player.id,
        'avatarId': player.avatarId,
      });

      _currentRoomId = roomId;

      // Notify we joined - sending a "join" action to host
      // In Supabase, the presence join handles this now.
      // We removed the explicit action to prevent race conditions and rely on presence.
      log('Joined room $roomId via Supabase Presence');
    } catch (e) {
      log('Error connecting to host: $e');
      _currentRoomId = null;
      rethrow;
    }
  }

  /// Disconnect/Leave
  @override
  Future<void> disconnect() async {
    await _networkService.leaveRoom();
    _currentRoomId = null;
    _isHosting = false;
    _eventSub?.cancel();
    _connectionSub?.cancel();
  }

  /// Broadcast state (Host Only)
  @override
  Future<void> broadcastState(GameState state) async {
    if (!_isHosting) return;

    await _networkService.updateState(state.toJson());
  }

  /// Broadcast discrete event (Host Only)
  @override
  Future<void> broadcastEvent(GameEvent event) async {
    if (!_isHosting) return;

    await _networkService.broadcastEvent(GenericGameEvent(
      type: OnlineEventTypes.gameAction, // Wrapper type
      data: {
        'eventType': event.type.index,
        'message': event.message,
        'data': event.data,
      },
      timestamp: DateTime.now(),
      senderId: _localPlayerId,
    ));
  }

  /// Send action to host (Client)
  @override
  Future<void> sendAction(Map<String, dynamic> action) async {
    // In our architecture, "sending action" is just broadcasting an event
    // The Host listens to all events and processes "player_action" types

    await _networkService.broadcastEvent(GenericGameEvent(
      type: OnlineEventTypes.gameAction,
      data: {
        'isPlayerAction': true,
        'actionPayload': action,
      },
      timestamp: DateTime.now(),
      senderId: _localPlayerId,
    ));
  }

  void _setupListeners() {
    _eventSub?.cancel();
    _eventSub = _networkService.gameEvents.listen(_handleIncomingEvent);

    _connectionSub?.cancel();
    _connectionSub =
        _networkService.connectionState.listen(_handleConnectionState);
  }

  void _handleIncomingEvent(OnlineGameEvent event) {
    try {
      // 1. State Sync (Clients receive state)
      if (event.type == OnlineEventTypes.stateSync) {
        log('Received State Sync Event');
        if (!_isHosting) {
          // Host ignores state sync (it is the source of truth)
          if (event.data['state'] == null) {
            log('Warning: received empty state sync');
            return;
          }
          final stateData = event.data['state'] as Map<String, dynamic>;
          log('Updating local state from network sync');
          final state = GameState.fromJson(stateData);
          onStateUpdate?.call(state);
        } else {
          log('Host ignored state sync event (Self-Reflection)');
        }
        return;
      }

      // 2. Game Actions / Events
      if (event.type == OnlineEventTypes.gameAction) {
        log('Received Game Action: ${event.data}');
        final data = event.data;

        // Check if it's a generic GameEvent (broadcasted by host to everyone)
        if (data.containsKey('eventType') &&
            !data.containsKey('isPlayerAction')) {
          final eventTypeIndex = data['eventType'] as int;
          final message = data['message'] as String;
          final eventData = data['data'] as Map<String, dynamic>?;

          final gameEvent = GameEvent(
            type: GameEventType.values[eventTypeIndex],
            message: message,
            data: eventData,
          );
          onGameEvent?.call(gameEvent);
          return;
        }

        // Check if it's a Player Action (sent by client to host)
        if (data.containsKey('isPlayerAction') && _isHosting) {
          log('Processing Player Action as Host');
          final action = data['actionPayload'] as Map<String, dynamic>;
          onPlayerAction?.call(action);
          return;
        }
      }

      // 3. Player Joined (Presence)
      if (event.type == OnlineEventTypes.playerJoined) {
        log('Player Joined Event (Presence): ${event.data}');

        final playerId = event.senderId;
        if (playerId == _localPlayerId) {
          // Ignore our own presence event to prevent double-processing
          return;
        }

        // Reliable Joining: Host automatically adds any player that appears in presence
        if (_isHosting && onPlayerAction != null) {
          log('Host detecting new player presence: $playerId');
          // Construct a join action payload from presence data
          final joinAction = {
            'type': 'join',
            'player': event.data,
          };
          onPlayerAction!(joinAction);
        }

        if (playerId != null) {
          onConnectionChange?.call(playerId, true);
        }
      }

      // 4. Player Left
      if (event.type == OnlineEventTypes.playerLeft) {
        final playerId = event.senderId;
        if (playerId != null) {
          onConnectionChange?.call(playerId, false);
        }
      }
    } catch (e) {
      log('Error handling online event: $e');
    }
  }

  void _handleConnectionState(OnlineConnectionState state) {
    log('Connection State: ${state.status}');
    if (state.status == OnlineConnectionStatus.disconnected ||
        state.status == OnlineConnectionStatus.error) {
      // Maybe notify UI of disconnection
      if (_localPlayerId != null) {
        onConnectionChange?.call(_localPlayerId!, false);
      }
    }
  }

  // Not used in Online Mode
  @override
  Future<void> startDiscovery() async {}

  @override
  Future<void> stopDiscovery() async {}

  @override
  Future<void> stopHosting() async {
    await disconnect();
  }

  @override
  void dispose() {
    disconnect();
  }
}
