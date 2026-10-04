import 'package:dartz/dartz.dart';

import '../../../../core/networking/async_result.dart';
import '../../domain/entities/online_lobby.dart';
import '../../domain/repos/online_session_repository.dart';
import '../datasources/online_session_local_data_source.dart';
import '../datasources/online_session_remote_data_source.dart';
import '../models/online_protocol_models.dart';

class OnlineSessionRepositoryImpl implements OnlineSessionRepository {
  final OnlineSessionRemoteDataSource _remoteDataSource;
  final OnlineSessionLocalDataSource _localDataSource;

  const OnlineSessionRepositoryImpl(
    this._remoteDataSource,
    this._localDataSource,
  );

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
      () async {
        final lobby = await _remoteDataSource.createRoom(
          playerName: playerName,
          avatarId: avatarId,
        );
        await _saveSession(lobby.roomCode, playerName, avatarId);
        return lobby.toEntity();
      },
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
      () async {
        final lobby = await _remoteDataSource.joinRoom(
          roomCode: roomCode,
          playerName: playerName,
          avatarId: avatarId,
        );
        await _saveSession(lobby.roomCode, playerName, avatarId);
        return lobby.toEntity();
      },
      mapFailure: _mapFailure,
    );
  }

  @override
  Future<FailureOrSuccess<OnlineLobby?>> restoreSession() {
    return executeAndHandleErrorsAsyncWrapper(
      () async {
        final saved = _localDataSource.read();
        if (saved == null) return null;
        return _resumeSavedSession(saved);
      },
      mapFailure: _mapFailure,
    );
  }

  @override
  Future<FailureOrSuccess<OnlineLobby>> reconnect() {
    return executeAndHandleErrorsAsyncWrapper(
      () async {
        final saved = _localDataSource.read();
        if (saved == null) {
          throw const OnlineProtocolException(
            'no_saved_room',
            'There is no saved online room to reconnect to.',
          );
        }
        return _resumeSavedSession(saved);
      },
      mapFailure: _mapFailure,
    );
  }

  @override
  Future<FailureOrSuccess<Unit>> leaveRoom() {
    return executeAndHandleErrorsAsyncWrapper(
      () async {
        try {
          await _remoteDataSource.leaveRoom();
          return unit;
        } finally {
          await _localDataSource.clear();
        }
      },
      mapFailure: _mapFailure,
    );
  }

  Future<void> _saveSession(
    String roomCode,
    String playerName,
    String avatarId,
  ) {
    return _localDataSource.save(SavedOnlineSession(
      roomCode: roomCode,
      playerName: playerName,
      avatarId: avatarId,
    ));
  }

  Future<OnlineLobby> _resumeSavedSession(SavedOnlineSession saved) async {
    try {
      return (await _remoteDataSource.resumeRoom(
        roomCode: saved.roomCode,
        playerName: saved.playerName,
        avatarId: saved.avatarId,
      ))
          .toEntity();
    } on OnlineProtocolException catch (error) {
      if (error.code == 'room_not_found' ||
          error.code == 'player_not_found' ||
          error.code == 'game_in_progress') {
        await _localDataSource.clear();
      }
      rethrow;
    }
  }

  @override
  Future<FailureOrSuccess<OnlineLobby>> startGame(int expectedStateVersion) {
    return _runRoomCommand(
      () => _remoteDataSource.startGame(expectedStateVersion),
    );
  }

  @override
  Future<FailureOrSuccess<OnlineLobby>> drawCard({
    required String targetUserId,
    required int cardIndex,
    required int expectedStateVersion,
  }) {
    return _runRoomCommand(
      () => _remoteDataSource.drawCard(
        targetUserId: targetUserId,
        cardIndex: cardIndex,
        expectedStateVersion: expectedStateVersion,
      ),
    );
  }

  @override
  Future<FailureOrSuccess<OnlineLobby>> shuffleHand(int expectedStateVersion) {
    return _runRoomCommand(
      () => _remoteDataSource.shuffleHand(expectedStateVersion),
    );
  }

  @override
  Future<FailureOrSuccess<OnlineLobby>> startNewRound(
    int expectedStateVersion,
  ) {
    return _runRoomCommand(
      () => _remoteDataSource.startNewRound(expectedStateVersion),
    );
  }

  Future<FailureOrSuccess<OnlineLobby>> _runRoomCommand(
    Future<OnlineLobbyModel> Function() command,
  ) {
    return executeAndHandleErrorsAsyncWrapper(
      () async => (await command()).toEntity(),
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
