/// Presentation Layer - Card Steal Animation Overlay
///
/// Displays a polished, performant animation when a card is stolen
/// from one player to another. Only shown to non-active players.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../domain/entities/player.dart';
import '../theme/app_theme.dart';
import 'playing_card_widget.dart';

/// Event data for card steal animation
class CardStealEvent {
  /// ID of the player who stole the card (active player)
  final String stealerId;

  /// ID of the player who lost the card
  final String victimId;

  /// Timestamp for animation synchronization
  final DateTime timestamp;

  const CardStealEvent({
    required this.stealerId,
    required this.victimId,
    required this.timestamp,
  });

  /// Unique key for this event to prevent duplicate animations
  String get key =>
      '${stealerId}_$victimId}${timestamp.millisecondsSinceEpoch}';

  /// Convert to JSON for network serialization
  Map<String, dynamic> toJson() => {
        'stealerId': stealerId,
        'victimId': victimId,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Create from JSON for network deserialization
  factory CardStealEvent.fromJson(Map<String, dynamic> json) {
    return CardStealEvent(
      stealerId: json['stealerId'] as String,
      victimId: json['victimId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Overlay widget that displays the card steal animation
class CardStealAnimationOverlay extends StatefulWidget {
  /// List of players for position calculation
  final List<Player> players;

  /// Local player ID for seat position calculation
  final String? localPlayerId;

  /// The steal event to animate
  final CardStealEvent event;

  /// Callback when animation completes
  final VoidCallback onComplete;

  /// Animation duration (default 650ms for smooth feel)
  final Duration duration;

  const CardStealAnimationOverlay({
    super.key,
    required this.players,
    this.localPlayerId,
    required this.event,
    required this.onComplete,
    this.duration = const Duration(milliseconds: 650),
  });

  @override
  State<CardStealAnimationOverlay> createState() =>
      _CardStealAnimationOverlayState();
}

class _CardStealAnimationOverlayState extends State<CardStealAnimationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _shadowAnimation;
  late Animation<double> _glowAnimation;

  // Cached positions
  Offset? _startPosition;
  Offset? _endPosition;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Smooth position curve with ease-in-out cubic
    _positionAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    // Subtle scale animation: starts normal, grows slightly in middle, ends normal
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_controller);

    // Subtle rotation: tilts slightly during movement
    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.05)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.05, end: -0.08)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.08, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    // Shadow/elevation animation for depth
    _shadowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 4.0, end: 16.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 16.0, end: 4.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_controller);

    // Subtle glow animation for visual polish
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.6)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.6, end: 0.3),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.3, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
    ]).animate(_controller);

    // Start animation and call onComplete when done
    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Calculate player position on the circular table
  Offset _calculatePlayerPosition(
    String playerId,
    Size screenSize,
    double radius,
  ) {
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;

    // Find player index
    final playerIndex = widget.players.indexWhere((p) => p.id == playerId);
    if (playerIndex == -1) {
      return Offset(centerX, centerY);
    }

    // Find local player index for relative positioning
    final localIndex =
        widget.players.indexWhere((p) => p.id == widget.localPlayerId);

    // Calculate adjusted index (local player at bottom)
    int adjustedIndex = playerIndex;
    if (localIndex >= 0) {
      adjustedIndex = (playerIndex - localIndex + widget.players.length) %
          widget.players.length;
    }

    // Angle for this player (0 = bottom, goes clockwise)
    final angle =
        (adjustedIndex / widget.players.length) * 2 * math.pi - math.pi / 2;

    // Position (offset to center on avatar)
    final x = centerX + radius * math.cos(angle);
    final y = centerY + radius * math.sin(angle);

    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;
        final radius = math.min(centerX, centerY) * 0.65;

        // Calculate positions if not cached
        if (!_initialized) {
          _startPosition = _calculatePlayerPosition(
            widget.event.victimId,
            screenSize,
            radius,
          );
          _endPosition = _calculatePlayerPosition(
            widget.event.stealerId,
            screenSize,
            radius,
          );
          _initialized = true;
        }

        // Fallback if positions couldn't be calculated
        if (_startPosition == null || _endPosition == null) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Calculate current position
                final currentX = _startPosition!.dx +
                    (_endPosition!.dx - _startPosition!.dx) *
                        _positionAnimation.value;
                final currentY = _startPosition!.dy +
                    (_endPosition!.dy - _startPosition!.dy) *
                        _positionAnimation.value;

                return Positioned(
                  left: currentX - 30, // Center the card
                  top: currentY - 42, // Center the card
                  child: _buildAnimatedCard(),
                );
              },
            ),

            // Light trail effect (subtle)
            if (_positionAnimation.value > 0.1 &&
                _positionAnimation.value < 0.9)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    size: screenSize,
                    painter: _CardTrailPainter(
                      start: _startPosition!,
                      end: _endPosition!,
                      progress: _positionAnimation.value,
                      opacity: _glowAnimation.value * 0.3,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedCard() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scale(_scaleAnimation.value)
            ..rotateZ(_rotationAnimation.value),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                // Main shadow for depth
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: _shadowAnimation.value,
                  spreadRadius: _shadowAnimation.value / 4,
                  offset: Offset(0, _shadowAnimation.value / 2),
                ),
                // Subtle glow effect
                BoxShadow(
                  color: AppColors.secondary.withOpacity(_glowAnimation.value),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const PlayingCardWidget(
              card: null, // Card back (hidden)
              faceUp: false,
              width: 60,
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for subtle trail effect
class _CardTrailPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final double progress;
  final double opacity;

  _CardTrailPainter({
    required this.start,
    required this.end,
    required this.progress,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.secondary.withOpacity(0),
          AppColors.secondary.withOpacity(opacity),
          AppColors.secondary.withOpacity(0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromPoints(start, end))
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw trail from start to current position
    final currentX = start.dx + (end.dx - start.dx) * progress;
    final currentY = start.dy + (end.dy - start.dy) * progress;
    final currentPos = Offset(currentX, currentY);

    // Trail starts fading in from behind
    final trailStart = Offset(
      start.dx + (end.dx - start.dx) * math.max(0, progress - 0.3),
      start.dy + (end.dy - start.dy) * math.max(0, progress - 0.3),
    );

    final path = Path()
      ..moveTo(trailStart.dx, trailStart.dy)
      ..lineTo(currentPos.dx, currentPos.dy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CardTrailPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}

/// Queue manager for handling multiple steal animations
/// This ensures animations play sequentially without overlap
class CardStealAnimationQueue extends ChangeNotifier {
  final List<CardStealEvent> _queue = [];
  CardStealEvent? _currentEvent;
  final Set<String> _processedEventKeys = {};

  /// Maximum number of processed event keys to keep (for cleanup)
  static const int _maxProcessedKeys = 50;

  /// Whether an animation is currently playing
  bool get isAnimating => _currentEvent != null;

  /// Current event being animated
  CardStealEvent? get currentEvent => _currentEvent;

  /// Add a steal event to the queue
  /// Returns false if the event was already processed (duplicate)
  bool enqueue(CardStealEvent event) {
    // Prevent duplicate animations
    if (_processedEventKeys.contains(event.key)) {
      return false;
    }

    // Check if event is too old (skip if more than 3 seconds old)
    final now = DateTime.now();
    if (now.difference(event.timestamp).inMilliseconds > 3000) {
      _processedEventKeys.add(event.key);
      return false;
    }

    _queue.add(event);
    _processedEventKeys.add(event.key);

    // Cleanup old processed keys
    if (_processedEventKeys.length > _maxProcessedKeys) {
      final keysToRemove =
          _processedEventKeys.take(_maxProcessedKeys ~/ 2).toList();
      for (final key in keysToRemove) {
        _processedEventKeys.remove(key);
      }
    }

    // Start animating if not already
    if (_currentEvent == null) {
      _startNextAnimation();
    }

    return true;
  }

  /// Start the next animation in the queue
  void _startNextAnimation() {
    if (_queue.isEmpty) {
      _currentEvent = null;
      notifyListeners();
      return;
    }

    _currentEvent = _queue.removeAt(0);
    notifyListeners();
  }

  /// Called when current animation completes
  void onAnimationComplete() {
    _currentEvent = null;
    _startNextAnimation();
  }

  /// Clear all pending animations
  void clear() {
    _queue.clear();
    _currentEvent = null;
    notifyListeners();
  }

  /// Check if player is the active player (should not see animation)
  static bool shouldShowAnimation({
    required String localPlayerId,
    required String stealerId,
  }) {
    // Active player doesn't see the animation (they interact directly)
    return localPlayerId != stealerId;
  }
}
