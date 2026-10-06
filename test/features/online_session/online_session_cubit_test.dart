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
      restoreOnlineSession: RestoreOnlineSessionUseCase(repository),
      reconnectOnlineSession: ReconnectOnlineSessionUseCase(repository),
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

  test('restores a saved room on screen entry', () async {
    repository.savedLobby = _FakeOnlineSessionRepository.lobby;

    await cubit.restoreSession();

    expect(cubit.state, isA<OnlineSessionReady>());
    expect((cubit.state as OnlineSessionReady).value.roomCode, 'ABC123');
  });

  test('returns to room entry when there is no saved room', () async {
    await cubit.restoreSession();

    expect(cubit.state, isA<OnlineSessionInitial>());
  });

  test('retries a failed saved-room restore when the app resumes', () async {
    repository.restoreFailure =
        const AppFailure('Offline', code: 'socket_error');
    await cubit.restoreSession();
    repository.restoreFailure = null;
    repository.savedLobby = _FakeOnlineSessionRepository.lobby;

    await cubit.onAppResumed();

    expect(repository.restoreCallCount, 2);
    expect(cubit.state, isA<OnlineSessionReady>());
  });

  test('reconnects a ready room when the app resumes', () async {
    await cubit.createRoom(playerName: 'Ashraf', avatarId: 'default');

    await cubit.onAppResumed();

    expect(repository.reconnectCallCount, 1);
    expect(
        cubit.state.connectionStatus, OnlineServerConnectionStatus.connected);
  });

  test('does not send game actions while the room is offline', () async {
    await cubit.createRoom(playerName: 'Ashraf', avatarId: 'default');
    repository.addUpdate(const OnlineConnectionUpdated(
      OnlineServerConnectionStatus.disconnected,
    ));
    await Future<void>.delayed(Duration.zero);

    await cubit.startGame();

    expect(repository.startGameCallCount, 0);
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

  test('does not draw from a disconnected player in a paused game', () async {
    repository.addUpdate(const OnlineLobbyUpdated(
      _FakeOnlineSessionRepository.pausedPlayingLobby,
    ));
    await Future<void>.delayed(Duration.zero);

    await cubit.drawCard(0);

    expect(repository.drawCardCallCount, 0);
  });

  test('cancels card selection when the authoritative target changes',
      () async {
    repository.addUpdate(const OnlineLobbyUpdated(
      _FakeOnlineSessionRepository.playingLobby,
    ));
    await Future<void>.delayed(Duration.zero);
    cubit.initiateDrawFrom('user-2');

    repository.addUpdate(const OnlineLobbyUpdated(
      _FakeOnlineSessionRepository.continuingPlayingLobby,
    ));
    await Future<void>.delayed(Duration.zero);

    final state = cubit.state as OnlineSessionReady;
    expect(state.drawPhase, OnlineDrawPhase.idle);
    expect(state.selectedDrawTargetUserId, isNull);

    await cubit.drawCard(0);
    expect(repository.drawCardCallCount, 0);
  });

  test('uses the correlated draw response after a newer snapshot arrives',
      () async {
    repository.addUpdate(const OnlineLobbyUpdated(
      _FakeOnlineSessionRepository.playingLobby,
    ));
    await Future<void>.delayed(Duration.zero);
    cubit.initiateDrawFrom('user-2');
    repository.drawCardCompleter = Completer();

    final draw = cubit.drawCard(0);
    repository.addUpdate(const OnlineLobbyUpdated(
      _FakeOnlineSessionRepository.newerDuringDrawLobby,
    ));
    repository.drawCardCompleter!.complete(const Right(
      _FakeOnlineSessionRepository.drawResponseLobby,
    ));
    await Future<void>.delayed(Duration.zero);

    final revealing = cubit.state as OnlineSessionReady;
    expect(revealing.value.stateVersion, 4);
    expect(revealing.drawPhase, OnlineDrawPhase.revealingCard);
    expect(revealing.drawOutcome?.targetUserId, 'user-2');
    expect(revealing.drawOutcome?.drawnCard.id, 'spades_7');
    expect(revealing.effect?.type, OnlineSessionEffectType.cardDrawn);

    await draw;
    expect((cubit.state as OnlineSessionReady).drawPhase, OnlineDrawPhase.idle);
  });

  test('does not publish shuffle feedback when the command fails', () async {
    repository.addUpdate(const OnlineLobbyUpdated(
      _FakeOnlineSessionRepository.playingLobby,
    ));
    await Future<void>.delayed(Duration.zero);
    repository.shuffleResult =
        const Left(AppFailure('State changed', code: 'stale_state'));

    await cubit.shuffleHand();

    final state = cubit.state as OnlineSessionReady;
    expect(state.effect, isNull);
    expect(state.actionErrorCode, 'stale_state');
  });

  test('continues with a connected target when a third player disconnects',
      () async {
    repository.addUpdate(const OnlineLobbyUpdated(
      _FakeOnlineSessionRepository.continuingPlayingLobby,
    ));
    await Future<void>.delayed(Duration.zero);

    final lobby = (cubit.state as OnlineSessionReady).value;
    expect(lobby.isPausedForDisconnectedPlayer, isFalse);
    expect(lobby.canDraw, isTrue);

    cubit.initiateDrawFrom('user-3');
    await cubit.drawCard(0);

    expect(repository.drawCardCallCount, 1);
    expect(repository.lastDrawTargetUserId, 'user-3');
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

  static const pausedPlayingLobby = OnlineLobby(
    roomCode: 'ABC123',
    stateVersion: 4,
    localUserId: 'user-1',
    phase: OnlineRoomPhase.playing,
    canStart: false,
    canStartNewRound: false,
    currentPlayerUserId: 'user-1',
    drawFromUserId: null,
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
        isConnected: false,
        cardCount: 2,
        score: 0,
        status: OnlinePlayerStatus.playing,
        finishPosition: 0,
      ),
    ],
  );

  static const continuingPlayingLobby = OnlineLobby(
    roomCode: 'ABC123',
    stateVersion: 5,
    localUserId: 'user-1',
    phase: OnlineRoomPhase.playing,
    canStart: false,
    canStartNewRound: false,
    currentPlayerUserId: 'user-1',
    drawFromUserId: 'user-3',
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
        name: 'Disconnected',
        avatarId: 'default',
        isConnected: false,
        cardCount: 2,
        score: 0,
        status: OnlinePlayerStatus.playing,
        finishPosition: 0,
      ),
      OnlineLobbyPlayer(
        userId: 'user-3',
        name: 'Connected target',
        avatarId: 'default',
        isConnected: true,
        cardCount: 2,
        score: 0,
        status: OnlinePlayerStatus.playing,
        finishPosition: 0,
      ),
    ],
  );

  static const newerDuringDrawLobby = OnlineLobby(
    roomCode: 'ABC123',
    stateVersion: 4,
    localUserId: 'user-1',
    phase: OnlineRoomPhase.playing,
    canStart: false,
    canStartNewRound: false,
    currentPlayerUserId: 'user-2',
    drawFromUserId: 'user-1',
    roundNumber: 1,
    lastAction: OnlineGameAction(
      type: OnlineGameActionType.handShuffled,
      actorUserId: 'user-2',
    ),
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

  static const drawResponseLobby = OnlineLobby(
    roomCode: 'ABC123',
    stateVersion: 3,
    localUserId: 'user-1',
    phase: OnlineRoomPhase.playing,
    canStart: false,
    canStartNewRound: false,
    currentPlayerUserId: 'user-2',
    drawFromUserId: 'user-1',
    roundNumber: 1,
    lastAction: OnlineGameAction(
      type: OnlineGameActionType.cardDrawn,
      actorUserId: 'user-1',
      targetUserId: 'user-2',
      madePair: false,
      drawnCard: OnlinePlayingCard(
        id: 'spades_7',
        suit: OnlineCardSuit.spades,
        rank: 7,
      ),
    ),
    players: [
      OnlineLobbyPlayer(
        userId: 'user-1',
        name: 'Ashraf',
        avatarId: 'default',
        isConnected: true,
        cardCount: 2,
        score: 0,
        status: OnlinePlayerStatus.playing,
        finishPosition: 0,
        hand: [
          OnlinePlayingCard(
            id: 'hearts_5',
            suit: OnlineCardSuit.hearts,
            rank: 5,
          ),
          OnlinePlayingCard(
            id: 'spades_7',
            suit: OnlineCardSuit.spades,
            rank: 7,
          ),
        ],
      ),
      OnlineLobbyPlayer(
        userId: 'user-2',
        name: 'Guest',
        avatarId: 'default',
        isConnected: true,
        cardCount: 1,
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
  OnlineLobby? savedLobby;
  AppFailure? restoreFailure;
  int restoreCallCount = 0;
  int reconnectCallCount = 0;
  int drawCardCallCount = 0;
  String? lastDrawTargetUserId;
  Completer<FailureOrSuccess<OnlineLobby>>? drawCardCompleter;
  FailureOrSuccess<OnlineLobby> shuffleResult = const Right(playingLobby);

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
  Future<FailureOrSuccess<OnlineLobby?>> restoreSession() async {
    restoreCallCount += 1;
    final failure = restoreFailure;
    return failure == null ? Right(savedLobby) : Left(failure);
  }

  @override
  Future<FailureOrSuccess<OnlineLobby>> reconnect() async {
    reconnectCallCount += 1;
    return const Right(lobby);
  }

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
  }) async {
    drawCardCallCount += 1;
    lastDrawTargetUserId = targetUserId;
    if (drawCardCompleter case final completer?) return completer.future;
    return const Right(playingLobby);
  }

  @override
  Future<FailureOrSuccess<OnlineLobby>> shuffleHand(
    int expectedStateVersion,
  ) async =>
      shuffleResult;

  @override
  Future<FailureOrSuccess<OnlineLobby>> startNewRound(
    int expectedStateVersion,
  ) async =>
      const Right(playingLobby);
}
