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
      startOnlineGame: StartOnlineGameUseCase(repository),
      drawOnlineCard: DrawOnlineCardUseCase(repository),
      shuffleOnlineHand: ShuffleOnlineHandUseCase(repository),
      startOnlineRound: StartOnlineRoundUseCase(repository),
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

  test('starts the game with the latest server state version', () async {
    await cubit.createRoom(playerName: 'Ashraf', avatarId: 'default');
    await cubit.startGame();

    expect(repository.lastExpectedStateVersion, 1);
    expect((cubit.state as OnlineSessionReady).value.phase,
        OnlineRoomPhase.playing);
  });

  test('ignores a second server action while the first one is in flight',
      () async {
    await cubit.createRoom(playerName: 'Ashraf', avatarId: 'default');
    repository.startGameCompleter = Completer();

    final firstAction = cubit.startGame();
    final secondAction = cubit.startGame();

    expect((cubit.state as OnlineSessionReady).isActionInFlight, isTrue);
    expect(repository.startGameCallCount, 1);

    repository.startGameCompleter!.complete(const Right(
      _FakeOnlineSessionRepository.playingLobby,
    ));
    await Future.wait([firstAction, secondAction]);

    expect((cubit.state as OnlineSessionReady).isActionInFlight, isFalse);
  });

  test('a stale action error cannot replace a newer streamed snapshot',
      () async {
    await cubit.createRoom(playerName: 'Ashraf', avatarId: 'default');
    repository.startGameCompleter = Completer();
    final action = cubit.startGame();
    repository.addUpdate(
      const OnlineLobbyUpdated(_FakeOnlineSessionRepository.playingLobby),
    );
    await Future<void>.delayed(Duration.zero);
    repository.startGameCompleter!.complete(
      const Left(AppFailure('State changed', code: 'stale_state')),
    );
    await action;

    final state = cubit.state as OnlineSessionReady;
    expect(state.value.stateVersion, 2);
    expect(state.actionErrorCode, 'stale_state');
  });

  test('an older action response cannot replace a newer streamed snapshot',
      () async {
    await cubit.createRoom(playerName: 'Ashraf', avatarId: 'default');
    repository.startGameCompleter = Completer();
    final action = cubit.startGame();
    repository.addUpdate(
      const OnlineLobbyUpdated(_FakeOnlineSessionRepository.newerPlayingLobby),
    );
    await Future<void>.delayed(Duration.zero);
    repository.startGameCompleter!.complete(
      const Right(_FakeOnlineSessionRepository.playingLobby),
    );
    await action;

    expect((cubit.state as OnlineSessionReady).value.stateVersion, 3);
  });
}

class _FakeOnlineSessionRepository implements OnlineSessionRepository {
  static const lobby = OnlineLobby(
    roomCode: 'ABC123',
    stateVersion: 1,
    localUserId: 'user-1',
    phase: OnlineRoomPhase.lobby,
    canStart: true,
    canStartNewRound: false,
    currentPlayerUserId: null,
    drawFromUserId: null,
    roundNumber: 1,
    lastAction: null,
    players: [
      OnlineLobbyPlayer(
        userId: 'user-1',
        name: 'Ashraf',
        avatarId: 'default',
        isConnected: true,
        cardCount: 0,
        score: 0,
        status: OnlinePlayerStatus.playing,
        finishPosition: 0,
        hand: [],
      ),
    ],
  );

  static const playingLobby = OnlineLobby(
    roomCode: 'ABC123',
    stateVersion: 2,
    localUserId: 'user-1',
    phase: OnlineRoomPhase.playing,
    canStart: false,
    canStartNewRound: false,
    currentPlayerUserId: 'user-1',
    drawFromUserId: 'user-2',
    roundNumber: 1,
    lastAction: null,
    players: [
      OnlineLobbyPlayer(
        userId: 'user-1',
        name: 'Ashraf',
        avatarId: 'default',
        isConnected: true,
        cardCount: 1,
        score: 0,
        status: OnlinePlayerStatus.playing,
        finishPosition: 0,
        hand: [
          OnlinePlayingCard(
            id: 'hearts_5',
            suit: OnlineCardSuit.hearts,
            rank: 5,
          ),
        ],
      ),
      OnlineLobbyPlayer(
        userId: 'user-2',
        name: 'Guest',
        avatarId: 'default',
        isConnected: true,
        cardCount: 2,
        score: 0,
        status: OnlinePlayerStatus.playing,
        finishPosition: 0,
      ),
    ],
  );

  static const newerPlayingLobby = OnlineLobby(
    roomCode: 'ABC123',
    stateVersion: 3,
    localUserId: 'user-1',
    phase: OnlineRoomPhase.playing,
    canStart: false,
    canStartNewRound: false,
    currentPlayerUserId: 'user-2',
    drawFromUserId: 'user-1',
    roundNumber: 1,
    lastAction: null,
    players: [
      OnlineLobbyPlayer(
        userId: 'user-1',
        name: 'Ashraf',
        avatarId: 'default',
        isConnected: true,
        cardCount: 1,
        score: 0,
        status: OnlinePlayerStatus.playing,
        finishPosition: 0,
        hand: [
          OnlinePlayingCard(
            id: 'hearts_5',
            suit: OnlineCardSuit.hearts,
            rank: 5,
          ),
        ],
      ),
      OnlineLobbyPlayer(
        userId: 'user-2',
        name: 'Guest',
        avatarId: 'default',
        isConnected: true,
        cardCount: 2,
        score: 0,
        status: OnlinePlayerStatus.playing,
        finishPosition: 0,
      ),
    ],
  );

  final _updates = StreamController<OnlineSessionUpdate>.broadcast(sync: true);
  int? lastExpectedStateVersion;
  int startGameCallCount = 0;
  Completer<FailureOrSuccess<OnlineLobby>>? startGameCompleter;

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

  @override
  Future<FailureOrSuccess<OnlineLobby>> startGame(
    int expectedStateVersion,
  ) async {
    startGameCallCount += 1;
    lastExpectedStateVersion = expectedStateVersion;
    if (startGameCompleter case final completer?) return completer.future;
    return const Right(playingLobby);
  }

  @override
  Future<FailureOrSuccess<OnlineLobby>> drawCard({
    required String targetUserId,
    required int cardIndex,
    required int expectedStateVersion,
  }) async =>
      const Right(playingLobby);

  @override
  Future<FailureOrSuccess<OnlineLobby>> shuffleHand(
    int expectedStateVersion,
  ) async =>
      const Right(playingLobby);

  @override
  Future<FailureOrSuccess<OnlineLobby>> startNewRound(
    int expectedStateVersion,
  ) async =>
      const Right(playingLobby);
}
