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
  final RestoreOnlineSessionUseCase _restoreOnlineSession;
  final ReconnectOnlineSessionUseCase _reconnectOnlineSession;
  final LeaveOnlineRoomUseCase _leaveOnlineRoom;
  final StartOnlineGameUseCase _startOnlineGame;
  final DrawOnlineCardUseCase _drawOnlineCard;
  final ShuffleOnlineHandUseCase _shuffleOnlineHand;
  final StartOnlineRoundUseCase _startOnlineRound;

  late final StreamSubscription<OnlineSessionUpdate> _updatesSubscription;
  bool _restoreAttempted = false;
  bool _restoreFailed = false;
  bool _reconnectInFlight = false;
  int _nextDrawOutcomeId = 0;
  int _nextEffectId = 0;

  OnlineSessionCubit({
    required ObserveOnlineSessionUseCase observeOnlineSession,
    required CreateOnlineRoomUseCase createOnlineRoom,
    required JoinOnlineRoomUseCase joinOnlineRoom,
    required RestoreOnlineSessionUseCase restoreOnlineSession,
    required ReconnectOnlineSessionUseCase reconnectOnlineSession,
    required LeaveOnlineRoomUseCase leaveOnlineRoom,
    required StartOnlineGameUseCase startOnlineGame,
    required DrawOnlineCardUseCase drawOnlineCard,
    required ShuffleOnlineHandUseCase shuffleOnlineHand,
    required StartOnlineRoundUseCase startOnlineRound,
  })  : _observeOnlineSession = observeOnlineSession,
        _createOnlineRoom = createOnlineRoom,
        _joinOnlineRoom = joinOnlineRoom,
        _restoreOnlineSession = restoreOnlineSession,
        _reconnectOnlineSession = reconnectOnlineSession,
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

  Future<void> restoreSession() async {
    if (_restoreAttempted) return;
    _restoreAttempted = true;
    emit(const OnlineSessionLoading(OnlineServerConnectionStatus.connecting));
    final result = await _restoreOnlineSession();
    if (isClosed) return;
    result.fold(
      (failure) {
        _restoreFailed = true;
        emit(OnlineSessionFailure(failure.message, code: failure.code));
      },
      (lobby) {
        _restoreFailed = false;
        emit(
          lobby == null
              ? const OnlineSessionInitial()
              : OnlineSessionReady(lobby),
        );
      },
    );
  }

  Future<void> reconnect() async {
    if (_reconnectInFlight) return;
    final current = state;
    if (current is! OnlineSessionReady) return;
    _reconnectInFlight = true;
    emit(current.copyWith(
      status: OnlineServerConnectionStatus.reconnecting,
      clearDraw: true,
    ));
    final result = await _reconnectOnlineSession();
    _reconnectInFlight = false;
    if (isClosed) return;
    result.fold(
      (failure) {
        final latest = _latestReady(current);
        emit(latest.copyWith(
          status: OnlineServerConnectionStatus.disconnected,
          actionErrorMessage: failure.message,
          actionErrorCode: failure.code,
          clearDraw: true,
        ));
      },
      (lobby) {
        final latest = _latestReady(current);
        final newestLobby = latest.value.stateVersion > lobby.stateVersion
            ? latest.value
            : lobby;
        emit(latest.copyWith(
          value: newestLobby,
          status: OnlineServerConnectionStatus.connected,
          isActionInFlight: false,
          clearActionError: true,
          clearDraw: true,
        ));
      },
    );
  }

  Future<void> onAppResumed() async {
    if (state case OnlineSessionReady()) {
      await reconnect();
    } else if (_restoreFailed) {
      _restoreAttempted = false;
      await restoreSession();
    }
  }

  Future<void> createRoom({
    required String playerName,
    required String avatarId,
  }) async {
    _restoreFailed = false;
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
    _restoreFailed = false;
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
    if (current is! OnlineSessionReady ||
        current.isActionInFlight ||
        current.connectionStatus != OnlineServerConnectionStatus.connected ||
        !current.value.canStart) {
      return;
    }
    _markActionInFlight(current);
    _handleGameResult(
      await _startOnlineGame(current.value.stateVersion),
      current,
    );
  }

  void initiateDrawFrom(String targetUserId) {
    final current = state;
    if (current is! OnlineSessionReady ||
        current.isActionInFlight ||
        current.connectionStatus != OnlineServerConnectionStatus.connected ||
        current.drawPhase != OnlineDrawPhase.idle ||
        !current.value.canDraw ||
        current.value.drawFromUserId != targetUserId ||
        current.value.drawFromPlayer?.cardCount == 0) {
      return;
    }
    emit(current.copyWith(
      drawPhase: OnlineDrawPhase.selectingCard,
      selectedDrawTargetUserId: targetUserId,
      clearActionError: true,
    ));
  }

  void cancelDrawSelection() {
    final current = state;
    if (current is! OnlineSessionReady || current.isActionInFlight) return;
    emit(current.copyWith(clearDraw: true));
  }

  Future<void> drawCard(int cardIndex) async {
    final current = state;
    if (current is! OnlineSessionReady ||
        current.isActionInFlight ||
        current.connectionStatus != OnlineServerConnectionStatus.connected ||
        current.drawPhase != OnlineDrawPhase.selectingCard ||
        !current.value.canDraw) {
      return;
    }
    final targetUserId = current.selectedDrawTargetUserId;
    final target = current.value.drawFromPlayer;
    if (targetUserId == null ||
        current.value.drawFromUserId != targetUserId ||
        target?.userId != targetUserId ||
        cardIndex < 0 ||
        cardIndex >= target!.cardCount) {
      emit(current.copyWith(clearDraw: true));
      return;
    }

    emit(current.copyWith(
      isActionInFlight: true,
      drawPhase: OnlineDrawPhase.completing,
      clearActionError: true,
    ));
    final result = await _drawOnlineCard(
      targetUserId: targetUserId,
      cardIndex: cardIndex,
      expectedStateVersion: current.value.stateVersion,
    );
    if (isClosed) return;
    await result.fold(
      (failure) async {
        final latest = _latestReady(current);
        emit(latest.copyWith(
          isActionInFlight: false,
          actionErrorMessage: failure.message,
          actionErrorCode: failure.code,
          clearDraw: true,
        ));
      },
      (room) async => _handleConfirmedDraw(
        responseRoom: room,
        previous: current,
        targetUserId: targetUserId,
        cardIndex: cardIndex,
      ),
    );
  }

  Future<void> shuffleHand() async {
    final current = state;
    if (current is! OnlineSessionReady ||
        current.isActionInFlight ||
        current.connectionStatus != OnlineServerConnectionStatus.connected ||
        current.value.phase != OnlineRoomPhase.playing ||
        current.drawPhase != OnlineDrawPhase.idle) {
      return;
    }
    _markActionInFlight(current);
    _handleGameResult(
      await _shuffleOnlineHand(current.value.stateVersion),
      current,
      successEffect: OnlineSessionEffectType.handShuffled,
    );
  }

  Future<void> startNewRound() async {
    final current = state;
    if (current is! OnlineSessionReady ||
        current.isActionInFlight ||
        current.connectionStatus != OnlineServerConnectionStatus.connected ||
        !current.value.canStartNewRound) {
      return;
    }
    _markActionInFlight(current);
    _handleGameResult(
      await _startOnlineRound(current.value.stateVersion),
      current,
    );
  }

  void _markActionInFlight(OnlineSessionReady current) {
    emit(current.copyWith(
      isActionInFlight: true,
      clearActionError: true,
    ));
  }

  void _handleGameResult(
    FailureOrSuccess<OnlineLobby> result,
    OnlineSessionReady previous, {
    OnlineSessionEffectType? successEffect,
  }) {
    if (isClosed) return;
    result.fold(
      (failure) {
        final latest = _latestReady(previous);
        emit(latest.copyWith(
          isActionInFlight: false,
          actionErrorMessage: failure.message,
          actionErrorCode: failure.code,
        ));
      },
      (room) {
        final latest = _latestReady(previous);
        final newestRoom =
            latest.value.stateVersion > room.stateVersion ? latest.value : room;
        emit(latest.copyWith(
          value: newestRoom,
          isActionInFlight: false,
          clearActionError: true,
          effect: successEffect == null ? null : _effect(successEffect),
        ));
      },
    );
  }

  Future<void> _handleConfirmedDraw({
    required OnlineLobby responseRoom,
    required OnlineSessionReady previous,
    required String targetUserId,
    required int cardIndex,
  }) async {
    final action = responseRoom.lastAction;
    if (action?.type != OnlineGameActionType.cardDrawn ||
        action?.actorUserId != previous.value.localUserId ||
        action?.targetUserId != targetUserId ||
        action?.drawnCard == null) {
      final latest = _latestReady(previous);
      emit(latest.copyWith(
        isActionInFlight: false,
        actionErrorMessage: 'The online server returned an invalid draw.',
        actionErrorCode: 'invalid_server_response',
        clearDraw: true,
      ));
      return;
    }

    OnlinePlayingCard? matchedCard;
    if (action!.madePair == true) {
      final previousHand = previous.value.localPlayer?.hand;
      if (previousHand != null) {
        for (final card in previousHand) {
          if (card.rank == action.drawnCard!.rank) {
            matchedCard = card;
            break;
          }
        }
      }
    }

    final latest = _latestReady(previous);
    final newestRoom = latest.value.stateVersion > responseRoom.stateVersion
        ? latest.value
        : responseRoom;
    final outcome = OnlineDrawOutcome(
      id: ++_nextDrawOutcomeId,
      targetUserId: targetUserId,
      selectedCardIndex: cardIndex,
      drawnCard: action.drawnCard!,
      matchedCard: matchedCard,
    );
    emit(latest.copyWith(
      value: newestRoom,
      isActionInFlight: false,
      drawPhase: OnlineDrawPhase.revealingCard,
      selectedDrawTargetUserId: targetUserId,
      drawOutcome: outcome,
      effect: _effect(OnlineSessionEffectType.cardDrawn),
      clearActionError: true,
    ));

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (isClosed) return;
    final afterReveal = state;
    if (afterReveal is! OnlineSessionReady ||
        afterReveal.drawOutcome?.id != outcome.id ||
        afterReveal.drawPhase != OnlineDrawPhase.revealingCard) {
      return;
    }
    if (!outcome.madeMatch) {
      emit(afterReveal.copyWith(clearDraw: true));
      return;
    }

    emit(afterReveal.copyWith(
      drawPhase: OnlineDrawPhase.showingMatch,
      effect: _effect(OnlineSessionEffectType.matchFound),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (isClosed) return;
    final afterMatch = state;
    if (afterMatch is OnlineSessionReady &&
        afterMatch.drawOutcome?.id == outcome.id &&
        afterMatch.drawPhase == OnlineDrawPhase.showingMatch) {
      emit(afterMatch.copyWith(clearDraw: true));
    }
  }

  OnlineSessionReady _latestReady(OnlineSessionReady fallback) {
    final current = state;
    return current is OnlineSessionReady ? current : fallback;
  }

  OnlineSessionEffect _effect(OnlineSessionEffectType type) {
    return OnlineSessionEffect(id: ++_nextEffectId, type: type);
  }

  OnlineSessionReady _reconcileDrawSelection(OnlineSessionReady current) {
    if (current.drawPhase != OnlineDrawPhase.selectingCard) return current;
    final isSelectionValid =
        current.connectionStatus == OnlineServerConnectionStatus.connected &&
            current.value.phase == OnlineRoomPhase.playing &&
            current.value.canDraw &&
            current.value.drawFromUserId == current.selectedDrawTargetUserId;
    return isSelectionValid ? current : current.copyWith(clearDraw: true);
  }

  void _handleUpdate(OnlineSessionUpdate update) {
    if (isClosed) return;
    switch (update) {
      case OnlineLobbyUpdated(:final lobby):
        final currentState = state;
        if (currentState is OnlineSessionReady) {
          final newestLobby =
              currentState.value.stateVersion > lobby.stateVersion
                  ? currentState.value
                  : lobby;
          emit(_reconcileDrawSelection(
            currentState.copyWith(value: newestLobby),
          ));
        } else {
          emit(OnlineSessionReady(lobby));
        }
      case OnlineConnectionUpdated(:final status):
        final currentState = state;
        if (currentState is OnlineSessionReady) {
          final updated = currentState.copyWith(
            status: status,
            clearDraw: status != OnlineServerConnectionStatus.connected &&
                !currentState.isActionInFlight,
          );
          emit(_reconcileDrawSelection(updated));
        } else if (status == OnlineServerConnectionStatus.disconnected) {
          emit(const OnlineSessionInitial());
        } else {
          emit(OnlineSessionLoading(status));
        }
      case OnlineSessionRejected(:final message, :final code):
        final currentState = state;
        if (currentState is OnlineSessionReady) {
          emit(currentState.copyWith(
            isActionInFlight: false,
            actionErrorMessage: message,
            actionErrorCode: code,
            clearDraw: true,
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
