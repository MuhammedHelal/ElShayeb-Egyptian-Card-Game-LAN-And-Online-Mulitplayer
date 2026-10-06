/// Presentation Layer - Game Widgets - Playing View
library;

import 'package:flutter/material.dart';

import '../../cubit/cubits.dart';

import '../widgets.dart';

// Main game view with table, overlays, and player interactions
class PlayingView extends StatelessWidget {
  final GameUiState state;
  final String? drawFromPlayerId;
  final ValueChanged<String>? onPlayerTap;
  final VoidCallback onDealAnimationComplete;
  final VoidCallback onStealAnimationComplete;
  final VoidCallback onCancelCardSelection;
  final ValueChanged<int> onCardSelected;

  const PlayingView({
    super.key,
    required this.state,
    required this.drawFromPlayerId,
    required this.onPlayerTap,
    required this.onDealAnimationComplete,
    required this.onStealAnimationComplete,
    required this.onCancelCardSelection,
    required this.onCardSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Game table with players
        Positioned.fill(
          child: GameTableWidget(
            players: state.players,
            localPlayerId: state.localPlayerId,
            currentPlayerId: state.currentPlayer?.id,
            drawFromPlayerId: drawFromPlayerId,
            onPlayerTap: state.isMyTurn && state.drawPhase == DrawPhase.idle
                ? onPlayerTap
                : null,
          ),
        ),

        // Dealing Animation Overlay
        if (state.showDealAnimation)
          Positioned.fill(
            child: DealingAnimationOverlay(
              players: state.players,
              localPlayerId: state.localPlayerId,
              onComplete: onDealAnimationComplete,
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
              onComplete: onStealAnimationComplete,
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
            onCancel: onCancelCardSelection,
            onCardSelected: onCardSelected,
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
