/// Data Layer - Online Network Manager
///
/// WebSocket-based networking for online multiplayer.
/// Uses the same game engine and rules as LAN mode.
/// Simply swaps the transport layer from TCP to WebSocket.
library;

import 'dart:async';
import 'dart:developer';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/entities/entities.dart';
import '../../core/constants/endpoints.dart';
import 'network_manager.dart';
import 'network_message.dart';

/// Online network manager using WebSockets
class OnlineNetworkManager implements NetworkManager {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  bool _isConnected = false;
  bool _isHosting = false;
  String? _localPlayerId;
  String? _roomId;

  // Heartbeat
  Timer? _heartbeatTimer;
  static const _heartbeatInterval = Duration(seconds: 10);

  // Reconnection
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;
  Player? _lastPlayer;

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
  bool get isConnected => _isConnected;

  @override
  bool get isHosting => _isHosting;

  @override
  String? get hostAddress => Endpoints.gameSocket;

  @override
  int? get hostPort => null; // Port is in the URL

  /// Start hosting a game (creates room on server)
  @override
  Future<void> startHosting(GameState initialState) async {
    _isHosting = true;
    _roomId = initialState.roomId;

    await _connect();

    // Send create room message
    final message = NetworkMessage(
      type: MessageType.stateSync,
      payload: {
        'action': 'create',
        'state': initialState.toJson(),
      },
    );

    _send(message);
  }

  /// Stop hosting
  @override
  Future<void> stopHosting() async {
    if (_roomId != null) {
      final message = NetworkMessage(
        type: MessageType.disconnected,
        payload: {'action': 'close_room', 'roomId': _roomId},
      );
      _send(message);
    }

    await disconnect();
    _isHosting = false;
  }

  /// Connect to WebSocket server
  Future<void> _connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(Endpoints.gameSocket));

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          log('WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          log('WebSocket closed');
          _handleDisconnect();
        },
      );

      _isConnected = true;
      _reconnectAttempts = 0;

      _startHeartbeat();
    } catch (e) {
      log('Failed to connect to server: $e');
      _handleDisconnect();
      rethrow;
    }
  }

  /// Handle incoming message
  void _handleMessage(dynamic data) {
    try {
      final message = NetworkMessage.decode(data as String);

      switch (message.type) {
        case MessageType.stateSync:
          final stateData = message.payload['state'] as Map<String, dynamic>;
          final state = GameState.fromJson(stateData);
          onStateUpdate?.call(state);
          break;

        case MessageType.playerAction:
          // Host receives player actions from server relay
          if (_isHosting) {
            onPlayerAction?.call(message.payload);
          }
          break;

        case MessageType.joinConfirm:
          final stateData = message.payload['state'] as Map<String, dynamic>;
          final state = GameState.fromJson(stateData);
          onStateUpdate?.call(state);
          break;

        case MessageType.gameEvent:
          final eventType =
              GameEventType.values[message.payload['eventType'] as int];
          final eventMessage = message.payload['message'] as String;
          final eventData = message.payload['data'] as Map<String, dynamic>?;

          final event = GameEvent(
            type: eventType,
            message: eventMessage,
            data: eventData,
          );
          onGameEvent?.call(event);
          break;

        case MessageType.joinReject:
          log('Join rejected: ${message.payload['reason']}');
          disconnect();
          break;

        case MessageType.disconnected:
          final playerId = message.payload['playerId'] as String?;
          if (playerId != null) {
            onConnectionChange?.call(playerId, false);
          }
          break;

        case MessageType.error:
          log('Server error: ${message.payload['message']}');
          break;

        default:
          break;
      }
    } catch (e) {
      log('Error handling message: $e');
    }
  }

  /// Handle disconnect
  void _handleDisconnect() {
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _channel = null;

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _attemptReconnect();
    } else {
      onConnectionChange?.call(_localPlayerId ?? '', false);
    }
  }

  /// Attempt reconnection
  void _attemptReconnect() {
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);

    log('Attempting reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(delay, () async {
      try {
        await _connect();

        // Re-join room if was a client
        if (_lastPlayer != null && _roomId != null) {
          await _rejoinRoom();
        }
      } catch (e) {
        log('Reconnect failed: $e');
      }
    });
  }

  /// Re-join room after reconnection
  Future<void> _rejoinRoom() async {
    if (_lastPlayer == null || _roomId == null) return;

    final message = NetworkMessage(
      type: MessageType.joinRequest,
      payload: {
        'roomId': _roomId,
        'player': _lastPlayer!.toJson(),
        'reconnect': true,
      },
      senderId: _lastPlayer!.id,
    );

    _send(message);
  }

  /// Connect to a room as client
  @override
  Future<void> connectToHost(String address, int port, Player player) async {
    // For online mode, address is the room code
    _roomId = address;
    _localPlayerId = player.id;
    _lastPlayer = player;
    _isHosting = false;

    await _connect();

    // Send join request
    final message = NetworkMessage.joinRequest(player);
    message.payload['roomId'] = _roomId;

    _send(message);
  }

  /// Disconnect from server
  @override
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    if (_localPlayerId != null) {
      final message = NetworkMessage.disconnected(_localPlayerId!);
      _send(message);
    }

    await _subscription?.cancel();
    await _channel?.sink.close();

    _channel = null;
    _subscription = null;
    _isConnected = false;
    _localPlayerId = null;
    _roomId = null;
    _lastPlayer = null;
    _reconnectAttempts = 0;
  }

  /// Broadcast state to all clients (via server)
  @override
  Future<void> broadcastState(GameState state) async {
    if (!_isHosting) return;

    final message = NetworkMessage.stateSync(state);
    message.payload['roomId'] = _roomId;

    _send(message);
  }

  /// Broadcast a discrete game event to all clients (via server)
  @override
  Future<void> broadcastEvent(GameEvent event) async {
    if (!_isHosting) return;

    final message = NetworkMessage.gameEvent(
      event.type,
      event.message,
      event.data,
    );
    message.payload['roomId'] = _roomId;

    _send(message);
  }

  /// Send action to host (via server)
  @override
  Future<void> sendAction(Map<String, dynamic> action) async {
    if (_localPlayerId == null) return;

    final message = NetworkMessage.playerAction(action, _localPlayerId!);
    message.payload['roomId'] = _roomId;

    _send(message);
  }

  /// Send message to server
  void _send(NetworkMessage message) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(message.encode());
      } catch (e) {
        log('Error sending message: $e');
      }
    }
  }

  /// Start heartbeat
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_isConnected && _localPlayerId != null) {
        final message = NetworkMessage.heartbeat(_localPlayerId!);
        _send(message);
      }
    });
  }

  /// Start discovering rooms (online)
  @override
  Future<void> startDiscovery() async {
    // Online mode doesn't use mDNS discovery
    // Rooms are found by room code
  }

  /// Stop discovery
  @override
  Future<void> stopDiscovery() async {
    // Nothing to stop for online mode
  }

  /// Dispose resources
  @override
  void dispose() {
    disconnect();
  }
}
