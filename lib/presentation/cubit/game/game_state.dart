/// Presentation Layer - Game UI State
///
/// UI-specific state that wraps domain GameState with presentation concerns.
library;

import 'package:equatable/equatable.dart';
import '../../../domain/entities/entities.dart';

/// Loading status for async operations
enum LoadingStatus {
  initial,
  loading,
  success,
  failure,
}

/// Draw phase for card selection flow
enum DrawPhase {
  /// Normal gameplay - waiting for player to tap opponent
  idle,

  /// Player tapped opponent - showing card selection overlay
  selectingCard,

  /// Card selected - revealing the drawn card
  revealingCard,

  /// Card matched - showing match animation
  showingMatch,

  /// Animation complete - moving to next turn
  completing,
}

/// Information about the current draw action
class DrawActionInfo extends Equatable {
  final String targetPlayerId;
  final int? selectedCardIndex;
  final PlayingCard? drawnCard;
  final PlayingCard? matchedCard;
  final bool madeMatch;

  const DrawActionInfo({
    required this.targetPlayerId,
    this.selectedCardIndex,
    this.drawnCard,
    this.matchedCard,
    this.madeMatch = false,
  });

  DrawActionInfo copyWith({
    String? targetPlayerId,
    int? selectedCardIndex,
    PlayingCard? drawnCard,
    PlayingCard? matchedCard,
    bool? madeMatch,
  }) {
    return DrawActionInfo(
      targetPlayerId: targetPlayerId ?? this.targetPlayerId,
      selectedCardIndex: selectedCardIndex ?? this.selectedCardIndex,
      drawnCard: drawnCard ?? this.drawnCard,
      matchedCard: matchedCard ?? this.matchedCard,
      madeMatch: madeMatch ?? this.madeMatch,
    );
  }

  @override
  List<Object?> get props =>
      [targetPlayerId, selectedCardIndex, drawnCard, matchedCard, madeMatch];
}

/// UI state for the game screen
class GameUiState extends Equatable {
  final GameState? gameState;
  final LoadingStatus status;
  final String? error;
  final String localPlayerId;
  final bool isHost;
  final bool isConnecting;
  final bool isReconnecting;
  final String? lastEventMessage;

  // Card selection state
  final int? selectedCardIndex;
  final DrawPhase drawPhase;
  final DrawActionInfo? currentDrawAction;

  // Animation states
  final bool showDealAnimation;
  final List<String> matchedCardIds;

  // Discovery
  final List<RoomInfo> discoveredRooms;

  const GameUiState({
    this.gameState,
    this.status = LoadingStatus.initial,
    this.error,
    this.localPlayerId = '',
    this.isHost = false,
    this.isConnecting = false,
    this.isReconnecting = false,
    this.lastEventMessage,
    this.selectedCardIndex,
    this.drawPhase = DrawPhase.idle,
    this.currentDrawAction,
    this.showDealAnimation = false,
    this.matchedCardIds = const [],
    this.discoveredRooms = const [],
  });

  /// Get players list
  List<Player> get players => gameState?.players ?? [];

  /// Get current game phase
  GamePhase get phase => gameState?.phase ?? GamePhase.lobby;

  /// Get room code
  String get roomCode => gameState?.roomCode ?? '';

  /// Get current player (whose turn it is)
  Player? get currentPlayer => gameState?.currentPlayer;

  /// Get local player
  Player? get localPlayer {
    if (localPlayerId.isEmpty || gameState == null) return null;
    return gameState!.getPlayerById(localPlayerId);
  }

  /// Check if it's local player's turn
  bool get isMyTurn => currentPlayer?.id == localPlayerId;

  /// Check if game is in playing phase
  bool get isPlaying => phase == GamePhase.playing;

  /// Check if we're in card selection mode
  bool get isSelectingCard => drawPhase == DrawPhase.selectingCard;

  /// Check if we're showing card reveal
  bool get isRevealingCard => drawPhase == DrawPhase.revealingCard;

  /// Check if we're showing match animation
  bool get isShowingMatch => drawPhase == DrawPhase.showingMatch;

  /// Get the target player for current draw action
  Player? get drawTargetPlayer {
    if (currentDrawAction == null || gameState == null) return null;
    return gameState!.getPlayerById(currentDrawAction!.targetPlayerId);
  }

  GameUiState copyWith({
    GameState? gameState,
    LoadingStatus? status,
    String? error,
    String? localPlayerId,
    bool? isHost,
    bool? isConnecting,
    bool? isReconnecting,
    String? lastEventMessage,
    int? selectedCardIndex,
    DrawPhase? drawPhase,
    DrawActionInfo? currentDrawAction,
    bool? showDealAnimation,
    List<String>? matchedCardIds,
    List<RoomInfo>? discoveredRooms,
    bool clearSelectedCardIndex = false,
    bool clearCurrentDrawAction = false,
    bool clearMatchedCardIds = false,
  }) {
    return GameUiState(
      gameState: gameState ?? this.gameState,
      status: status ?? this.status,
      error: error ?? this.error,
      localPlayerId: localPlayerId ?? this.localPlayerId,
      isHost: isHost ?? this.isHost,
      isConnecting: isConnecting ?? this.isConnecting,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      lastEventMessage: lastEventMessage ?? this.lastEventMessage,
      selectedCardIndex: clearSelectedCardIndex
          ? null
          : (selectedCardIndex ?? this.selectedCardIndex),
      drawPhase: drawPhase ?? this.drawPhase,
      currentDrawAction: clearCurrentDrawAction
          ? null
          : (currentDrawAction ?? this.currentDrawAction),
      showDealAnimation: showDealAnimation ?? this.showDealAnimation,
      matchedCardIds: clearMatchedCardIds
          ? const []
          : (matchedCardIds ?? this.matchedCardIds),
      discoveredRooms: discoveredRooms ?? this.discoveredRooms,
    );
  }

  @override
  List<Object?> get props => [
        gameState,
        status,
        error,
        localPlayerId,
        isHost,
        isConnecting,
        isReconnecting,
        lastEventMessage,
        selectedCardIndex,
        drawPhase,
        currentDrawAction,
        showDealAnimation,
        matchedCardIds,
        discoveredRooms,
      ];
}
