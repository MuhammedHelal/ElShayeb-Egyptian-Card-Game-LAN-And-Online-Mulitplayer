/// Data Layer - LAN Network Manager
///
/// TCP socket-based networking for local Wi-Fi multiplayer.
/// Host architecture:
/// - Host creates a TCP server
/// - Clients connect via TCP socket
/// - Host validates all actions and broadcasts state
/// - Uses UDP broadcast for room discovery
library;

import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:convert';

import '../../domain/entities/entities.dart';
import 'network_manager.dart';
import 'network_message.dart';
import 'lan_discovery.dart';

/// LAN network manager using TCP sockets
class LanNetworkManager implements NetworkManager {
  // Server-side (Host)
  ServerSocket? _server;
  final Map<String, Socket> _clientSockets = {};

  // Client-side
  Socket? _clientSocket;

  // LAN Discovery
  final LanDiscovery _discovery = LanDiscovery();

  // State
  bool _isHosting = false;
  bool _isConnected = false;
  String? _localPlayerId;
  GameState? _currentState;
  String? _localIpAddress;

  // Heartbeat
  Timer? _heartbeatTimer;
  static const _heartbeatInterval = Duration(seconds: 5);
  static const _connectionTimeout = Duration(seconds: 15);
  final Map<String, DateTime> _lastHeartbeat = {};

  // Reconnection
  String? _lastHostAddress;
  int? _lastHostPort;
  Player? _lastPlayer;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  // Callbacks
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
  String? get hostAddress => _localIpAddress;

  @override
  int? get hostPort => _server?.port;

  /// Get discovered rooms
  List<RoomInfo> get discoveredRooms => _discovery.discoveredRooms;

  /// Start hosting a game
  @override
  Future<void> startHosting(GameState initialState) async {
    if (_isHosting) return;

    try {
      // Get local IP address first
      _localIpAddress = await _discovery.getLocalIpAddress();

      // Bind to all interfaces on a dynamic port
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      _isHosting = true;
      _isConnected = true;
      _currentState = initialState;

      log('LAN Server started on $_localIpAddress:${_server!.port}');

      // Listen for incoming connections
      _server!.listen(
        _handleClientConnection,
        onError: (error) {
          log('Server error: $error');
        },
        onDone: () {
          log('Server closed');
          _isHosting = false;
        },
      );

      // Start UDP broadcast advertising
      _startAdvertising(initialState);

      // Start heartbeat monitoring
      _startHeartbeatMonitor();
    } catch (e) {
      log('Failed to start hosting: $e');
      rethrow;
    }
  }

  /// Get host name from state
  String _getHostName(GameState state) {
    try {
      return state.players.firstWhere((p) => p.isHost).name;
    } catch (_) {
      return 'Host';
    }
  }

  /// Start advertising the room
  void _startAdvertising(GameState state) {
    try {
      final roomInfo = RoomInfo(
        roomId: state.roomId,
        roomCode: state.roomCode,
        hostName: _getHostName(state),
        hostAddress: _localIpAddress ?? '',
        port: _server?.port ?? 0,
        playerCount: state.players.length,
        maxPlayers: 6,
        isStarted: state.phase != GamePhase.lobby,
      );
      _discovery.startAdvertising(roomInfo);
    } catch (e) {
      log('Failed to start advertising: $e');
    }
  }

  /// Update the advertised room info (when players join/leave)
  void updateRoomInfo(GameState state) {
    if (!_isHosting || _server == null) return;
    _currentState = state;

    // Update advertising info
    // Safe to call as LanDiscovery.startAdvertising now handles updates without re-binding
    try {
      final roomInfo = RoomInfo(
        roomId: state.roomId,
        roomCode: state.roomCode,
        hostName: _getHostName(state),
        hostAddress: _localIpAddress ?? '',
        port: _server?.port ?? 0,
        playerCount: state.players.length,
        maxPlayers: 6,
        isStarted: state.phase != GamePhase.lobby,
      );
      _discovery.startAdvertising(roomInfo);
    } catch (e) {
      log('Failed to update room info: $e');
    }
  }

  /// Handle new client connection
  void _handleClientConnection(Socket socket) {
    final clientAddress =
        '${socket.remoteAddress.address}:${socket.remotePort}';
    log('Client connected from $clientAddress');

    String buffer = '';

    socket.listen(
      (data) {
        try {
          buffer += utf8.decode(data);

          // Process complete messages (delimited by newline)
          while (buffer.contains('\n')) {
            final index = buffer.indexOf('\n');
            final messageData = buffer.substring(0, index);
            buffer = buffer.substring(index + 1);

            try {
              final message = NetworkMessage.decode(messageData);
              _handleClientMessage(socket, message);
            } catch (e) {
              log('Error parsing message: $e');
            }
          }
        } catch (e) {
          log('Error decoding data: $e');
        }
      },
      onError: (error) {
        log('Client error: $error');
        _removeClient(socket);
      },
      onDone: () {
        log('Client disconnected: $clientAddress');
        _removeClient(socket);
      },
    );
  }

  /// Handle message from client
  void _handleClientMessage(Socket socket, NetworkMessage message) {
    try {
      switch (message.type) {
        case MessageType.joinRequest:
          _handleJoinRequest(socket, message);
          break;
        case MessageType.playerAction:
          if (message.senderId != null) {
            onPlayerAction?.call(message.payload);
          }
          break;
        case MessageType.heartbeat:
          if (message.senderId != null) {
            _lastHeartbeat[message.senderId!] = DateTime.now();
          }
          break;
        case MessageType.disconnected:
          _removeClient(socket);
          break;
        default:
          break;
      }
    } catch (e) {
      log('Error handling client message: $e');
    }
  }

  /// Handle join request from client
  void _handleJoinRequest(Socket socket, NetworkMessage message) {
    try {
      final playerData = message.payload['player'] as Map<String, dynamic>;
      final player = Player.fromJson(playerData);

      // Check if can join
      if (_currentState != null && _currentState!.isFull) {
        _sendToSocket(socket, NetworkMessage.joinReject('Room is full'));
        return;
      }

      // Accept join (allow late joining - game logic will handle spectator state)
      _clientSockets[player.id] = socket;
      _lastHeartbeat[player.id] = DateTime.now();

      // Notify game controller via action callback
      onPlayerAction?.call({
        'type': 'join',
        'player': playerData,
      });
    } catch (e) {
      log('Error handling join request: $e');
      _sendToSocket(socket, NetworkMessage.joinReject('Invalid request'));
    }
  }

  /// Remove client connection
  void _removeClient(Socket socket) {
    String? playerId;
    _clientSockets.forEach((id, s) {
      if (s == socket) playerId = id;
    });

    if (playerId != null) {
      _clientSockets.remove(playerId);
      _lastHeartbeat.remove(playerId);
      onConnectionChange?.call(playerId!, false);
    }

    try {
      socket.close();
    } catch (_) {}
  }

  /// Send message to a specific socket
  void _sendToSocket(Socket socket, NetworkMessage message) {
    try {
      final data = '${message.encode()}\n';
      socket.write(data);
    } catch (e) {
      log('Error sending to socket: $e');
    }
  }

  /// Broadcast state to all clients
  @override
  Future<void> broadcastState(GameState state) async {
    if (!_isHosting) return;

    _currentState = state;

    try {
      final message = NetworkMessage.stateSync(state);

      // Send to each client with proper error handling
      for (final entry in _clientSockets.entries) {
        try {
          _sendToSocket(entry.value, message);
        } catch (e) {
          log('Error sending state to ${entry.key}: $e');
        }
      }
    } catch (e) {
      log('Error broadcasting state: $e');
    }
  }

  /// Broadcast a discrete game event to all clients
  @override
  Future<void> broadcastEvent(GameEvent event) async {
    if (!_isHosting) return;

    try {
      final message = NetworkMessage.gameEvent(
        event.type,
        event.message,
        event.data,
      );

      // Send to each client with proper error handling
      for (final entry in _clientSockets.entries) {
        try {
          _sendToSocket(entry.value, message);
        } catch (e) {
          log('Error sending event to ${entry.key}: $e');
        }
      }
    } catch (e) {
      log('Error broadcasting event: $e');
    }
  }

  /// Stop hosting
  @override
  Future<void> stopHosting() async {
    _heartbeatTimer?.cancel();

    // Stop discovery advertising
    _discovery.stopAdvertising();

    // Close all client connections
    for (final socket in _clientSockets.values) {
      try {
        socket.close();
      } catch (_) {}
    }
    _clientSockets.clear();
    _lastHeartbeat.clear();

    // Close server
    await _server?.close();
    _server = null;

    _isHosting = false;
    _isConnected = false;
    _currentState = null;
  }

  /// Connect to host as client
  @override
  Future<void> connectToHost(String address, int port, Player player) async {
    if (_isConnected) return;

    _lastHostAddress = address;
    _lastHostPort = port;
    _lastPlayer = player;
    _localPlayerId = player.id;

    try {
      _clientSocket = await Socket.connect(
        address,
        port,
        timeout: const Duration(seconds: 10),
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      log('Connected to host at $address:$port');

      String buffer = '';

      _clientSocket!.listen(
        (data) {
          try {
            buffer += utf8.decode(data);

            while (buffer.contains('\n')) {
              final index = buffer.indexOf('\n');
              final messageData = buffer.substring(0, index);
              buffer = buffer.substring(index + 1);

              try {
                final message = NetworkMessage.decode(messageData);
                _handleHostMessage(message);
              } catch (e) {
                log('Error parsing message: $e');
              }
            }
          } catch (e) {
            log('Error decoding data: $e');
          }
        },
        onError: (error) {
          log('Connection error: $error');
          _handleDisconnect();
        },
        onDone: () {
          log('Disconnected from host');
          _handleDisconnect();
        },
      );

      // Send join request
      final joinMessage = NetworkMessage.joinRequest(player);
      _clientSocket!.write('${joinMessage.encode()}\n');
      await _clientSocket!.flush();

      // Start sending heartbeats
      _startClientHeartbeat();
    } catch (e) {
      log('Failed to connect: $e');
      _handleDisconnect();
      rethrow;
    }
  }

  /// Handle message from host
  void _handleHostMessage(NetworkMessage message) {
    try {
      switch (message.type) {
        case MessageType.stateSync:
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
        case MessageType.joinConfirm:
          final stateData = message.payload['state'] as Map<String, dynamic>;
          final state = GameState.fromJson(stateData);
          onStateUpdate?.call(state);
          break;
        case MessageType.joinReject:
          final reason = message.payload['reason'] as String;
          log('Join rejected: $reason');
          disconnect();
          break;
        default:
          break;
      }
    } catch (e) {
      log('Error handling host message: $e');
    }
  }

  /// Handle disconnect (attempt reconnection)
  void _handleDisconnect() {
    _isConnected = false;
    _clientSocket = null;
    _heartbeatTimer?.cancel();

    if (_lastHostAddress != null &&
        _reconnectAttempts < _maxReconnectAttempts) {
      _attemptReconnect();
    } else {
      onConnectionChange?.call(_localPlayerId ?? '', false);
    }
  }

  /// Attempt to reconnect
  void _attemptReconnect() {
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);

    log('Attempting reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(delay, () async {
      if (_lastHostAddress != null &&
          _lastHostPort != null &&
          _lastPlayer != null) {
        try {
          await connectToHost(_lastHostAddress!, _lastHostPort!, _lastPlayer!);
        } catch (e) {
          log('Reconnect failed: $e');
        }
      }
    });
  }

  /// Start client heartbeat
  void _startClientHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_isConnected && _localPlayerId != null) {
        final message = NetworkMessage.heartbeat(_localPlayerId!);
        try {
          _clientSocket?.write('${message.encode()}\n');
        } catch (e) {
          log('Heartbeat error: $e');
        }
      }
    });
  }

  /// Start heartbeat monitor (host)
  void _startHeartbeatMonitor() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      final now = DateTime.now();
      final disconnected = <String>[];

      _lastHeartbeat.forEach((playerId, lastTime) {
        if (now.difference(lastTime) > _connectionTimeout) {
          disconnected.add(playerId);
        }
      });

      for (final playerId in disconnected) {
        final socket = _clientSockets[playerId];
        if (socket != null) {
          _removeClient(socket);
        }
      }
    });
  }

  /// Send action to host (client only)
  @override
  Future<void> sendAction(Map<String, dynamic> action) async {
    if (!_isConnected || _clientSocket == null || _localPlayerId == null) {
      return;
    }

    final message = NetworkMessage.playerAction(action, _localPlayerId!);
    try {
      _clientSocket!.write('${message.encode()}\n');
      await _clientSocket!.flush();
    } catch (e) {
      log('Error sending action: $e');
    }
  }

  /// Disconnect from host
  @override
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();

    if (_localPlayerId != null) {
      final message = NetworkMessage.disconnected(_localPlayerId!);
      try {
        _clientSocket?.write('${message.encode()}\n');
      } catch (_) {}
    }

    try {
      await _clientSocket?.close();
    } catch (_) {}

    _clientSocket = null;
    _isConnected = false;
    _localPlayerId = null;
    _lastHostAddress = null;
    _lastHostPort = null;
    _lastPlayer = null;
    _reconnectAttempts = 0;
  }

  // ============ LAN Discovery ============

  /// Start discovering rooms on the network
  @override
  Future<void> startDiscovery() async {
    _discovery.onRoomsUpdated = (rooms) {
      onRoomDiscovered?.call(rooms);
    };
    await _discovery.startDiscovery();
  }

  /// Stop room discovery
  @override
  Future<void> stopDiscovery() async {
    _discovery.stopDiscovery();
  }

  /// Dispose all resources
  @override
  void dispose() {
    stopHosting();
    disconnect();
    stopDiscovery();
    _discovery.dispose();
  }
}
