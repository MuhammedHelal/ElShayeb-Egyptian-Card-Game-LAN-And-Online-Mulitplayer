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
      // Pure Realtime: No Database Insert requires.
      // The room exists purely as a transient Realtime channel.
      final roomId =
          initialGameState['roomCode']; // Use the code from game logic

      // Subscribe to channel
      await _channels!.subscribeToRoom(roomId, userId, {
        'isHost': true,
        'name': initialGameState['hostName'] ?? 'Host',
      });

      _currentRoomId = roomId;
      return roomId;
    } catch (e) {
      throw RoomException('Failed to create room', e);
    }
  }

  @override
  Future<void> joinRoom(String roomId, Map<String, dynamic> playerData) async {
    if (_client == null || _channels == null) await initialize();
    final userId = _client!.auth.currentUser!.id;

    try {
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
    if (_channels != null && _currentRoomId != null) {
      try {
        await _channels!.broadcastEvent(GenericGameEvent(
          type: OnlineEventTypes.stateSync,
          data: {'state': stateData},
          timestamp: DateTime.now(),
          senderId: currentUserId,
        ));
      } catch (e) {
        log('Failed to update state: $e');
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
