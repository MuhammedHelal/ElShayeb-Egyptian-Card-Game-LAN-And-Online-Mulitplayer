import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:elshayeb/core/networking/async_result.dart';
import 'package:elshayeb/features/online_session/domain/domain.dart';
import 'package:elshayeb/features/online_session/presentation/cubit/online_session_cubit.dart';
import 'package:elshayeb/features/online_session/presentation/cubit/online_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeOnlineSessionRepository repository;
  late OnlineSessionCubit cubit;

  setUp(() {
    repository = _FakeOnlineSessionRepository();
    cubit = OnlineSessionCubit(
      observeOnlineSession: ObserveOnlineSessionUseCase(repository),
      createOnlineRoom: CreateOnlineRoomUseCase(repository),
      joinOnlineRoom: JoinOnlineRoomUseCase(repository),
      leaveOnlineRoom: LeaveOnlineRoomUseCase(repository),
    );
  });

  tearDown(() => cubit.close());

  test('emits server-owned lobby after create', () async {
    await cubit.createRoom(playerName: 'Ashraf', avatarId: 'default');

    expect(cubit.state, isA<OnlineSessionReady>());
    expect((cubit.state as OnlineSessionReady).value.roomCode, 'ABC123');
  });

  test('surfaces reconnecting and resumed snapshot updates', () async {
    repository.addUpdate(const OnlineConnectionUpdated(
      OnlineServerConnectionStatus.reconnecting,
    ));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<OnlineSessionLoading>());
    expect(
      cubit.state.connectionStatus,
      OnlineServerConnectionStatus.reconnecting,
    );

    repository.addUpdate(
        const OnlineLobbyUpdated(_FakeOnlineSessionRepository.lobby));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<OnlineSessionReady>());
  });
}

class _FakeOnlineSessionRepository implements OnlineSessionRepository {
  static const lobby = OnlineLobby(
    roomCode: 'ABC123',
    stateVersion: 1,
    localUserId: 'user-1',
    canStart: false,
    players: [
      OnlineLobbyPlayer(
        userId: 'user-1',
        name: 'Ashraf',
        avatarId: 'default',
        isConnected: true,
      ),
    ],
  );

  final _updates = StreamController<OnlineSessionUpdate>.broadcast(sync: true);

  void addUpdate(OnlineSessionUpdate update) => _updates.add(update);

  @override
  Stream<OnlineSessionUpdate> observe() => _updates.stream;

  @override
  Future<FailureOrSuccess<OnlineLobby>> createRoom({
    required String playerName,
    required String avatarId,
  }) async =>
      const Right(lobby);

  @override
  Future<FailureOrSuccess<OnlineLobby>> joinRoom({
    required String roomCode,
    required String playerName,
    required String avatarId,
  }) async =>
      const Right(lobby);

  @override
  Future<FailureOrSuccess<Unit>> leaveRoom() async => const Right(unit);
}
