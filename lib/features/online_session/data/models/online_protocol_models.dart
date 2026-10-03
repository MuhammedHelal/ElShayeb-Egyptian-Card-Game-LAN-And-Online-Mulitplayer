import '../../domain/entities/online_lobby.dart';

class OnlinePlayingCardModel {
  final String id;
  final OnlineCardSuit suit;
  final int rank;

  const OnlinePlayingCardModel({
    required this.id,
    required this.suit,
    required this.rank,
  });

  factory OnlinePlayingCardModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final suit = _parseEnum(OnlineCardSuit.values, json['suit']);
    final rank = json['rank'];
    if (id is! String ||
        id.isEmpty ||
        suit == null ||
        rank is! int ||
        rank < 1 ||
        rank > 13) {
      throw const OnlineProtocolException(
        'invalid_snapshot',
        'The server sent an invalid card.',
      );
    }
    return OnlinePlayingCardModel(id: id, suit: suit, rank: rank);
  }

  OnlinePlayingCard toEntity() =>
      OnlinePlayingCard(id: id, suit: suit, rank: rank);
}

class OnlineLobbyPlayerModel {
  final String userId;
  final String name;
  final String avatarId;
  final bool isConnected;
  final int cardCount;
  final int score;
  final OnlinePlayerStatus status;
  final int finishPosition;
  final List<OnlinePlayingCardModel>? hand;

  const OnlineLobbyPlayerModel({
    required this.userId,
    required this.name,
    required this.avatarId,
    required this.isConnected,
    required this.cardCount,
    required this.score,
    required this.status,
    required this.finishPosition,
    required this.hand,
  });

  factory OnlineLobbyPlayerModel.fromJson(Map<String, dynamic> json) {
    final userId = json['userId'];
    final name = json['name'];
    final avatarId = json['avatarId'];
    final isConnected = json['connected'];
    final cardCount = json['cardCount'];
    final score = json['score'];
    final status = _parseEnum(OnlinePlayerStatus.values, json['status']);
    final finishPosition = json['finishPosition'];
    final rawHand = json['hand'];
    if (userId is! String ||
        userId.isEmpty ||
        name is! String ||
        name.isEmpty ||
        avatarId is! String ||
        avatarId.isEmpty ||
        isConnected is! bool ||
        cardCount is! int ||
        cardCount < 0 ||
        score is! int ||
        status == null ||
        finishPosition is! int ||
        finishPosition < 0 ||
        (rawHand != null && rawHand is! List)) {
      throw const OnlineProtocolException(
        'invalid_snapshot',
        'The server lobby included an invalid player.',
      );
    }
    final List<OnlinePlayingCardModel>? hand = rawHand == null
        ? null
        : rawHand.map<OnlinePlayingCardModel>((card) {
            if (card is! Map<String, dynamic>) {
              throw const OnlineProtocolException(
                'invalid_snapshot',
                'The server sent an invalid card.',
              );
            }
            return OnlinePlayingCardModel.fromJson(card);
          }).toList(growable: false);
    if (hand != null && hand.length != cardCount) {
      throw const OnlineProtocolException(
        'invalid_snapshot',
        'The private hand did not match its public card count.',
      );
    }
    return OnlineLobbyPlayerModel(
      userId: userId,
      name: name,
      avatarId: avatarId,
      isConnected: isConnected,
      cardCount: cardCount,
      score: score,
      status: status,
      finishPosition: finishPosition,
      hand: hand,
    );
  }

  OnlineLobbyPlayer toEntity() => OnlineLobbyPlayer(
        userId: userId,
        name: name,
        avatarId: avatarId,
        isConnected: isConnected,
        cardCount: cardCount,
        score: score,
        status: status,
        finishPosition: finishPosition,
        hand: hand?.map((card) => card.toEntity()).toList(growable: false),
      );
}

class OnlineGameActionModel {
  final OnlineGameActionType type;
  final String actorUserId;
  final String? targetUserId;
  final bool? madePair;
  final OnlinePlayingCardModel? drawnCard;

  const OnlineGameActionModel({
    required this.type,
    required this.actorUserId,
    required this.targetUserId,
    required this.madePair,
    required this.drawnCard,
  });

  factory OnlineGameActionModel.fromJson(Map<String, dynamic> json) {
    final type = _parseEnum(OnlineGameActionType.values, json['type']);
    final actorUserId = json['actorUserId'];
    final targetUserId = json['targetUserId'];
    final madePair = json['madePair'];
    final rawCard = json['drawnCard'];
    if (type == null ||
        actorUserId is! String ||
        actorUserId.isEmpty ||
        (targetUserId != null && targetUserId is! String) ||
        (madePair != null && madePair is! bool) ||
        (rawCard != null && rawCard is! Map<String, dynamic>)) {
      throw const OnlineProtocolException(
        'invalid_snapshot',
        'The server sent an invalid action summary.',
      );
    }
    return OnlineGameActionModel(
      type: type,
      actorUserId: actorUserId,
      targetUserId: targetUserId as String?,
      madePair: madePair as bool?,
      drawnCard:
          rawCard == null ? null : OnlinePlayingCardModel.fromJson(rawCard),
    );
  }

  OnlineGameAction toEntity() => OnlineGameAction(
        type: type,
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        madePair: madePair,
        drawnCard: drawnCard?.toEntity(),
      );
}

class OnlineLobbyModel {
  final String roomCode;
  final int stateVersion;
  final String localUserId;
  final OnlineRoomPhase phase;
  final bool canStart;
  final bool canStartNewRound;
  final String? currentPlayerUserId;
  final String? drawFromUserId;
  final int roundNumber;
  final OnlineGameActionModel? lastAction;
  final List<OnlineLobbyPlayerModel> players;

  const OnlineLobbyModel({
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

  factory OnlineLobbyModel.fromProtocolMessage(Map<String, dynamic> message) {
    final payload = message['payload'];
    if (payload is! Map<String, dynamic>) return _invalidSnapshot();
    final rawPlayers = payload['players'];
    final roomCode = payload['roomCode'];
    final stateVersion = message['stateVersion'];
    final localUserId = payload['localUserId'];
    final phase = _parseEnum(OnlineRoomPhase.values, payload['phase']);
    final canStart = payload['canStart'];
    final canStartNewRound = payload['canStartNewRound'];
    final currentPlayerUserId = payload['currentPlayerUserId'];
    final drawFromUserId = payload['drawFromUserId'];
    final roundNumber = payload['roundNumber'];
    final rawLastAction = payload['lastAction'];
    if (message['type'] != 'room_snapshot' ||
        rawPlayers is! List ||
        roomCode is! String ||
        !RegExp(r'^[A-Z0-9]{6}$').hasMatch(roomCode) ||
        stateVersion is! int ||
        stateVersion < 0 ||
        localUserId is! String ||
        localUserId.isEmpty ||
        phase == null ||
        canStart is! bool ||
        canStartNewRound is! bool ||
        (currentPlayerUserId != null && currentPlayerUserId is! String) ||
        (drawFromUserId != null && drawFromUserId is! String) ||
        roundNumber is! int ||
        roundNumber < 1 ||
        (rawLastAction != null && rawLastAction is! Map<String, dynamic>)) {
      return _invalidSnapshot();
    }
    final players = rawPlayers.map((player) {
      if (player is! Map<String, dynamic>) return _invalidPlayer();
      return OnlineLobbyPlayerModel.fromJson(player);
    }).toList(growable: false);
    if (!players
        .any((player) => player.userId == localUserId && player.hand != null)) {
      return _invalidSnapshot();
    }
    if (players.any(
      (player) => player.userId != localUserId && player.hand != null,
    )) {
      return _invalidSnapshot();
    }
    return OnlineLobbyModel(
      roomCode: roomCode,
      stateVersion: stateVersion,
      localUserId: localUserId,
      phase: phase,
      canStart: canStart,
      canStartNewRound: canStartNewRound,
      currentPlayerUserId: currentPlayerUserId as String?,
      drawFromUserId: drawFromUserId as String?,
      roundNumber: roundNumber,
      lastAction: rawLastAction == null
          ? null
          : OnlineGameActionModel.fromJson(rawLastAction),
      players: players,
    );
  }

  OnlineLobby toEntity() => OnlineLobby(
        roomCode: roomCode,
        stateVersion: stateVersion,
        localUserId: localUserId,
        phase: phase,
        canStart: canStart,
        canStartNewRound: canStartNewRound,
        currentPlayerUserId: currentPlayerUserId,
        drawFromUserId: drawFromUserId,
        roundNumber: roundNumber,
        lastAction: lastAction?.toEntity(),
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

T? _parseEnum<T extends Enum>(List<T> values, Object? rawValue) {
  if (rawValue is! String) return null;
  final normalized = rawValue.replaceAllMapped(
    RegExp(r'_([a-z])'),
    (match) => match.group(1)!.toUpperCase(),
  );
  for (final value in values) {
    if (value.name == normalized) return value;
  }
  return null;
}

Never _invalidSnapshot() => throw const OnlineProtocolException(
      'invalid_snapshot',
      'The server sent an incomplete room snapshot.',
    );

Never _invalidPlayer() => throw const OnlineProtocolException(
      'invalid_snapshot',
      'The server room included an invalid player.',
    );
