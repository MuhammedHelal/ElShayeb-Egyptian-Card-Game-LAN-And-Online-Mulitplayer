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

  Future<FailureOrSuccess<Unit>> leaveRoom();
}
