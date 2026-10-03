import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/networking/async_result.dart';
import '../../domain/entities/online_lobby.dart';
import '../../domain/usecases/online_session_usecases.dart';
import 'online_session_state.dart';

class OnlineSessionCubit extends Cubit<OnlineSessionState> {
  final ObserveOnlineSessionUseCase _observeOnlineSession;
  final CreateOnlineRoomUseCase _createOnlineRoom;
  final JoinOnlineRoomUseCase _joinOnlineRoom;
  final LeaveOnlineRoomUseCase _leaveOnlineRoom;
  final StartOnlineGameUseCase _startOnlineGame;
  final DrawOnlineCardUseCase _drawOnlineCard;
  final ShuffleOnlineHandUseCase _shuffleOnlineHand;
  final StartOnlineRoundUseCase _startOnlineRound;

  late final StreamSubscription<OnlineSessionUpdate> _updatesSubscription;

  OnlineSessionCubit({
    required ObserveOnlineSessionUseCase observeOnlineSession,
    required CreateOnlineRoomUseCase createOnlineRoom,
    required JoinOnlineRoomUseCase joinOnlineRoom,
    required LeaveOnlineRoomUseCase leaveOnlineRoom,
    required StartOnlineGameUseCase startOnlineGame,
    required DrawOnlineCardUseCase drawOnlineCard,
    required ShuffleOnlineHandUseCase shuffleOnlineHand,
    required StartOnlineRoundUseCase startOnlineRound,
  })  : _observeOnlineSession = observeOnlineSession,
        _createOnlineRoom = createOnlineRoom,
        _joinOnlineRoom = joinOnlineRoom,
        _leaveOnlineRoom = leaveOnlineRoom,
        _startOnlineGame = startOnlineGame,
        _drawOnlineCard = drawOnlineCard,
        _shuffleOnlineHand = shuffleOnlineHand,
        _startOnlineRound = startOnlineRound,
        super(const OnlineSessionInitial()) {
    _updatesSubscription = _observeOnlineSession().listen(
      _handleUpdate,
      onError: (Object error, StackTrace stackTrace) {
        if (!isClosed) emit(OnlineSessionFailure(error.toString()));
      },
    );
  }

  Future<void> createRoom({
    required String playerName,
    required String avatarId,
  }) async {
    emit(const OnlineSessionLoading(OnlineServerConnectionStatus.connecting));
    final result = await _createOnlineRoom(
      playerName: playerName,
      avatarId: avatarId,
    );
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        OnlineSessionFailure(failure.message, code: failure.code),
      ),
      (lobby) => emit(OnlineSessionReady(lobby)),
    );
  }

  Future<void> joinRoom({
    required String roomCode,
    required String playerName,
    required String avatarId,
  }) async {
    emit(const OnlineSessionLoading(OnlineServerConnectionStatus.connecting));
    final result = await _joinOnlineRoom(
      roomCode: roomCode,
      playerName: playerName,
      avatarId: avatarId,
    );
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        OnlineSessionFailure(failure.message, code: failure.code),
      ),
      (lobby) => emit(OnlineSessionReady(lobby)),
    );
  }

  Future<void> leaveRoom() async {
    final result = await _leaveOnlineRoom();
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        OnlineSessionFailure(failure.message, code: failure.code),
      ),
      (_) => emit(const OnlineSessionInitial()),
    );
  }

  Future<void> startGame() async {
    final current = state;
    if (current is! OnlineSessionReady || !current.value.canStart) return;
    _handleGameResult(
      await _startOnlineGame(current.value.stateVersion),
      current,
    );
  }

  Future<void> drawCard(int cardIndex) async {
    final current = state;
    if (current is! OnlineSessionReady || !current.value.isMyTurn) return;
    final targetUserId = current.value.drawFromUserId;
    if (targetUserId == null) return;
    _handleGameResult(
      await _drawOnlineCard(
        targetUserId: targetUserId,
        cardIndex: cardIndex,
        expectedStateVersion: current.value.stateVersion,
      ),
      current,
    );
  }

  Future<void> shuffleHand() async {
    final current = state;
    if (current is! OnlineSessionReady ||
        current.value.phase != OnlineRoomPhase.playing) {
      return;
    }
    _handleGameResult(
      await _shuffleOnlineHand(current.value.stateVersion),
      current,
    );
  }

  Future<void> startNewRound() async {
    final current = state;
    if (current is! OnlineSessionReady || !current.value.canStartNewRound) {
      return;
    }
    _handleGameResult(
      await _startOnlineRound(current.value.stateVersion),
      current,
    );
  }

  void _handleGameResult(
    FailureOrSuccess<OnlineLobby> result,
    OnlineSessionReady previous,
  ) {
    if (isClosed) return;
    result.fold(
      (failure) {
        final latest = state is OnlineSessionReady
            ? state as OnlineSessionReady
            : previous;
        emit(OnlineSessionReady(
          latest.value,
          status: latest.connectionStatus,
          actionErrorMessage: failure.message,
          actionErrorCode: failure.code,
        ));
      },
      (room) => emit(OnlineSessionReady(room)),
    );
  }

  void _handleUpdate(OnlineSessionUpdate update) {
    if (isClosed) return;
    switch (update) {
      case OnlineLobbyUpdated(:final lobby):
        emit(OnlineSessionReady(lobby));
      case OnlineConnectionUpdated(:final status):
        final currentState = state;
        if (currentState is OnlineSessionReady) {
          emit(OnlineSessionReady(currentState.value, status: status));
        } else if (status == OnlineServerConnectionStatus.disconnected) {
          emit(const OnlineSessionInitial());
        } else {
          emit(OnlineSessionLoading(status));
        }
      case OnlineSessionRejected(:final message, :final code):
        final currentState = state;
        if (currentState is OnlineSessionReady) {
          emit(OnlineSessionReady(
            currentState.value,
            status: currentState.connectionStatus,
            actionErrorMessage: message,
            actionErrorCode: code,
          ));
        } else {
          emit(OnlineSessionFailure(
            message,
            code: code,
            status: state.connectionStatus,
          ));
        }
    }
  }

  @override
  Future<void> close() async {
    await _leaveOnlineRoom();
    await _updatesSubscription.cancel();
    return super.close();
  }
}
