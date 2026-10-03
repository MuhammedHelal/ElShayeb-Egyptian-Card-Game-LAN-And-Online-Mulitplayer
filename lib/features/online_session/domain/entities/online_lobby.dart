import 'package:equatable/equatable.dart';

class OnlineLobbyPlayer extends Equatable {
  final String userId;
  final String name;
  final String avatarId;
  final bool isConnected;

  const OnlineLobbyPlayer({
    required this.userId,
    required this.name,
    required this.avatarId,
    required this.isConnected,
  });

  @override
  List<Object?> get props => [userId, name, avatarId, isConnected];
}

class OnlineLobby extends Equatable {
  final String roomCode;
  final int stateVersion;
  final String localUserId;
  final bool canStart;
  final List<OnlineLobbyPlayer> players;

  const OnlineLobby({
    required this.roomCode,
    required this.stateVersion,
    required this.localUserId,
    required this.canStart,
    required this.players,
  });

  @override
  List<Object?> get props => [
        roomCode,
        stateVersion,
        localUserId,
        canStart,
        players,
      ];
}

enum OnlineServerConnectionStatus {
  disconnected,
  connecting,
  authenticating,
  connected,
  reconnecting,
}

sealed class OnlineSessionUpdate {
  const OnlineSessionUpdate();
}

class OnlineConnectionUpdated extends OnlineSessionUpdate {
  final OnlineServerConnectionStatus status;

  const OnlineConnectionUpdated(this.status);
}

class OnlineLobbyUpdated extends OnlineSessionUpdate {
  final OnlineLobby lobby;

  const OnlineLobbyUpdated(this.lobby);
}

class OnlineSessionRejected extends OnlineSessionUpdate {
  final String message;
  final String? code;

  const OnlineSessionRejected(this.message, {this.code});
}
