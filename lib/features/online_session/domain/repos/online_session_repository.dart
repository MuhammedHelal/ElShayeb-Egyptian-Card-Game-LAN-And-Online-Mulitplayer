import 'package:dartz/dartz.dart';

import '../../../../core/networking/async_result.dart';
import '../entities/online_lobby.dart';

abstract class OnlineSessionRepository {
  Stream<OnlineSessionUpdate> observe();

  Future<FailureOrSuccess<OnlineLobby>> createRoom({
    required String playerName,
    required String avatarId,
  });

  Future<FailureOrSuccess<OnlineLobby>> joinRoom({
    required String roomCode,
    required String playerName,
    required String avatarId,
  });

  Future<FailureOrSuccess<OnlineLobby?>> restoreSession();

  Future<FailureOrSuccess<OnlineLobby>> reconnect();

  Future<FailureOrSuccess<Unit>> leaveRoom();

  Future<FailureOrSuccess<OnlineLobby>> startGame(int expectedStateVersion);

  Future<FailureOrSuccess<OnlineLobby>> drawCard({
    required String targetUserId,
    required int cardIndex,
    required int expectedStateVersion,
  });

  Future<FailureOrSuccess<OnlineLobby>> shuffleHand(int expectedStateVersion);

  Future<FailureOrSuccess<OnlineLobby>> startNewRound(int expectedStateVersion);
}
