/// Presentation Layer - Scoreboard Widget
///
/// Displays player rankings and scores.
library;

import 'package:flutter/material.dart';

import '../../core/localization/localization_service.dart';
import '../../domain/entities/player.dart';
import '../theme/app_theme.dart';

/// Scoreboard widget showing all players sorted by score
class ScoreboardWidget extends StatelessWidget {
  final List<Player> players;
  final String? localPlayerId;
  final bool showRoundResults;

  const ScoreboardWidget({
    super.key,
    required this.players,
    this.localPlayerId,
    this.showRoundResults = false,
  });

  @override
  Widget build(BuildContext context) {
    // Sort by finish position for round results, or by score
    final sortedPlayers = List<Player>.from(players);
    if (showRoundResults) {
      sortedPlayers.sort((a, b) {
        if (a.finishPosition == 0) return 1;
        if (b.finishPosition == 0) return -1;
        return a.finishPosition.compareTo(b.finishPosition);
      });
    } else {
      sortedPlayers.sort((a, b) => b.score.compareTo(a.score));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, color: AppColors.textDark),
                const SizedBox(width: 8),
                Text(
                  showRoundResults
                      ? AppStrings.scoreboardRoundResults
                      : AppStrings.scoreboardTitle,
                  style: AppTypography.headlineMedium.copyWith(
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),

          // Player list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: sortedPlayers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final player = sortedPlayers[index];
              return _buildPlayerRow(player, index + 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(Player player, int rank) {
    final isLocal = player.id == localPlayerId;
    final isShayeb = player.isShayeb;

    // Determine score change for round results
    int? scoreChange;
    if (showRoundResults) {
      if (isShayeb) {
        scoreChange = -50;
      } else {
        final scores = {1: 100, 2: 60, 3: 40, 4: 20, 5: 10};
        scoreChange = scores[player.finishPosition];
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isLocal ? AppColors.secondary.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _getRankGradient(rank, isShayeb),
            ),
            child: Center(
              child: Text(
                isShayeb ? '👴' : _getRankEmoji(rank),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Player name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      player.name,
                      style: AppTypography.titleMedium.copyWith(
                        color: isLocal
                            ? AppColors.secondary
                            : AppColors.textPrimary,
                        fontWeight:
                            isLocal ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isLocal)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(AppStrings.scoreboardYou,
                            style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                if (isShayeb)
                  Text(
                    AppStrings.scoreboardShayeb,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),

          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppStrings.scoreboardPts(player.score),
                style: AppTypography.titleMedium.copyWith(
                  color:
                      player.score >= 0 ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (scoreChange != null)
                Text(
                  '${scoreChange >= 0 ? '+' : ''}$scoreChange',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        scoreChange >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  LinearGradient _getRankGradient(int rank, bool isShayeb) {
    if (isShayeb) {
      return const LinearGradient(
        colors: [Color(0xFF8B0000), Color(0xFF5C0000)],
      );
    }

    switch (rank) {
      case 1:
        return const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
        );
      case 2:
        return const LinearGradient(
          colors: [Color(0xFFC0C0C0), Color(0xFF808080)],
        );
      case 3:
        return const LinearGradient(
          colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
        );
      default:
        return const LinearGradient(
          colors: [AppColors.surfaceLight, AppColors.surface],
        );
    }
  }

  String _getRankEmoji(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '$rank';
    }
  }
}
