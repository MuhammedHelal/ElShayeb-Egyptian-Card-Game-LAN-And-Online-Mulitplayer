/// Presentation Layer - Card Selection Overlay Widget
///
/// Full-screen overlay for selecting a card from opponent's hand.
/// Shows cards face-down in a fan layout for selection.
library;

import 'package:flutter/material.dart';

import '../../domain/entities/entities.dart';
import '../theme/app_theme.dart';
import 'playing_card_widget.dart';

/// Overlay for selecting a card from opponent's hand
class CardSelectionOverlay extends StatefulWidget {
  final Player targetPlayer;
  final VoidCallback onCancel;
  final void Function(int index) onCardSelected;

  const CardSelectionOverlay({
    super.key,
    required this.targetPlayer,
    required this.onCancel,
    required this.onCardSelected,
  });

  @override
  State<CardSelectionOverlay> createState() => _CardSelectionOverlayState();
}

class _CardSelectionOverlayState extends State<CardSelectionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardCount = widget.targetPlayer.hand.length;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.black.withOpacity(0.85),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Close button
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.close, size: 28),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Player info
                    _buildPlayerInfo(),

                    const SizedBox(height: 24),

                    // Instructions
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, color: AppColors.textDark),
                          SizedBox(width: 8),
                          Text(
                            'Tap a card to draw it!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Cards area
              Expanded(
                child: Center(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildCardFan(cardCount),
                  ),
                ),
              ),

              // Bottom padding
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Avatar
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.secondary,
            boxShadow: [
              BoxShadow(
                color: AppColors.secondary.withOpacity(0.5),
                blurRadius: 16,
              ),
            ],
          ),
          child: Center(
            child: Text(
              _getAvatarEmoji(widget.targetPlayer.avatarId),
              style: const TextStyle(fontSize: 32),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.targetPlayer.name,
              style: AppTypography.headlineMedium,
            ),
            Text(
              '${widget.targetPlayer.cardCount} cards',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardFan(int cardCount) {
    if (cardCount == 0) {
      return const Text('No cards!');
    }

    // Calculate layout based on card count
    const double maxSpread = 280;
    const double cardWidth = 80;
    final double overlap =
        cardCount > 1 ? (maxSpread - cardWidth) / (cardCount - 1) : 0;
    final double totalWidth = cardWidth + overlap * (cardCount - 1);
    final double startOffset = -totalWidth / 2 + cardWidth / 2;

    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: List.generate(cardCount, (index) {
          final isHovered = _hoveredIndex == index;
          final xOffset = startOffset + index * overlap;

          // Calculate rotation for fan effect
          final normalizedIndex = cardCount > 1
              ? (index - (cardCount - 1) / 2) / ((cardCount - 1) / 2)
              : 0.0;
          final rotation = normalizedIndex * 0.1; // Max 0.1 radians rotation

          return AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left:
                MediaQuery.of(context).size.width / 2 + xOffset - cardWidth / 2,
            top: isHovered ? 0 : 20,
            child: GestureDetector(
              onTap: () => widget.onCardSelected(index),
              onTapDown: (_) => setState(() => _hoveredIndex = index),
              onTapCancel: () => setState(() => _hoveredIndex = null),
              onTapUp: (_) => setState(() => _hoveredIndex = null),
              child: AnimatedScale(
                scale: isHovered ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Transform.rotate(
                  angle: rotation,
                  child: Container(
                    width: cardWidth,
                    height: cardWidth * 1.4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: isHovered
                              ? AppColors.secondary.withOpacity(0.6)
                              : Colors.black.withOpacity(0.3),
                          blurRadius: isHovered ? 20 : 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          // Card back
                          const PlayingCardWidget(
                            card: null,
                            faceUp: false,
                            width: 80,
                          ),

                          // Selection indicator
                          if (isHovered)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.secondary,
                                  width: 3,
                                ),
                              ),
                            ),

                          // Card number
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Text(
                              '${index + 1}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  String _getAvatarEmoji(String avatarId) {
    final avatars = ['😀', '😎', '🤠', '👨‍💻', '👩‍🎤', '🧔'];
    final index = int.tryParse(avatarId.split('_').last) ?? 1;
    return avatars[(index - 1).clamp(0, avatars.length - 1)];
  }
}

/// Overlay for revealing a drawn card and showing match animation
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
      child: AnimatedBuilder(
        animation: Listenable.merge([_revealController, _matchController]),
        builder: (context, child) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  widget.showMatch ? '🎉 Match! 🎉' : 'You drew:',
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
                  widget.drawnCard.displayName,
                  style: AppTypography.displayMedium.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSingleCard() {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(_flipAnimation.value * 3.14159),
      child: _flipAnimation.value < 0.5
          ? const PlayingCardWidget(
              card: null,
              faceUp: false,
              width: 120,
            )
          : Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(3.14159),
              child: PlayingCardWidget(
                card: widget.drawnCard,
                faceUp: true,
                width: 120,
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
