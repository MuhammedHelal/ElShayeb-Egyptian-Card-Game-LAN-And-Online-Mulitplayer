import 'package:dartz/dartz.dart';

import '../../../../core/networking/async_result.dart';
import '../../domain/entities/online_lobby.dart';
import '../../domain/repos/online_session_repository.dart';
import '../datasources/online_session_remote_data_source.dart';
import '../models/online_protocol_models.dart';

class OnlineSessionRepositoryImpl implements OnlineSessionRepository {
  final OnlineSessionRemoteDataSource _remoteDataSource;

  const OnlineSessionRepositoryImpl(this._remoteDataSource);

  @override
  Stream<OnlineSessionUpdate> observe() {
    return _remoteDataSource.observe().map(_mapUpdate);
  }

  @override
  Future<FailureOrSuccess<OnlineLobby>> createRoom({
    required String playerName,
    required String avatarId,
  }) {
    return executeAndHandleErrorsAsyncWrapper(
      () async => (await _remoteDataSource.createRoom(
        playerName: playerName,
        avatarId: avatarId,
      ))
          .toEntity(),
      mapFailure: _mapFailure,
    );
  }

  @override
  Future<FailureOrSuccess<OnlineLobby>> joinRoom({
    required String roomCode,
    required String playerName,
    required String avatarId,
  }) {
    return executeAndHandleErrorsAsyncWrapper(
      () async => (await _remoteDataSource.joinRoom(
        roomCode: roomCode,
        playerName: playerName,
        avatarId: avatarId,
      ))
          .toEntity(),
      mapFailure: _mapFailure,
    );
  }

  @override
  Future<FailureOrSuccess<Unit>> leaveRoom() {
    return executeAndHandleErrorsAsyncWrapper(
      () async {
        await _remoteDataSource.leaveRoom();
        return unit;
      },
      mapFailure: _mapFailure,
    );
  }

  OnlineSessionUpdate _mapUpdate(OnlineSessionUpdateModel update) {
    return switch (update) {
      OnlineConnectionUpdateModel(:final status) =>
        OnlineConnectionUpdated(_mapConnectionStatus(status)),
      OnlineLobbyUpdateModel(:final lobby) =>
        OnlineLobbyUpdated(lobby.toEntity()),
      OnlineErrorUpdateModel(:final code, :final message) =>
        OnlineSessionRejected(message, code: code),
    };
  }

  OnlineServerConnectionStatus _mapConnectionStatus(
    OnlineConnectionStatusModel status,
  ) {
    return switch (status) {
      OnlineConnectionStatusModel.disconnected =>
        OnlineServerConnectionStatus.disconnected,
      OnlineConnectionStatusModel.connecting =>
        OnlineServerConnectionStatus.connecting,
      OnlineConnectionStatusModel.authenticating =>
        OnlineServerConnectionStatus.authenticating,
      OnlineConnectionStatusModel.connected =>
        OnlineServerConnectionStatus.connected,
      OnlineConnectionStatusModel.reconnecting =>
        OnlineServerConnectionStatus.reconnecting,
    };
  }

  AppFailure _mapFailure(Exception error) {
    if (error is OnlineProtocolException) {
      return AppFailure(error.message, code: error.code);
    }
    return AppFailure(error.toString());
  }
}
