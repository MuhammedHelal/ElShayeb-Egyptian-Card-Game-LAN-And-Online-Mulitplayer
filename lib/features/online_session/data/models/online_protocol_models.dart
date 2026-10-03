import '../../domain/entities/online_lobby.dart';

class OnlineLobbyPlayerModel {
  final String userId;
  final String name;
  final String avatarId;
  final bool isConnected;

  const OnlineLobbyPlayerModel({
    required this.userId,
    required this.name,
    required this.avatarId,
    required this.isConnected,
  });

  factory OnlineLobbyPlayerModel.fromJson(Map<String, dynamic> json) {
    return OnlineLobbyPlayerModel(
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarId: json['avatarId'] as String? ?? '',
      isConnected: json['connected'] as bool? ?? false,
    );
  }

  OnlineLobbyPlayer toEntity() => OnlineLobbyPlayer(
        userId: userId,
        name: name,
        avatarId: avatarId,
        isConnected: isConnected,
      );
}

class OnlineLobbyModel {
  final String roomCode;
  final int stateVersion;
  final String localUserId;
  final bool canStart;
  final List<OnlineLobbyPlayerModel> players;

  const OnlineLobbyModel({
    required this.roomCode,
    required this.stateVersion,
    required this.localUserId,
    required this.canStart,
    required this.players,
  });

  factory OnlineLobbyModel.fromProtocolMessage(Map<String, dynamic> message) {
    final payload = message['payload'];
    if (payload is! Map<String, dynamic>) {
      throw const OnlineProtocolException(
        'invalid_snapshot',
        'The server sent an invalid lobby snapshot.',
      );
    }
    final rawPlayers = payload['players'];
    if (rawPlayers is! List) {
      throw const OnlineProtocolException(
        'invalid_snapshot',
        'The server lobby did not include a player list.',
      );
    }
    return OnlineLobbyModel(
      roomCode: payload['roomCode'] as String? ?? '',
      stateVersion: message['stateVersion'] as int? ?? 0,
      localUserId: payload['localUserId'] as String? ?? '',
      canStart: payload['canStart'] as bool? ?? false,
      players: rawPlayers
          .whereType<Map<String, dynamic>>()
          .map(OnlineLobbyPlayerModel.fromJson)
          .toList(growable: false),
    );
  }

  OnlineLobby toEntity() => OnlineLobby(
        roomCode: roomCode,
        stateVersion: stateVersion,
        localUserId: localUserId,
        canStart: canStart,
        players:
            players.map((player) => player.toEntity()).toList(growable: false),
      );
}

enum OnlineConnectionStatusModel {
  disconnected,
  connecting,
  authenticating,
  connected,
  reconnecting,
}

sealed class OnlineSessionUpdateModel {
  const OnlineSessionUpdateModel();
}

class OnlineConnectionUpdateModel extends OnlineSessionUpdateModel {
  final OnlineConnectionStatusModel status;

  const OnlineConnectionUpdateModel(this.status);
}

class OnlineLobbyUpdateModel extends OnlineSessionUpdateModel {
  final OnlineLobbyModel lobby;

  const OnlineLobbyUpdateModel(this.lobby);
}

class OnlineErrorUpdateModel extends OnlineSessionUpdateModel {
  final String code;
  final String message;

  const OnlineErrorUpdateModel(this.code, this.message);
}

class OnlineProtocolException implements Exception {
  final String code;
  final String message;

  const OnlineProtocolException(this.code, this.message);

  @override
  String toString() => message;
}
