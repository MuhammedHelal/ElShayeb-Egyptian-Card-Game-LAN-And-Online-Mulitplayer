import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/constants/online_server_constants.dart';
import '../models/online_protocol_models.dart';

abstract class OnlineSessionRemoteDataSource {
  Stream<OnlineSessionUpdateModel> observe();

  Future<OnlineLobbyModel> createRoom({
    required String playerName,
    required String avatarId,
  });

  Future<OnlineLobbyModel> joinRoom({
    required String roomCode,
    required String playerName,
    required String avatarId,
  });

  Future<OnlineLobbyModel> resumeRoom({
    required String roomCode,
    required String playerName,
    required String avatarId,
  });

  Future<void> leaveRoom();

  Future<OnlineLobbyModel> startGame(int expectedStateVersion);

  Future<OnlineLobbyModel> drawCard({
    required String targetUserId,
    required int cardIndex,
    required int expectedStateVersion,
  });

  Future<OnlineLobbyModel> shuffleHand(int expectedStateVersion);

  Future<OnlineLobbyModel> startNewRound(int expectedStateVersion);
}

class CloudflareOnlineSessionDataSource
    implements OnlineSessionRemoteDataSource {
  final SupabaseClient _supabase;
  final http.Client _httpClient;
  final Uuid _uuid;

  final _updates = StreamController<OnlineSessionUpdateModel>.broadcast();
  final Map<String, Completer<Map<String, dynamic>>> _pendingCommands = {};

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Completer<void>? _connectionReady;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _connectionGeneration = 0;
  int _reconnectAttempt = 0;
  bool _heartbeatInFlight = false;
  bool _intentionalClose = false;
  bool _socketAvailable = false;
  bool _canAutoReconnect = false;
  String? _roomCode;
  String? _playerName;
  String? _avatarId;

  CloudflareOnlineSessionDataSource({
    required SupabaseClient supabase,
    required http.Client httpClient,
    Uuid uuid = const Uuid(),
  })  : _supabase = supabase,
        _httpClient = httpClient,
        _uuid = uuid;

  @override
  Stream<OnlineSessionUpdateModel> observe() => _updates.stream;

  @override
  Future<OnlineLobbyModel> createRoom({
    required String playerName,
    required String avatarId,
  }) async {
    for (var attempt = 0; attempt < 3; attempt += 1) {
      final roomCode = await _allocateRoomCode();
      try {
        return await _connectAndEnter(
          roomCode: roomCode,
          playerName: playerName,
          avatarId: avatarId,
          commandType: 'create_room',
        );
      } on OnlineProtocolException catch (error) {
        if (error.code != 'room_already_exists' || attempt == 2) rethrow;
      }
    }
    throw const OnlineProtocolException(
      'room_code_failed',
      'A room could not be created right now.',
    );
  }

  Future<String> _allocateRoomCode() async {
    final response = await _httpClient.post(
      Uri.parse('${OnlineServerConstants.httpsBaseUrl}/room-code'),
    );
    if (response.statusCode != 201) {
      throw const OnlineProtocolException(
        'room_code_failed',
        'A room could not be created right now.',
      );
    }
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['roomCode'] is String) {
        return body['roomCode'] as String;
      }
    } on FormatException {
      // Converted to a stable protocol error below.
    }
    throw const OnlineProtocolException(
      'invalid_room_code',
      'A room could not be created right now.',
    );
  }

  @override
  Future<OnlineLobbyModel> joinRoom({
    required String roomCode,
    required String playerName,
    required String avatarId,
  }) {
    final normalizedCode = roomCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(normalizedCode)) {
      throw const OnlineProtocolException(
        'invalid_room_code',
        'Room codes contain exactly six letters or numbers.',
      );
    }
    return _connectAndEnter(
      roomCode: normalizedCode,
      playerName: playerName,
      avatarId: avatarId,
      commandType: 'join_room',
    );
  }

  @override
  Future<OnlineLobbyModel> resumeRoom({
    required String roomCode,
    required String playerName,
    required String avatarId,
  }) {
    return _connectAndEnter(
      roomCode: roomCode.trim().toUpperCase(),
      playerName: playerName,
      avatarId: avatarId,
      commandType: 'resume_room',
    );
  }

  Future<OnlineLobbyModel> _connectAndEnter({
    required String roomCode,
    required String playerName,
    required String avatarId,
    required String commandType,
    bool reconnecting = false,
    bool resetReconnectAttempts = true,
  }) async {
    if (resetReconnectAttempts) {
      _reconnectAttempt = 0;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
    _roomCode = roomCode;
    _playerName = playerName;
    _avatarId = avatarId;
    _intentionalClose = false;
    _socketAvailable = false;
    _canAutoReconnect = commandType == 'resume_room' || _canAutoReconnect;
    _stopHeartbeat();
    _emitConnection(
      reconnecting
          ? OnlineConnectionStatusModel.reconnecting
          : OnlineConnectionStatusModel.connecting,
    );

    final session = await _validSession();
    final generation = ++_connectionGeneration;
    await _socketSubscription?.cancel();
    await _channel?.sink.close();
    _connectionReady = Completer<void>();
    _channel = WebSocketChannel.connect(
      Uri.parse(
        '${OnlineServerConstants.websocketBaseUrl}/rooms/$roomCode/connect',
      ),
    );
    _socketSubscription = _channel!.stream.listen(
      (raw) => _handleMessage(raw, generation),
      onError: (Object error, StackTrace stackTrace) {
        if (generation != _connectionGeneration) return;
        _socketAvailable = false;
        _stopHeartbeat();
        const exception = OnlineProtocolException(
          'socket_error',
          'The connection to the online server failed.',
        );
        _completeConnectionFailure(exception);
        _failPending(exception);
        _scheduleReconnect();
      },
      onDone: () {
        if (generation != _connectionGeneration) return;
        _socketAvailable = false;
        _stopHeartbeat();
        const exception = OnlineProtocolException(
          'socket_error',
          'The connection to the online server failed.',
        );
        _completeConnectionFailure(exception);
        _failPending(exception);
        _emitConnection(OnlineConnectionStatusModel.disconnected);
        if (!_intentionalClose) _scheduleReconnect();
      },
    );

    try {
      await _connectionReady!.future.timeout(
        OnlineServerConstants.commandTimeout,
        onTimeout: () => throw const OnlineProtocolException(
          'connection_timeout',
          'The online server did not answer in time.',
        ),
      );
      _socketAvailable = true;
      _emitConnection(OnlineConnectionStatusModel.authenticating);
      await _sendAndWait(
        type: 'authenticate',
        payload: {'accessToken': session.accessToken},
        expectedType: 'authenticated',
      );
      final snapshot = await _sendAndWait(
        type: commandType,
        payload: {'name': playerName, 'avatarId': avatarId},
        expectedType: 'room_snapshot',
      );
      final lobby = OnlineLobbyModel.fromProtocolMessage(snapshot);
      _canAutoReconnect = true;
      _reconnectAttempt = 0;
      _emitConnection(OnlineConnectionStatusModel.connected);
      _startHeartbeat();
      return lobby;
    } on Exception {
      if (generation == _connectionGeneration) {
        _connectionGeneration += 1;
        await _socketSubscription?.cancel();
        await _channel?.sink.close();
        _channel = null;
        _socketAvailable = false;
        _stopHeartbeat();
      }
      rethrow;
    }
  }

  Future<Session> _validSession() async {
    var session = _supabase.auth.currentSession;
    if (session == null) {
      final response = await _supabase.auth.signInAnonymously();
      session = response.session;
    }
    if (session == null) {
      throw const OnlineProtocolException(
        'authentication_failed',
        'Supabase could not create an anonymous player session.',
      );
    }
    if (session.isExpired) {
      final response = await _supabase.auth.refreshSession();
      session = response.session;
    }
    if (session == null) {
      throw const OnlineProtocolException(
        'authentication_failed',
        'The player session expired and could not be refreshed.',
      );
    }
    return session;
  }

  Future<Map<String, dynamic>> _sendAndWait({
    required String type,
    required Map<String, dynamic> payload,
    required String expectedType,
    int? expectedStateVersion,
  }) async {
    final actionId = _uuid.v4();
    final completer = Completer<Map<String, dynamic>>();
    _pendingCommands[actionId] = completer;
    try {
      _channel!.sink.add(jsonEncode({
        'protocolVersion': OnlineServerConstants.protocolVersion,
        'type': type,
        'actionId': actionId,
        if (expectedStateVersion != null)
          'expectedStateVersion': expectedStateVersion,
        'payload': payload,
      }));
      final message = await completer.future.timeout(
        OnlineServerConstants.commandTimeout,
        onTimeout: () => throw OnlineProtocolException(
          'command_timeout',
          'The server did not confirm $type in time.',
        ),
      );
      if (message['type'] != expectedType) {
        throw const OnlineProtocolException(
          'unexpected_response',
          'The server returned an unexpected response.',
        );
      }
      return message;
    } finally {
      _pendingCommands.remove(actionId);
    }
  }

  void _handleMessage(dynamic raw, int generation) {
    if (generation != _connectionGeneration || raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const OnlineProtocolException(
          'invalid_message',
          'The server returned an invalid message.',
        );
      }
      final type = decoded['type'];
      if (type == 'connection_ready') {
        if (!(_connectionReady?.isCompleted ?? true)) {
          _connectionReady!.complete();
        }
        return;
      }

      final actionId = decoded['actionId'];
      if (type == 'error') {
        final payload = decoded['payload'];
        final code = payload is Map<String, dynamic>
            ? payload['code'] as String? ?? 'server_error'
            : 'server_error';
        final message = payload is Map<String, dynamic>
            ? payload['message'] as String? ??
                'The online server rejected the request.'
            : 'The online server rejected the request.';
        final exception = OnlineProtocolException(code, message);
        if (actionId is String) {
          final pending = _pendingCommands[actionId];
          if (pending != null && !pending.isCompleted) {
            pending.completeError(exception);
            return;
          }
        }
        _updates.add(OnlineErrorUpdateModel(code, message));
        return;
      }

      if (actionId is String) {
        final pending = _pendingCommands[actionId];
        if (pending != null && !pending.isCompleted) {
          pending.complete(decoded);
        }
      }
      if (type == 'room_snapshot') {
        _updates.add(
          OnlineLobbyUpdateModel(
            OnlineLobbyModel.fromProtocolMessage(decoded),
          ),
        );
      }
    } on Exception catch (error) {
      _updates.add(OnlineErrorUpdateModel('invalid_message', error.toString()));
    }
  }

  void _scheduleReconnect() {
    if (_intentionalClose ||
        !_canAutoReconnect ||
        _roomCode == null ||
        _playerName == null ||
        _avatarId == null) {
      return;
    }
    if (_reconnectTimer?.isActive ?? false) return;
    final exponent = _reconnectAttempt > 5 ? 5 : _reconnectAttempt;
    final delay = Duration(seconds: 1 << exponent);
    _reconnectAttempt += 1;
    _emitConnection(OnlineConnectionStatusModel.reconnecting);
    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      try {
        await _connectAndEnter(
          roomCode: _roomCode!,
          playerName: _playerName!,
          avatarId: _avatarId!,
          commandType: 'resume_room',
          reconnecting: true,
          resetReconnectAttempts: false,
        );
      } on OnlineProtocolException catch (error) {
        if (_isTerminalResumeError(error.code)) {
          _canAutoReconnect = false;
          _emitConnection(OnlineConnectionStatusModel.disconnected);
          _updates.add(OnlineErrorUpdateModel(error.code, error.message));
        } else {
          _scheduleReconnect();
        }
      } on Exception {
        _scheduleReconnect();
      }
    });
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(
      OnlineServerConstants.heartbeatInterval,
      (_) => _sendHeartbeat(),
    );
  }

  Future<void> _sendHeartbeat() async {
    if (_heartbeatInFlight || !_socketAvailable || _channel == null) return;
    _heartbeatInFlight = true;
    try {
      await _sendAndWait(
        type: 'ping',
        payload: const {},
        expectedType: 'pong',
      );
    } on Exception {
      _socketAvailable = false;
      _stopHeartbeat();
      _emitConnection(OnlineConnectionStatusModel.reconnecting);
      await _channel?.sink.close();
      _scheduleReconnect();
    } finally {
      _heartbeatInFlight = false;
    }
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _emitConnection(OnlineConnectionStatusModel status) {
    if (!_updates.isClosed) {
      _updates.add(OnlineConnectionUpdateModel(status));
    }
  }

  void _failPending(Object error) {
    for (final completer in _pendingCommands.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pendingCommands.clear();
  }

  void _completeConnectionFailure(Object error) {
    final ready = _connectionReady;
    if (ready != null && !ready.isCompleted) ready.completeError(error);
  }

  bool _isTerminalResumeError(String code) {
    return code == 'room_not_found' ||
        code == 'player_not_found' ||
        code == 'game_in_progress' ||
        code == 'authentication_failed';
  }

  @override
  Future<void> leaveRoom() async {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    try {
      if (_channel != null && _roomCode != null && _socketAvailable) {
        await _sendAndWait(
          type: 'leave_room',
          payload: const {},
          expectedType: 'left_room',
        );
      }
    } finally {
      _roomCode = null;
      _playerName = null;
      _avatarId = null;
      _connectionGeneration += 1;
      await _socketSubscription?.cancel();
      await _channel?.sink.close();
      _channel = null;
      _socketAvailable = false;
      _canAutoReconnect = false;
      _reconnectAttempt = 0;
      _emitConnection(OnlineConnectionStatusModel.disconnected);
    }
  }

  @override
  Future<OnlineLobbyModel> startGame(int expectedStateVersion) {
    return _sendGameCommand(
      type: 'start_game',
      expectedStateVersion: expectedStateVersion,
    );
  }

  @override
  Future<OnlineLobbyModel> drawCard({
    required String targetUserId,
    required int cardIndex,
    required int expectedStateVersion,
  }) {
    return _sendGameCommand(
      type: 'draw_card',
      expectedStateVersion: expectedStateVersion,
      payload: {'targetUserId': targetUserId, 'cardIndex': cardIndex},
    );
  }

  @override
  Future<OnlineLobbyModel> shuffleHand(int expectedStateVersion) {
    return _sendGameCommand(
      type: 'shuffle_hand',
      expectedStateVersion: expectedStateVersion,
    );
  }

  @override
  Future<OnlineLobbyModel> startNewRound(int expectedStateVersion) {
    return _sendGameCommand(
      type: 'start_new_round',
      expectedStateVersion: expectedStateVersion,
    );
  }

  Future<OnlineLobbyModel> _sendGameCommand({
    required String type,
    required int expectedStateVersion,
    Map<String, dynamic> payload = const {},
  }) async {
    if (!_socketAvailable || _channel == null) {
      throw const OnlineProtocolException(
        'not_connected',
        'Connect to an online room before sending a game action.',
      );
    }
    final message = await _sendAndWait(
      type: type,
      payload: payload,
      expectedType: 'room_snapshot',
      expectedStateVersion: expectedStateVersion,
    );
    return OnlineLobbyModel.fromProtocolMessage(message);
  }
}
