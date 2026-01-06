/// Presentation Layer - Game Widgets - Playing View
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubit/cubits.dart';
import '../widgets.dart';

// Main game view with table, overlays, and player interactions
class PlayingView extends StatelessWidget {
  final GameUiState state;

  const PlayingView({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final gameCubit = context.read<GameCubit>();

    // Find the player we can draw from
    String? drawFromId;
    if (state.isMyTurn && state.gameState != null) {
      final drawFrom = state.gameState!.drawFromPlayer;
      if (drawFrom != null) {
        drawFromId = drawFrom.id;
      }
    }

    return Stack(
      children: [
        // Game table with players
        Positioned.fill(
          child: GameTableWidget(
            players: state.players,
            localPlayerId: state.localPlayerId,
            currentPlayerId: state.currentPlayer?.id,
            drawFromPlayerId: drawFromId,
            onPlayerTap: state.isMyTurn && state.drawPhase == DrawPhase.idle
                ? (playerId) => gameCubit.initiateDrawFrom(playerId)
                : null,
          ),
        ),

        // Dealing Animation Overlay
        if (state.showDealAnimation)
          Positioned.fill(
            child: DealingAnimationOverlay(
              players: state.players,
              localPlayerId: state.localPlayerId,
              onComplete: () => gameCubit.onDealAnimationComplete(),
            ),
          ),

        // Card Steal Animation Overlay
        if (state.pendingCardStealEvent != null)
          Positioned.fill(
            child: CardStealAnimationOverlay(
              players: state.players,
              localPlayerId: state.localPlayerId,
              event: CardStealEvent(
                stealerId: state.pendingCardStealEvent!.stealerId,
                victimId: state.pendingCardStealEvent!.victimId,
                timestamp: state.pendingCardStealEvent!.timestamp,
              ),
              onComplete: () => gameCubit.onStealAnimationComplete(),
            ),
          ),

        // Event message banner
        if (state.lastEventMessage != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: EventMessageBanner(message: state.lastEventMessage!),
          ),

        // Card Selection Overlay
        if (state.drawPhase == DrawPhase.selectingCard &&
            state.drawTargetPlayer != null)
          CardSelectionOverlay(
            targetPlayer: state.drawTargetPlayer!,
            onCancel: () => gameCubit.cancelCardSelection(),
            onCardSelected: (index) => gameCubit.selectCardToDraw(index),
          ),

        // Card Reveal Overlay
        if ((state.drawPhase == DrawPhase.revealingCard ||
                state.drawPhase == DrawPhase.showingMatch) &&
            state.currentDrawAction?.drawnCard != null)
          CardRevealOverlay(
            drawnCard: state.currentDrawAction!.drawnCard!,
            matchedCard: state.currentDrawAction?.matchedCard,
            showMatch: state.drawPhase == DrawPhase.showingMatch,
          ),
      ],
    );
  }
}
