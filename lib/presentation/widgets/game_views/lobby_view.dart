/// Presentation Layer - Game Widgets - Lobby View
library;

import 'package:flutter/material.dart';

import '../../cubit/cubits.dart';
import '../../theme/app_theme.dart';
import '../../../core/localization/localization_service.dart';
import '../widgets.dart';

// Waiting for players before game starts
class LobbyView extends StatelessWidget {
  final GameUiState state;
  final Widget? connectionInfo;
  final VoidCallback? onStartGame;

  const LobbyView({
    super.key,
    required this.state,
    required this.connectionInfo,
    required this.onStartGame,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  AppStrings.gameWaitingForPlayers,
                  style: AppTypography.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.gamePlayersJoined(state.players.length),
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: state.players.map((player) {
                    return PlayerAvatarWidget(
                      player: player,
                      isLocalPlayer: player.id == state.localPlayerId,
                      showCardCount: false,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                if (connectionInfo != null) ...[
                  connectionInfo!,
                ],
                if (onStartGame != null) ...[
                  const SizedBox(height: 24),
                  if (state.gameState?.canStart == true)
                    ElevatedButton.icon(
                      onPressed: onStartGame,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(AppStrings.gameStart),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                      ),
                    )
                  else
                    Text(
                      AppStrings.gameNeedPlayers,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
