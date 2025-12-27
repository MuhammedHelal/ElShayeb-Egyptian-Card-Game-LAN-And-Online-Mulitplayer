import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/entities/player.dart';
import 'playing_card_widget.dart';

class DealingAnimationOverlay extends StatefulWidget {
  final List<Player> players;
  final String? localPlayerId;
  final VoidCallback onComplete;

  const DealingAnimationOverlay({
    super.key,
    required this.players,
    this.localPlayerId,
    required this.onComplete,
  });

  @override
  State<DealingAnimationOverlay> createState() =>
      _DealingAnimationOverlayState();
}

class _DealingAnimationOverlayState extends State<DealingAnimationOverlay> {
  final int _totalCards = 49;
  final List<_FlyingCard> _activeCards = [];
  Timer? _dealTimer;
  int _cardsDealt = 0;

  @override
  void initState() {
    super.initState();
    _startDealing();
  }

  void _startDealing() {
    // Deal one card every 50ms
    _dealTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_cardsDealt >= _totalCards) {
        timer.cancel();
        // Allow last card to land before completing
        Future.delayed(const Duration(milliseconds: 600), widget.onComplete);
        return;
      }

      final playerIndex = _cardsDealt % widget.players.length;
      _spawnCard(playerIndex);
      _cardsDealt++;
    });
  }

  void _spawnCard(int targetPlayerIndex) {
    if (!mounted) return;
    setState(() {
      _activeCards.add(_FlyingCard(
        id: _cardsDealt,
        targetPlayerIndex: targetPlayerIndex,
        startTime: DateTime.now(),
      ));
    });
  }

  @override
  void dispose() {
    _dealTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;
        final radius = math.min(centerX, centerY) * 0.65;
        final localIndex =
            widget.players.indexWhere((p) => p.id == widget.localPlayerId);

        // Remove landed cards to improve performance
        final now = DateTime.now();
        _activeCards.removeWhere(
            (c) => now.difference(c.startTime).inMilliseconds > 600);

        return Stack(
          children: [
            // Deck in center
            if (_cardsDealt < _totalCards)
              Positioned(
                left: centerX - 25,
                top: centerY - 35,
                child: const PlayingCardWidget(
                  card: null,
                  faceUp: false,
                  width: 50,
                ),
              ),

            // Flying cards
            ..._activeCards.map((flyingCard) {
              // Calculate target position using same logic as GameTableWidget
              int adjustedIndex = flyingCard.targetPlayerIndex;
              if (localIndex >= 0) {
                adjustedIndex = (flyingCard.targetPlayerIndex -
                        localIndex +
                        widget.players.length) %
                    widget.players.length;
              }

              final angle =
                  (adjustedIndex / widget.players.length) * 2 * math.pi -
                      math.pi / 2;

              // Target avatar position
              // Note: GameTableWidget centers avatar at (x,y), avatar size ~55
              // We want card to land near the avatar
              final targetX = centerX +
                  radius * math.cos(angle) -
                  25; // -25 for center of card width 50
              final targetY = centerY +
                  radius * math.sin(angle) -
                  35; // -35 for center of card height 70

              return _AnimatedFlyingCard(
                startX: centerX - 25,
                startY: centerY - 35,
                targetX: targetX,
                targetY: targetY,
                startTime: flyingCard.startTime,
              );
            }),
          ],
        );
      },
    );
  }
}

class _FlyingCard {
  final int id;
  final int targetPlayerIndex;
  final DateTime startTime;

  _FlyingCard({
    required this.id,
    required this.targetPlayerIndex,
    required this.startTime,
  });
}

class _AnimatedFlyingCard extends StatefulWidget {
  final double startX;
  final double startY;
  final double targetX;
  final double targetY;
  final DateTime startTime;

  const _AnimatedFlyingCard({
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.startTime,
  });

  @override
  State<_AnimatedFlyingCard> createState() => _AnimatedFlyingCardState();
}

class _AnimatedFlyingCardState extends State<_AnimatedFlyingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late double _currentX;
  late double _currentY;

  @override
  void initState() {
    super.initState();
    // Calculate elapsed time since spawn to sync animation if rebuilt
    final elapsed = DateTime.now().difference(widget.startTime).inMilliseconds;
    double startValue = (elapsed / 500.0).clamp(0.0, 1.0); // 500ms duration

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward(from: startValue);

    _currentX = widget.startX;
    _currentY = widget.startY;

    _controller.addListener(() {
      setState(() {
        _currentX =
            widget.startX + (widget.targetX - widget.startX) * _animation.value;
        _currentY =
            widget.startY + (widget.targetY - widget.startY) * _animation.value;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _currentX,
      top: _currentY,
      child: Transform.rotate(
        angle: _animation.value * math.pi * 2, // Spin while flying
        child: const PlayingCardWidget(
          card: null,
          faceUp: false,
          width: 50,
        ),
      ),
    );
  }
}
