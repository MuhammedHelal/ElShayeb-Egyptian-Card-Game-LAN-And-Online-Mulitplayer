/// Presentation Layer - Game Widgets - Round End View
library;

import 'package:flutter/material.dart';

import '../../cubit/cubits.dart';
import '../../../core/localization/localization_service.dart';
import '../widgets.dart';

// Round/game end scoreboard view
class RoundEndView extends StatelessWidget {
  final GameUiState state;
  final VoidCallback? onStartNewRound;

  const RoundEndView({
    super.key,
    required this.state,
    required this.onStartNewRound,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScoreboardWidget(
            players: state.players,
            localPlayerId: state.localPlayerId,
            showRoundResults: true,
          ),
          const SizedBox(height: 24),
          if (onStartNewRound != null)
            ElevatedButton.icon(
              onPressed: onStartNewRound,
              icon: const Icon(Icons.refresh),
              label: Text(AppStrings.gameNewRound),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
