/// Data Layer - Supabase Mappers
///
/// Transforming Supabase events to Domain events.
library;

import '../online_events.dart';

class SupabaseMappers {
  static OnlineGameEvent toOnlineEvent(Map<String, dynamic> payload) {
    // Handling "broadcast" events from Supabase Realtime
    // The structure depends on how we send it.
    // Assuming pattern: { "event": "broadcast", "payload": { "type": "...", "data": ..., "senderId": "..." } }

    // Direct mapping if the payload matches our event structure
    var type = payload['type'] as String;
    // Fix: Supabase Realtime overrides 'type' with 'broadcast'.
    // We Map 'broadcast' back to our internal 'game_action' type if it's the right event.
    if (type == 'broadcast' && payload['event'] == 'game_event') {
      type = OnlineEventTypes.gameAction;
    }

    final data = payload['data'] as Map<String, dynamic>? ?? {};
    final senderId = payload['senderId'] as String?;
    final timestampStr = payload['timestamp'] as String?;
    final timestamp =
        timestampStr != null ? DateTime.parse(timestampStr) : DateTime.now();

    return GenericGameEvent(
      type: type,
      data: data,
      senderId: senderId,
      timestamp: timestamp,
    );
  }

  static OnlineGameEvent fromPresenceJoin(
      String key, Map<String, dynamic> presenceState) {
    // Extract player info from presence
    return GenericGameEvent(
      type: OnlineEventTypes.playerJoined,
      data: presenceState,
      senderId: key,
      timestamp: DateTime.now(),
    );
  }

  static OnlineGameEvent fromPresenceLeave(
      String key, Map<String, dynamic> presenceState) {
    return GenericGameEvent(
      type: OnlineEventTypes.playerLeft,
      data: presenceState,
      senderId: key,
      timestamp: DateTime.now(),
    );
  }
}
