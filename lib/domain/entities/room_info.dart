/// Domain Layer - Room Info Entity
///
/// Represents discoverable room information for LAN lobby browsing.
library;

import 'package:equatable/equatable.dart';

/// Room information for discovery
class RoomInfo extends Equatable {
  final String roomId;
  final String roomCode;
  final String hostName;
  final String hostAddress;
  final int port;
  final int playerCount;
  final int maxPlayers;
  final bool isStarted;

  const RoomInfo({
    required this.roomId,
    required this.roomCode,
    required this.hostName,
    required this.hostAddress,
    required this.port,
    required this.playerCount,
    this.maxPlayers = 6,
    this.isStarted = false,
  });

  /// Check if room can be joined
  bool get canJoin => !isStarted && playerCount < maxPlayers;

  /// Display string for player count
  String get playerCountDisplay => '$playerCount/$maxPlayers';

  @override
  List<Object?> get props => [
        roomId,
        roomCode,
        hostName,
        hostAddress,
        port,
        playerCount,
        maxPlayers,
        isStarted,
      ];

  /// Convert to JSON for mDNS TXT records
  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'roomCode': roomCode,
        'hostName': hostName,
        'hostAddress': hostAddress,
        'port': port,
        'playerCount': playerCount,
        'maxPlayers': maxPlayers,
        'isStarted': isStarted,
      };

  /// Create from JSON
  factory RoomInfo.fromJson(Map<String, dynamic> json) {
    return RoomInfo(
      roomId: json['roomId'] as String,
      roomCode: json['roomCode'] as String,
      hostName: json['hostName'] as String,
      hostAddress: json['hostAddress'] as String,
      port: json['port'] as int,
      playerCount: json['playerCount'] as int,
      maxPlayers: json['maxPlayers'] as int? ?? 6,
      isStarted: json['isStarted'] as bool? ?? false,
    );
  }
}
