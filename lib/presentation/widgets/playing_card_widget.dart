/// Presentation Layer - Playing Card Widget
///
/// Displays a single playing card with optional animations.
/// Supports face-up, face-down, and flip animations.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../domain/entities/card.dart';
import '../theme/app_theme.dart';

/// Playing card widget
class PlayingCardWidget extends StatefulWidget {
  final PlayingCard? card;
  final bool faceUp;
  final bool isSelected;
  final bool isHighlighted;
  final Color? highlightColor;
  final bool showMatchAnimation;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const PlayingCardWidget({
    super.key,
    this.card,
    this.faceUp = true,
    this.isSelected = false,
    this.isHighlighted = false,
    this.highlightColor,
    this.showMatchAnimation = false,
    this.onTap,
    this.width = 70,
    this.height = 100,
  });

  @override
  State<PlayingCardWidget> createState() => _PlayingCardWidgetState();
}

class _PlayingCardWidgetState extends State<PlayingCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _showFront = widget.faceUp;
    if (!widget.faceUp) {
      _flipController.value = 1;
    }
  }

  @override
  void didUpdateWidget(PlayingCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.faceUp != widget.faceUp) {
      if (widget.faceUp) {
        _flipController.reverse();
      } else {
        _flipController.forward();
      }
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: CardAnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final isShowingBack = _flipAnimation.value > 0.5;
          final rotationAngle = _flipAnimation.value * math.pi;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(rotationAngle),
            child: isShowingBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _buildCardBack(),
                  )
                : _buildCardFront(),
          );
        },
      ),
    );
  }

  Widget _buildCardFront() {
    final card = widget.card;
    if (card == null) return _buildCardBack();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: widget.width,
      height: widget.height,
      transform: Matrix4.identity()
        ..translate(0.0, widget.isSelected ? -10.0 : 0.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: AppColors.cardGradient,
        boxShadow: [
          BoxShadow(
            color: widget.isHighlighted
                ? (widget.highlightColor ?? AppColors.secondary)
                    .withOpacity(0.6)
                : Colors.black.withOpacity(0.3),
            blurRadius: widget.isHighlighted ? 12 : 6,
            offset: const Offset(2, 4),
          ),
          if (widget.showMatchAnimation)
            BoxShadow(
              color: AppColors.success.withOpacity(0.8),
              blurRadius: 20,
              spreadRadius: 4,
            ),
        ],
        border: widget.isSelected
            ? Border.all(color: AppColors.secondary, width: 3)
            : widget.isHighlighted
                ? Border.all(
                    color: widget.highlightColor ?? AppColors.secondary,
                    width: 3)
                : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Card content
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top rank and suit
                  _buildRankSuit(card, alignment: CrossAxisAlignment.start),

                  // Center suit
                  Expanded(
                    child: Center(
                      child: Text(
                        card.suit.symbol,
                        style: TextStyle(
                          fontSize: widget.width * 0.4,
                          color: card.suit.isRed
                              ? AppColors.cardRed
                              : AppColors.cardBlack,
                        ),
                      ),
                    ),
                  ),

                  // Bottom rank and suit (inverted)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Transform.rotate(
                      angle: math.pi,
                      child: _buildRankSuit(card,
                          alignment: CrossAxisAlignment.start),
                    ),
                  ),
                ],
              ),
            ),

            // Match animation overlay
            if (widget.showMatchAnimation)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.success.withOpacity(0.3),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 40,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankSuit(PlayingCard card,
      {required CrossAxisAlignment alignment}) {
    final color = card.suit.isRed ? AppColors.cardRed : AppColors.cardBlack;

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          card.rank.symbol,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: widget.width * 0.18,
            color: color,
            height: 1,
          ),
        ),
        Text(
          card.suit.symbol,
          style: TextStyle(
            fontSize: widget.width * 0.14,
            color: color,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A4C7C),
            Color(0xFF0D3254),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(2, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Pattern background
            Positioned.fill(
              child: CustomPaint(
                painter: CardBackPatternPainter(),
              ),
            ),
            // Center emblem
            Center(
              child: Container(
                width: widget.width * 0.5,
                height: widget.width * 0.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.goldGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'ش',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for card back pattern
class CardBackPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 10.0;

    // Draw diagonal lines
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }

    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, size.height),
        Offset(i + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Animated builder helper for card flip animation
class CardAnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const CardAnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
