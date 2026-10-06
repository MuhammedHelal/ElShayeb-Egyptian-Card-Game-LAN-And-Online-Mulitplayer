/// Presentation Layer - Game Widgets - Game Content
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubit/cubits.dart';
import '../../../domain/entities/entities.dart';
import '../widgets.dart';

// Routes to correct game phase view
class GameContent extends StatelessWidget {
  final GameUiState state;

  const GameContent({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    switch (state.phase) {
      case GamePhase.lobby:
        final gameCubit = context.read<GameCubit>();
        return LobbyView(
          state: state,
          connectionInfo: state.isHost
              ? HostConnectionInfo(
                  isLan: gameCubit.currentMode == GameMode.lan,
                  connectionInfo: gameCubit.connectionInfo,
                  roomCode: state.roomCode,
                )
              : null,
          onStartGame: state.isHost ? gameCubit.startGame : null,
        );
      case GamePhase.dealing:
        return DealingAnimationOverlay(
          players: state.players,
          localPlayerId: state.localPlayerId,
          onComplete: () => context.read<GameCubit>().onDealAnimationComplete(),
        );
      case GamePhase.playing:
        final gameCubit = context.read<GameCubit>();
        final drawFromPlayerId =
            state.isMyTurn ? state.gameState?.drawFromPlayer?.id : null;
        return PlayingView(
          state: state,
          drawFromPlayerId: drawFromPlayerId,
          onPlayerTap: gameCubit.initiateDrawFrom,
          onDealAnimationComplete: gameCubit.onDealAnimationComplete,
          onStealAnimationComplete: gameCubit.onStealAnimationComplete,
          onCancelCardSelection: gameCubit.cancelCardSelection,
          onCardSelected: gameCubit.selectCardToDraw,
        );
      case GamePhase.roundEnd:
      case GamePhase.gameEnd:
        return RoundEndView(
          state: state,
          onStartNewRound:
              state.isHost ? context.read<GameCubit>().startNewRound : null,
        );
    }
  }
}
