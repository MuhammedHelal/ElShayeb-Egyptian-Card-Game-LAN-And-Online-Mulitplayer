/// Presentation Layer - Player Avatar Widget
///
/// Displays a player avatar with name, card count, and status indicators.
library;

import 'package:flutter/material.dart';

import '../../../domain/entities/player.dart';
import '../theme/app_theme.dart';

/// Player avatar widget
class PlayerAvatarWidget extends StatelessWidget {
  final Player player;
  final bool isCurrentTurn;
  final bool isLocalPlayer;
  final bool showCardCount;
  final bool compact;
  final VoidCallback? onTap;
  final double size;

  const PlayerAvatarWidget({
    super.key,
    required this.player,
    this.isCurrentTurn = false,
    this.isLocalPlayer = false,
    this.showCardCount = true,
    this.compact = false,
    this.onTap,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar circle with status
            Stack(
              children: [
                // Glow effect for current turn
                if (isCurrentTurn)
                  Container(
                    width: size + 8,
                    height: size + 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.6),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),

                // Avatar container
                Container(
                  width: size,
                  height: size,
                  margin: EdgeInsets.all(isCurrentTurn ? 4 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _getAvatarGradient(),
                    border: Border.all(
                      color: _getBorderColor(),
                      width: isCurrentTurn ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _getAvatarEmoji(),
                      style: TextStyle(fontSize: size * 0.5),
                    ),
                  ),
                ),

                // Status badge
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _buildStatusBadge(),
                ),

                // Card count badge
                if (showCardCount && player.cardCount > 0)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _buildCardCountBadge(),
                  ),
              ],
            ),

            const SizedBox(height: 4),

            // Player name
            if (!compact)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isLocalPlayer
                      ? AppColors.secondary.withOpacity(0.2)
                      : AppColors.surface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  player.name,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isLocalPlayer
                        ? AppColors.secondary
                        : AppColors.textPrimary,
                    fontWeight:
                        isLocalPlayer ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Score
            if (!compact)
              Text(
                '${player.score} pts',
                style: AppTypography.bodyMedium.copyWith(
                  color:
                      player.score >= 0 ? AppColors.success : AppColors.error,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getAvatarGradient() {
    if (player.isShayeb) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8B0000), Color(0xFF5C0000)],
      );
    }
    if (player.hasFinished) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.success, Color(0xFF1E7D32)],
      );
    }
    if (!player.isConnected) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.grey.shade600, Colors.grey.shade800],
      );
    }

    // Default gradient based on avatar ID
    final colorIndex = int.tryParse(player.avatarId.split('_').last) ?? 1;
    final gradients = [
      const [Color(0xFF4A90D9), Color(0xFF2E5A8E)],
      const [Color(0xFF7C4DFF), Color(0xFF4A2E94)],
      const [Color(0xFFE91E63), Color(0xFF9C1459)],
      const [Color(0xFF00BCD4), Color(0xFF00838F)],
      const [Color(0xFFFF9800), Color(0xFFE65100)],
      const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
    ];
    final colors = gradients[(colorIndex - 1) % gradients.length];

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  Color _getBorderColor() {
    if (isCurrentTurn) return AppColors.secondary;
    if (player.isShayeb) return AppColors.error;
    if (player.hasFinished) return AppColors.success;
    if (isLocalPlayer) return AppColors.secondary.withOpacity(0.6);
    return Colors.white.withOpacity(0.3);
  }

  String _getAvatarEmoji() {
    if (player.isShayeb) return '👴';
    if (player.hasFinished) return '🏆';
    if (!player.isConnected) return '📡';

    final avatars = ['😀', '😎', '🤠', '👨‍💻', '👩‍🎤', '🧔'];
    final index = int.tryParse(player.avatarId.split('_').last) ?? 1;
    return avatars[(index - 1) % avatars.length];
  }

  Widget _buildStatusBadge() {
    IconData icon;
    Color color;

    if (player.isShayeb) {
      icon = Icons.elderly;
      color = AppColors.error;
    } else if (player.hasFinished) {
      icon = Icons.check_circle;
      color = AppColors.success;
    } else if (!player.isConnected) {
      icon = Icons.wifi_off;
      color = AppColors.warning;
    } else if (player.isHost) {
      icon = Icons.star;
      color = AppColors.secondary;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: size * 0.35,
      height: size * 0.35,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: AppColors.background, width: 2),
      ),
      child: Icon(
        icon,
        size: size * 0.2,
        color: Colors.white,
      ),
    );
  }

  Widget _buildCardCountBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Text(
        '${player.cardCount}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
