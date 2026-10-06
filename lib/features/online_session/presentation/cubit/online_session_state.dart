import 'package:equatable/equatable.dart';

import '../../../../core/networking/resource.dart';
import '../../domain/entities/online_lobby.dart';

enum OnlineDrawPhase {
  idle,
  selectingCard,
  completing,
  revealingCard,
  showingMatch,
}

class OnlineDrawOutcome extends Equatable {
  final int id;
  final String targetUserId;
  final int selectedCardIndex;
  final OnlinePlayingCard drawnCard;
  final OnlinePlayingCard? matchedCard;

  const OnlineDrawOutcome({
    required this.id,
    required this.targetUserId,
    required this.selectedCardIndex,
    required this.drawnCard,
    this.matchedCard,
  });

  bool get madeMatch => matchedCard != null;

  @override
  List<Object?> get props => [
        id,
        targetUserId,
        selectedCardIndex,
        drawnCard,
        matchedCard,
      ];
}

enum OnlineSessionEffectType {
  cardDrawn,
  matchFound,
  handShuffled,
}

class OnlineSessionEffect extends Equatable {
  final int id;
  final OnlineSessionEffectType type;

  const OnlineSessionEffect({required this.id, required this.type});

  @override
  List<Object?> get props => [id, type];
}

sealed class OnlineSessionState extends Equatable {
  final Resource<OnlineLobby> lobby;
  final OnlineServerConnectionStatus connectionStatus;

  const OnlineSessionState({
    required this.lobby,
    required this.connectionStatus,
  });

  @override
  List<Object?> get props => [lobby, connectionStatus];
}

class OnlineSessionInitial extends OnlineSessionState {
  const OnlineSessionInitial()
      : super(
          lobby: const Resource.initial(),
          connectionStatus: OnlineServerConnectionStatus.disconnected,
        );
}

class OnlineSessionLoading extends OnlineSessionState {
  const OnlineSessionLoading(OnlineServerConnectionStatus status)
      : super(lobby: const Resource.loading(), connectionStatus: status);
}

class OnlineSessionReady extends OnlineSessionState {
  final OnlineLobby value;
  final String? actionErrorMessage;
  final String? actionErrorCode;
  final bool isActionInFlight;
  final OnlineDrawPhase drawPhase;
  final String? selectedDrawTargetUserId;
  final OnlineDrawOutcome? drawOutcome;
  final OnlineSessionEffect? effect;

  OnlineSessionReady(
    this.value, {
    OnlineServerConnectionStatus status =
        OnlineServerConnectionStatus.connected,
    this.actionErrorMessage,
    this.actionErrorCode,
    this.isActionInFlight = false,
    this.drawPhase = OnlineDrawPhase.idle,
    this.selectedDrawTargetUserId,
    this.drawOutcome,
    this.effect,
  }) : super(lobby: Resource.success(value), connectionStatus: status);

  OnlineSessionReady copyWith({
    OnlineLobby? value,
    OnlineServerConnectionStatus? status,
    String? actionErrorMessage,
    String? actionErrorCode,
    bool? isActionInFlight,
    OnlineDrawPhase? drawPhase,
    String? selectedDrawTargetUserId,
    OnlineDrawOutcome? drawOutcome,
    OnlineSessionEffect? effect,
    bool clearActionError = false,
    bool clearDraw = false,
  }) {
    return OnlineSessionReady(
      value ?? this.value,
      status: status ?? connectionStatus,
      actionErrorMessage: clearActionError
          ? null
          : actionErrorMessage ?? this.actionErrorMessage,
      actionErrorCode:
          clearActionError ? null : actionErrorCode ?? this.actionErrorCode,
      isActionInFlight: isActionInFlight ?? this.isActionInFlight,
      drawPhase: clearDraw ? OnlineDrawPhase.idle : drawPhase ?? this.drawPhase,
      selectedDrawTargetUserId: clearDraw
          ? null
          : selectedDrawTargetUserId ?? this.selectedDrawTargetUserId,
      drawOutcome: clearDraw ? null : drawOutcome ?? this.drawOutcome,
      effect: effect ?? this.effect,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        value,
        actionErrorMessage,
        actionErrorCode,
        isActionInFlight,
        drawPhase,
        selectedDrawTargetUserId,
        drawOutcome,
        effect,
      ];
}

class OnlineSessionFailure extends OnlineSessionState {
  final String message;
  final String? code;

  OnlineSessionFailure(
    this.message, {
    this.code,
    OnlineServerConnectionStatus status =
        OnlineServerConnectionStatus.disconnected,
  }) : super(lobby: Resource.error(message), connectionStatus: status);

  @override
  List<Object?> get props => [...super.props, message, code];
}
