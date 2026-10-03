import 'package:equatable/equatable.dart';

enum OnlineRoomPhase { lobby, playing, roundEnd }

enum OnlinePlayerStatus { playing, finished, shayeb }

enum OnlineCardSuit { hearts, diamonds, clubs, spades }

enum OnlineGameActionType { gameStarted, cardDrawn, handShuffled, roundStarted }

class OnlinePlayingCard extends Equatable {
  final String id;
  final OnlineCardSuit suit;
  final int rank;

  const OnlinePlayingCard({
    required this.id,
    required this.suit,
    required this.rank,
  });

  String get label {
    const ranks = <int, String>{1: 'A', 11: 'J', 12: 'Q', 13: 'K'};
    const suits = <OnlineCardSuit, String>{
      OnlineCardSuit.hearts: '♥',
      OnlineCardSuit.diamonds: '♦',
      OnlineCardSuit.clubs: '♣',
      OnlineCardSuit.spades: '♠',
    };
    return '${ranks[rank] ?? rank}${suits[suit]}';
  }

  @override
  List<Object?> get props => [id, suit, rank];
}

class OnlineGameAction extends Equatable {
  final OnlineGameActionType type;
  final String actorUserId;
  final String? targetUserId;
  final bool? madePair;
  final OnlinePlayingCard? drawnCard;

  const OnlineGameAction({
    required this.type,
    required this.actorUserId,
    this.targetUserId,
    this.madePair,
    this.drawnCard,
  });

  @override
  List<Object?> get props => [
        type,
        actorUserId,
        targetUserId,
        madePair,
        drawnCard,
      ];
}

class OnlineLobbyPlayer extends Equatable {
  final String userId;
  final String name;
  final String avatarId;
  final bool isConnected;
  final int cardCount;
  final int score;
  final OnlinePlayerStatus status;
  final int finishPosition;
  final List<OnlinePlayingCard>? hand;

  const OnlineLobbyPlayer({
    required this.userId,
    required this.name,
    required this.avatarId,
    required this.isConnected,
    required this.cardCount,
    required this.score,
    required this.status,
    required this.finishPosition,
    this.hand,
  });

  @override
  List<Object?> get props => [
        userId,
        name,
        avatarId,
        isConnected,
        cardCount,
        score,
        status,
        finishPosition,
        hand,
      ];
}

class OnlineLobby extends Equatable {
  final String roomCode;
  final int stateVersion;
  final String localUserId;
  final OnlineRoomPhase phase;
  final bool canStart;
  final bool canStartNewRound;
  final String? currentPlayerUserId;
  final String? drawFromUserId;
  final int roundNumber;
  final OnlineGameAction? lastAction;
  final List<OnlineLobbyPlayer> players;

  const OnlineLobby({
    required this.roomCode,
    required this.stateVersion,
    required this.localUserId,
    required this.phase,
    required this.canStart,
    required this.canStartNewRound,
    required this.currentPlayerUserId,
    required this.drawFromUserId,
    required this.roundNumber,
    required this.lastAction,
    required this.players,
  });

  OnlineLobbyPlayer? get localPlayer => _playerById(localUserId);

  OnlineLobbyPlayer? get drawFromPlayer =>
      drawFromUserId == null ? null : _playerById(drawFromUserId!);

  bool get isMyTurn => currentPlayerUserId == localUserId;

  OnlineLobbyPlayer? _playerById(String userId) {
    for (final player in players) {
      if (player.userId == userId) return player;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        roomCode,
        stateVersion,
        localUserId,
        phase,
        canStart,
        canStartNewRound,
        currentPlayerUserId,
        drawFromUserId,
        roundNumber,
        lastAction,
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
