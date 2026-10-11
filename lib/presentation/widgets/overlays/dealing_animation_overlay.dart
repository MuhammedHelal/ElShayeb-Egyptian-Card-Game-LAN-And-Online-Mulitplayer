import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/player.dart';
import '../common/playing_card_widget.dart';

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

class _DealingAnimationOverlayState extends State<DealingAnimationOverlay>
    with SingleTickerProviderStateMixin {
  static const _totalCards = 49;
  static const _dealIntervalMs = 50;
  static const _flightDurationMs = 500;
  static const _settleDurationMs = 150;
  static const _durationMs =
      _totalCards * _dealIntervalMs + _flightDurationMs + _settleDurationMs;
  static const _flightSlots = _flightDurationMs ~/ _dealIntervalMs;
  static const _cardWidth = 50.0;
  static const _cardHeight = _cardWidth * 1.45;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _durationMs),
    );
    if (widget.players.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onComplete();
      });
    } else {
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          widget.onComplete();
        }
      });
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.players.isEmpty) return const SizedBox.shrink();

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final center = Offset(
            constraints.maxWidth / 2,
            constraints.maxHeight / 2,
          );
          final radius = math.min(center.dx, center.dy) * 0.65;
          final localIndex =
              widget.players.indexWhere((p) => p.id == widget.localPlayerId);
          final targets = List<Offset>.generate(widget.players.length, (index) {
            final adjustedIndex = localIndex < 0
                ? index
                : (index - localIndex + widget.players.length) %
                    widget.players.length;
            final angle = adjustedIndex / widget.players.length * 2 * math.pi -
                math.pi / 2;
            return Offset(radius * math.cos(angle), radius * math.sin(angle));
          });

          // Fixed positions keep the Stack out of layout on animation frames.
          // Only paint transforms change; card faces stay cached underneath.
          return Stack(
            children: [
              Positioned(
                left: center.dx - _cardWidth / 2,
                top: center.dy - _cardHeight / 2,
                child: AnimatedBuilder(
                  animation: _controller,
                  child: const RepaintBoundary(
                    child: PlayingCardWidget(faceUp: false, width: _cardWidth),
                  ),
                  builder: (context, child) => Opacity(
                    opacity: _controller.value * _durationMs <
                            _totalCards * _dealIntervalMs
                        ? 1
                        : 0,
                    child: child,
                  ),
                ),
              ),
              // Reuse ten flight slots instead of mounting a new controller
              // per dealt card. Every flight derives from the same frame clock,
              // so a delayed frame cannot desynchronize spawning and movement.
              for (var slot = 0; slot < _flightSlots; slot++)
                Positioned(
                  left: center.dx - _cardWidth / 2,
                  top: center.dy - _cardHeight / 2,
                  child: _DealingCard(
                    key: ValueKey('dealing-card-$slot'),
                    controller: _controller,
                    slot: slot,
                    targets: targets,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DealingCard extends StatelessWidget {
  final AnimationController controller;
  final int slot;
  final List<Offset> targets;

  const _DealingCard({
    super.key,
    required this.controller,
    required this.slot,
    required this.targets,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: const RepaintBoundary(
        child: PlayingCardWidget(
          faceUp: false,
          width: _DealingAnimationOverlayState._cardWidth,
        ),
      ),
      builder: (context, child) {
        final elapsedMs =
            controller.value * _DealingAnimationOverlayState._durationMs;
        final firstStartMs =
            (slot + 1) * _DealingAnimationOverlayState._dealIntervalMs;
        final cycle = ((elapsedMs - firstStartMs) /
                _DealingAnimationOverlayState._flightDurationMs)
            .floor();
        final cardIndex =
            slot + cycle * _DealingAnimationOverlayState._flightSlots;
        final isFlying =
            cycle >= 0 && cardIndex < _DealingAnimationOverlayState._totalCards;
        final progress = isFlying
            ? ((elapsedMs -
                        firstStartMs -
                        cycle *
                            _DealingAnimationOverlayState._flightDurationMs) /
                    _DealingAnimationOverlayState._flightDurationMs)
                .clamp(0.0, 1.0)
            : 0.0;
        final easedProgress = Curves.easeOut.transform(progress);
        final target =
            isFlying ? targets[cardIndex % targets.length] : Offset.zero;

        return Opacity(
          opacity: isFlying ? 1 : 0,
          child: Transform.translate(
            offset: target * easedProgress,
            child: Transform.rotate(
              angle: easedProgress * math.pi * 2,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
