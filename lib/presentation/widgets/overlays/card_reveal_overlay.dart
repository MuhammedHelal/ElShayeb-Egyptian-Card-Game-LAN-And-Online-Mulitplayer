/// Presentation Layer - Card Reveal Overlay Widget
///
/// Full-screen overlay for revealing a drawn card and showing match animation.
library;

import 'package:flutter/material.dart';

import '../../../core/localization/localization_service.dart';
import '../../../domain/entities/entities.dart';
import '../../theme/app_theme.dart';
import '../common/playing_card_widget.dart';

class CardRevealOverlay extends StatefulWidget {
  final PlayingCard drawnCard;
  final PlayingCard? matchedCard;
  final bool showMatch;
  final VoidCallback? onComplete;

  const CardRevealOverlay({
    super.key,
    required this.drawnCard,
    this.matchedCard,
    this.showMatch = false,
    this.onComplete,
  });

  @override
  State<CardRevealOverlay> createState() => _CardRevealOverlayState();
}

class _CardRevealOverlayState extends State<CardRevealOverlay>
    with TickerProviderStateMixin {
  late AnimationController _revealController;
  late AnimationController _matchController;
  late Animation<double> _flipAnimation;
  late Animation<double> _matchScaleAnimation;
  late Animation<double> _exitAnimation;

  @override
  void initState() {
    super.initState();

    _revealController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _matchController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeInOut),
    );

    _matchScaleAnimation = Tween<double>(begin: 1, end: 1.1).animate(
      CurvedAnimation(parent: _matchController, curve: Curves.elasticOut),
    );

    _exitAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _matchController,
        curve: const Interval(0.5, 1, curve: Curves.easeIn),
      ),
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    // Flip to reveal card
    await _revealController.forward();

    if (widget.showMatch && widget.matchedCard != null) {
      // Pulse animation for match
      await _matchController.forward();
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    _matchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.8),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_revealController, _matchController]),
          builder: (context, child) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        widget.showMatch ? AppStrings.cardMatch : 'You drew:',
                        style: AppTypography.headlineMedium.copyWith(
                          color: widget.showMatch
                              ? AppColors.secondary
                              : AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Cards
                      if (widget.showMatch && widget.matchedCard != null)
                        _buildMatchDisplay()
                      else
                        _buildSingleCard(),

                      const SizedBox(height: 32),

                      // Card name
                      Text(
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        widget.drawnCard.displayName,
                        style: AppTypography.displayMedium.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSingleCard() {
    const double cardWidth = 120;
    const double cardHeight = cardWidth * 1.45;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(_flipAnimation.value * 3.14159),
      child: _flipAnimation.value < 0.5
          ? const PlayingCardWidget(
              card: null,
              faceUp: false,
              width: cardWidth,
              height: cardHeight,
            )
          : Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(3.14159),
              child: PlayingCardWidget(
                card: widget.drawnCard,
                faceUp: true,
                width: cardWidth,
                height: cardHeight,
              ),
            ),
    );
  }

  Widget _buildMatchDisplay() {
    final exitOffset = _exitAnimation.value * 300;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Drawn card
        Transform.translate(
          offset: Offset(-exitOffset, -exitOffset),
          child: Opacity(
            opacity: 1 - _exitAnimation.value,
            child: ScaleTransition(
              scale: _matchScaleAnimation,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.8),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: PlayingCardWidget(
                  card: widget.drawnCard,
                  faceUp: true,
                  width: 100,
                  height: 145,
                  isHighlighted: true,
                  highlightColor: Colors.orange,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 24),

        // Match indicator
        Opacity(
          opacity: 1 - _exitAnimation.value,
          child: const Icon(
            Icons.favorite,
            color: Colors.orange,
            size: 40,
          ),
        ),

        const SizedBox(width: 24),

        // Matched card
        Transform.translate(
          offset: Offset(exitOffset, exitOffset),
          child: Opacity(
            opacity: 1 - _exitAnimation.value,
            child: ScaleTransition(
              scale: _matchScaleAnimation,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.8),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: PlayingCardWidget(
                  card: widget.matchedCard!,
                  faceUp: true,
                  width: 100,
                  height: 145,
                  isHighlighted: true,
                  highlightColor: Colors.orange,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
