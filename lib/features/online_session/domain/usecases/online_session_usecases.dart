import 'package:dartz/dartz.dart';

import '../../../../core/networking/async_result.dart';
import '../entities/online_lobby.dart';
import '../repos/online_session_repository.dart';

class ObserveOnlineSessionUseCase {
  final OnlineSessionRepository _repository;

  const ObserveOnlineSessionUseCase(this._repository);

  Stream<OnlineSessionUpdate> call() => _repository.observe();
}

class CreateOnlineRoomUseCase {
  final OnlineSessionRepository _repository;

  const CreateOnlineRoomUseCase(this._repository);

  Future<FailureOrSuccess<OnlineLobby>> call({
    required String playerName,
    required String avatarId,
  }) =>
      _repository.createRoom(playerName: playerName, avatarId: avatarId);
}

class JoinOnlineRoomUseCase {
  final OnlineSessionRepository _repository;

  const JoinOnlineRoomUseCase(this._repository);

  Future<FailureOrSuccess<OnlineLobby>> call({
    required String roomCode,
    required String playerName,
    required String avatarId,
  }) =>
      _repository.joinRoom(
        roomCode: roomCode,
        playerName: playerName,
        avatarId: avatarId,
      );
}

class RestoreOnlineSessionUseCase {
  final OnlineSessionRepository _repository;

  const RestoreOnlineSessionUseCase(this._repository);

  Future<FailureOrSuccess<OnlineLobby?>> call() => _repository.restoreSession();
}

class ReconnectOnlineSessionUseCase {
  final OnlineSessionRepository _repository;

  const ReconnectOnlineSessionUseCase(this._repository);

  Future<FailureOrSuccess<OnlineLobby>> call() => _repository.reconnect();
}

class LeaveOnlineRoomUseCase {
  final OnlineSessionRepository _repository;

  const LeaveOnlineRoomUseCase(this._repository);

  Future<FailureOrSuccess<Unit>> call() => _repository.leaveRoom();
}

class StartOnlineGameUseCase {
  final OnlineSessionRepository _repository;

  const StartOnlineGameUseCase(this._repository);

  Future<FailureOrSuccess<OnlineLobby>> call(int expectedStateVersion) =>
      _repository.startGame(expectedStateVersion);
}

class DrawOnlineCardUseCase {
  final OnlineSessionRepository _repository;

  const DrawOnlineCardUseCase(this._repository);

  Future<FailureOrSuccess<OnlineLobby>> call({
    required String targetUserId,
    required int cardIndex,
    required int expectedStateVersion,
  }) =>
      _repository.drawCard(
        targetUserId: targetUserId,
        cardIndex: cardIndex,
        expectedStateVersion: expectedStateVersion,
      );
}

class ShuffleOnlineHandUseCase {
  final OnlineSessionRepository _repository;

  const ShuffleOnlineHandUseCase(this._repository);

  Future<FailureOrSuccess<OnlineLobby>> call(int expectedStateVersion) =>
      _repository.shuffleHand(expectedStateVersion);
}

class StartOnlineRoundUseCase {
  final OnlineSessionRepository _repository;

  const StartOnlineRoundUseCase(this._repository);

  Future<FailureOrSuccess<OnlineLobby>> call(int expectedStateVersion) =>
      _repository.startNewRound(expectedStateVersion);
}
