/// Presentation Layer - Game Table Widget
///
/// The main game table layout showing all players and cards.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../domain/entities/entities.dart';
import '../theme/app_theme.dart';
import 'player_avatar_widget.dart';
import 'player_hand_widget.dart';

/// Game table widget with circular player arrangement
class GameTableWidget extends StatelessWidget {
  final List<Player> players;
  final String? localPlayerId;
  final String? currentPlayerId;
  final String? drawFromPlayerId;
  final Function(String playerId)? onPlayerTap;

  const GameTableWidget({
    super.key,
    required this.players,
    this.localPlayerId,
    this.currentPlayerId,
    this.drawFromPlayerId,
    this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerX = constraints.maxWidth / 2;
        final centerY = constraints.maxHeight / 2;
        final radius = math.min(centerX, centerY) * 0.65;

        // Find local player index
        final localIndex = players.indexWhere((p) => p.id == localPlayerId);

        return Stack(
          children: [
            // Table background
            Center(
              child: Container(
                width: radius * 1.6,
                height: radius * 1.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      AppColors.primaryLight.withOpacity(0.4),
                      AppColors.primary.withOpacity(0.3),
                      AppColors.primaryDark.withOpacity(0.2),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.secondary.withOpacity(0.3),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),

            // Center decoration
            Center(
              child: Container(
                width: radius * 0.6,
                height: radius * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.goldGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'K',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Players around the table
            ...List.generate(players.length, (index) {
              final player = players[index];
              final isLocal = player.id == localPlayerId;

              // Calculate position (local player at bottom)
              int adjustedIndex = index;
              if (localIndex >= 0) {
                adjustedIndex =
                    (index - localIndex + players.length) % players.length;
              }

              // Angle for this player (0 = bottom, goes clockwise)
              final angle =
                  (adjustedIndex / players.length) * 2 * math.pi - math.pi / 2;

              // Position
              final x = centerX + radius * math.cos(angle) - 50;
              final y = centerY + radius * math.sin(angle) - 60;

              final isCurrentTurn = player.id == currentPlayerId;
              final canDrawFrom = player.id == drawFromPlayerId &&
                  currentPlayerId == localPlayerId;

              return Positioned(
                left: x,
                top: y,
                child: Column(
                  children: [
                    PlayerAvatarWidget(
                      player: player,
                      isCurrentTurn: isCurrentTurn,
                      isLocalPlayer: isLocal,
                      size: isLocal ? 55 : 50,
                      onTap: canDrawFrom
                          ? () => onPlayerTap?.call(player.id)
                          : null,
                    ),
                    if (!isLocal && player.isPlaying && player.cardCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: GestureDetector(
                          onTap: canDrawFrom
                              ? () => onPlayerTap?.call(player.id)
                              : null,
                          child: OpponentHandWidget(
                            cardCount: player.cardCount,
                            isCurrentTurn: canDrawFrom,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),

            // Turn indicator in center
            if (currentPlayerId != null)
              Positioned(
                left: centerX - 60,
                top: centerY + radius * 0.2,
                child: _buildTurnIndicator(),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTurnIndicator() {
    final currentPlayer = players.firstWhere(
      (p) => p.id == currentPlayerId,
      orElse: () => players.first,
    );

    final isMyTurn = currentPlayerId == localPlayerId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isMyTurn
            ? AppColors.secondary.withOpacity(0.9)
            : AppColors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.arrow_forward,
            size: 16,
            color: isMyTurn ? AppColors.textDark : AppColors.textPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            isMyTurn ? 'Your turn!' : "${currentPlayer.name}'s turn",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isMyTurn ? AppColors.textDark : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
