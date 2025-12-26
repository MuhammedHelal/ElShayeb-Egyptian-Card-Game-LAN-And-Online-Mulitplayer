/// Presentation Layer - Player Hand Widget
///
/// Displays the player's hand with spread cards and drag support.
library;

import 'package:flutter/material.dart';

import '../../../domain/entities/card.dart';
import '../theme/app_theme.dart';
import 'playing_card_widget.dart';

/// Player hand widget showing spread cards
class PlayerHandWidget extends StatelessWidget {
  final List<PlayingCard> cards;
  final int? selectedIndex;
  final List<String> matchedCardIds;
  final bool isInteractive;
  final Function(int index)? onCardTap;
  final double cardWidth;
  final double cardHeight;
  final double maxWidth;

  const PlayerHandWidget({
    super.key,
    required this.cards,
    this.selectedIndex,
    this.matchedCardIds = const [],
    this.isInteractive = true,
    this.onCardTap,
    this.cardWidth = 65,
    this.cardHeight = 95,
    this.maxWidth = 350,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Container(
        height: cardHeight + 30,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.secondary.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            '🎉 No cards left!',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.success,
            ),
          ),
        ),
      );
    }

    // Calculate overlap to fit cards
    final totalWidth = cards.length * cardWidth;
    double overlap = 0;
    if (totalWidth > maxWidth) {
      overlap = (totalWidth - maxWidth) / (cards.length - 1);
    }
    final effectiveCardWidth = cardWidth - overlap;
    final handWidth = effectiveCardWidth * (cards.length - 1) + cardWidth;

    return Container(
      height: cardHeight + 30, // Extra space for selection raise
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppColors.surface.withOpacity(0.5),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Center(
        child: SizedBox(
          width: handWidth.clamp(0, maxWidth),
          height: cardHeight + 20,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(cards.length, (index) {
              final card = cards[index];
              final isSelected = selectedIndex == index;
              final isMatched = matchedCardIds.contains(card.id);

              return AnimatedPositioned(
                key: ValueKey(card.id),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                left: index * effectiveCardWidth,
                bottom: isSelected ? 10 : 0,
                child: PlayingCardWidget(
                  card: card,
                  isSelected: isSelected,
                  showMatchAnimation: isMatched,
                  onTap: isInteractive ? () => onCardTap?.call(index) : null,
                  width: cardWidth,
                  height: cardHeight,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Fan-style hand for other players (cards face down)
class OpponentHandWidget extends StatelessWidget {
  final int cardCount;
  final bool isCurrentTurn;
  final VoidCallback? onTap;
  final double arcAngle;
  final double cardWidth;
  final double cardHeight;

  const OpponentHandWidget({
    super.key,
    required this.cardCount,
    this.isCurrentTurn = false,
    this.onTap,
    this.arcAngle = 0.3,
    this.cardWidth = 45,
    this.cardHeight = 65,
  });

  @override
  Widget build(BuildContext context) {
    if (cardCount == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isCurrentTurn
              ? [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: SizedBox(
          width: cardWidth * 1.5 + (cardCount - 1) * 8,
          height: cardHeight * 1.2,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(cardCount.clamp(0, 10), (index) {
              final angle =
                  (index - (cardCount - 1) / 2) * arcAngle / cardCount;

              return AnimatedPositioned(
                key: ValueKey('opponent_card_$index'),
                duration: const Duration(milliseconds: 400),
                left: index * 8.0,
                child: Transform.rotate(
                  angle: angle,
                  child: PlayingCardWidget(
                    faceUp: false,
                    width: cardWidth,
                    height: cardHeight,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
