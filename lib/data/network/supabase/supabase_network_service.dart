/// Data Layer - Supabase Network Service
///
/// Implementation of OnlineNetworkService using Supabase.
library;

import 'dart:async';
import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../connection_state.dart';
import '../network_exceptions.dart';
import '../online_events.dart';
import '../online_network_service.dart';
import 'supabase_channels.dart';

class SupabaseNetworkService implements OnlineNetworkService {
  SupabaseClient? _client;
  SupabaseChannels? _channels;

  // Use a broadcast stream for connection state to allow multiple listeners
  final _connectionStateController =
      StreamController<OnlineConnectionState>.broadcast();
  final _eventsController = StreamController<OnlineGameEvent>.broadcast();
  StreamSubscription? _channelStateSub;
  StreamSubscription? _channelEventSub;

  String? _currentRoomId;

  @override
  Stream<OnlineConnectionState> get connectionState =>
      _connectionStateController.stream;

  @override
  Stream<OnlineGameEvent> get gameEvents => _eventsController.stream;

  @override
  String? get currentUserId => _client?.auth.currentUser?.id;

  @override
  Future<void> initialize() async {
    try {
      // Initialize Supabase if not already
      // NOTE: Supabase.initialize usually happens in main.dart
      // Here we grab the instance or initialize a local client if DI is used differently

      // For this implementation, we assume Supabase.instance is available after main init,
      // OR we are provided the client via constructor/DI.
      // Since we need to register it in DI, we'll try to get the instance.

      try {
        _client = Supabase.instance.client;
      } catch (_) {
        // Fallback if not initialized globally yet (though it should be)
        await Supabase.initialize(
          url: SupabaseConstants.url,
          anonKey: SupabaseConstants.anonKey,
        );
        _client = Supabase.instance.client;
      }

      // Anonymous sign in if needed
      if (_client!.auth.currentUser == null) {
        await _client!.auth.signInAnonymously();
      }

      _channels = SupabaseChannels(_client!);

      // Forward channel streams
      _channelStateSub =
          _channels!.connectionState.listen(_connectionStateController.add);
      _channelEventSub = _channels!.events.listen(_eventsController.add);
    } catch (e) {
      log('Supabase init error: $e');
      throw NetworkException('Failed to initialize Supabase', e);
    }
  }

  @override
  Future<String> createRoom(Map<String, dynamic> initialGameState) async {
    if (_client == null || _channels == null) await initialize();
    final userId = _client!.auth.currentUser!.id;

    try {
      final roomId = initialGameState['roomCode'];
      // final hostId = initialGameState['hostId']; // NOT USED for DB ownership

      // Use the actual Supabase Auth ID for the database ownership
      // This ensures RLS policies work correctly (host_id = auth.uid())
      final dbHostId = userId;

      // 1. Create entry in Database
      await _client!.from('rooms').insert({
        'room_code': roomId,
        'host_id': dbHostId,
        'game_state': initialGameState,
        'status': 'waiting',
      });

      log('Room created in DB: $roomId');

      // 2. Subscribe to channel (for Presence + Realtime DB Updates)
      await _channels!.subscribeToRoom(roomId, userId, {
        'isHost': true,
        'name': initialGameState['hostName'] ?? 'Host',
        'id': initialGameState['hostId'],
      });

      _currentRoomId = roomId;
      return roomId;
    } catch (e) {
      log('Create Room Error: $e');
      throw RoomException('Failed to create room', e);
    }
  }

  @override
  Future<void> joinRoom(String roomId, Map<String, dynamic> playerData) async {
    if (_client == null || _channels == null) await initialize();
    final userId = _client!.auth.currentUser!.id;

    try {
      log('Joining room: $roomId');

      // 1. Fetch initial state from DB (Startup Sync)
      try {
        final roomData = await _client!
            .from('rooms')
            .select()
            .eq('room_code', roomId)
            .single();

        log('Fetched room data from DB: ${roomData['id']}');

        // Immediately notify listener of initial state
        if (roomData.containsKey('game_state')) {
          final state = roomData['game_state'] as Map<String, dynamic>;
          _eventsController.add(GenericGameEvent(
            type: OnlineEventTypes.stateSync,
            data: {'state': state},
            timestamp: DateTime.now(),
            senderId: 'system',
          ));
        }
      } catch (e) {
        log('Warning: Could not fetch initial room state from DB: $e');
        // Continue anyway, maybe it's a legacy room or transient
      }

      // 2. Subscribe to channel
      await _channels!.subscribeToRoom(roomId, userId, playerData);
      _currentRoomId = roomId;
    } catch (e) {
      throw RoomException('Failed to join room', e);
    }
  }

  @override
  Future<void> leaveRoom() async {
    if (_channels != null) {
      await _channels!.unsubscribe();
    }
    _currentRoomId = null;
  }

  @override
  Future<void> broadcastEvent(OnlineGameEvent event) async {
    if (_channels != null) {
      await _channels!.broadcastEvent(event);
    }
  }

  @override
  Future<void> updateState(Map<String, dynamic> stateData) async {
    if (_currentRoomId != null) {
      try {
        // Update the persistset state in Database
        // This triggers the Postgres Change event for all listeners
        log('SupabaseNetworkService: Updating state in DB for room $_currentRoomId');
        await _client!
            .from('rooms')
            .update({'game_state': stateData}).eq('room_code', _currentRoomId!);
      } catch (e) {
        log('Failed to update state in DB: $e');
        // Fallback or retry logic could go here
      }
    }
  }

  @override
  void dispose() {
    _channels?.dispose();
    _channelStateSub?.cancel();
    _channelEventSub?.cancel();
    _connectionStateController.close();
    _eventsController.close();
  }
}
