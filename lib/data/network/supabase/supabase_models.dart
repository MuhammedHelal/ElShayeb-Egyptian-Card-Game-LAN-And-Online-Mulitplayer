/// Data Layer - Supabase Models
///
/// DTOs for Supabase interactions.
library;

class SupabaseEvent {
  final String type;
  final Map<String, dynamic> payload;

  SupabaseEvent({
    required this.type,
    required this.payload,
  });

  factory SupabaseEvent.fromJson(Map<String, dynamic> json) {
    return SupabaseEvent(
      type: json['type'] as String,
      payload: json['payload'] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'payload': payload,
    };
  }
}

class SupabaseRoom {
  final String id;
  final String hostId;
  final Map<String, dynamic> state;
  final DateTime createdAt;

  SupabaseRoom({
    required this.id,
    required this.hostId,
    required this.state,
    required this.createdAt,
  });

  factory SupabaseRoom.fromJson(Map<String, dynamic> json) {
    return SupabaseRoom(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      state: json['state'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
