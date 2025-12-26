/// Data Layer - Supabase Channels
///
/// Manages Supabase Realtime channel subscriptions and event broadcasting.
library;

import 'dart:async';
import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../connection_state.dart';
import '../online_events.dart';
import 'supabase_mappers.dart';

class SupabaseChannels {
  final SupabaseClient _client;

  RealtimeChannel? _gameChannel;
  StreamSubscription? _statusSubscription;

  final _eventController = StreamController<OnlineGameEvent>.broadcast();
  final _connectionStateController =
      StreamController<OnlineConnectionState>.broadcast();

  SupabaseChannels(this._client);

  Stream<OnlineGameEvent> get events => _eventController.stream;
  Stream<OnlineConnectionState> get connectionState =>
      _connectionStateController.stream;

  /// Subscribe to a game room channel
  Future<void> subscribeToRoom(
      String roomId, String userId, Map<String, dynamic> playerData) async {
    if (_gameChannel != null) {
      await unsubscribe();
    }

    try {
      _connectionStateController.add(const OnlineConnectionState.connecting());

      final channelName = 'room:$roomId';
      _gameChannel = _client.channel(channelName);

      // Subscribe to broadcast events (game actions)
      _gameChannel!.onBroadcast(
        event: 'game_event',
        callback: (payload) {
          final event = SupabaseMappers.toOnlineEvent(payload);
          _eventController.add(event);
        },
      );

      // Subscribe to presence (joining/leaving)
      _gameChannel!.onPresenceSync((payload) {
        log('Presence Sync: $payload');
        // Presence sync logic can be complex, often safer to rely on explicit join events
        // or just use presence for "who is online" list.
        // For this implementation, we'll map presence joins to PlayerJoined events if needed.
      });

      _gameChannel!.onPresenceJoin((payload) {
        log('Presence Join: ${payload.newPresences}');
        // Map to PlayerJoined
        final newPresences = payload.newPresences;
        for (final presence in newPresences) {
          final presenceMap = presence.payload;
          // Ensure we don't process our own join as an event if it's echo'd
          // But usually we want to know we are online.
          _eventController.add(
            GenericGameEvent(
              type: OnlineEventTypes.playerJoined,
              data: Map<String, dynamic>.from(presenceMap),
              senderId: presenceMap['player_id'] as String?,
              timestamp: DateTime.now(),
            ),
          );
        }
      });

      _gameChannel!.onPresenceLeave((payload) {
        log('Presence Leave: ${payload.leftPresences}');
        final leftPresences = payload.leftPresences;
        for (final presence in leftPresences) {
          final presenceMap = presence.payload;
          _eventController.add(
            GenericGameEvent(
              type: OnlineEventTypes.playerLeft,
              data: Map<String, dynamic>.from(presenceMap),
              senderId: presenceMap['player_id'] as String?,
              timestamp: DateTime.now(),
            ),
          );
        }
      });

      // Subscribe
      _gameChannel!.subscribe();

      _connectionStateController.add(const OnlineConnectionState.connected());

      // Track presence
      await _gameChannel!.track({
        'player_id': userId,
        'online_at': DateTime.now().toIso8601String(),
        ...playerData,
      });
    } catch (e) {
      _connectionStateController.add(OnlineConnectionState.error(e.toString()));
      rethrow;
    }
  }

  /// Broadcast an event to the room
  Future<void> broadcastEvent(OnlineGameEvent event) async {
    if (_gameChannel == null) return;

    await _gameChannel!.sendBroadcastMessage(
      event: 'game_event',
      payload: event.toJson(),
    );
  }

  /// Unsubscribe from current channel
  Future<void> unsubscribe() async {
    if (_gameChannel != null) {
      await _client.removeChannel(_gameChannel!);
      _gameChannel = null;
      _connectionStateController
          .add(const OnlineConnectionState.disconnected());
    }
  }

  void dispose() {
    unsubscribe();
    _eventController.close();
    _connectionStateController.close();
    _statusSubscription?.cancel();
  }
}
