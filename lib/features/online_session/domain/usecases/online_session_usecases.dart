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

class LeaveOnlineRoomUseCase {
  final OnlineSessionRepository _repository;

  const LeaveOnlineRoomUseCase(this._repository);

  Future<FailureOrSuccess<Unit>> call() => _repository.leaveRoom();
}
