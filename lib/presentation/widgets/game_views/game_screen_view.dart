import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/localization_service.dart';
import '../../cubit/game/game_state.dart';
import '../../theme/app_theme.dart';
import '../game_components/scoreboard_widget.dart';
import 'player_hand_view.dart';
import 'top_bar.dart';

/// Shared in-game shell used by LAN and online sessions.
class GameScreenView extends StatelessWidget {
  final GameUiState state;
  final String connectionInfo;
  final Widget content;
  final Future<void> Function() onLeave;
  final VoidCallback? onShuffle;
  final ValueChanged<int>? onCardTap;

  const GameScreenView({
    super.key,
    required this.state,
    required this.connectionInfo,
    required this.content,
    required this.onLeave,
    required this.onShuffle,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showExitDialog(context);
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.tableGradient),
          child: SafeArea(
            child: Column(
              children: [
                TopBar(
                  connectionInfo: connectionInfo,
                  onMenuPressed: () => _showGameMenu(context),
                  onScoreboardPressed: () => _showScoreboard(context),
                  onRoomCodeTap: () => _copyConnectionInfo(context),
                ),
                Expanded(
                  child: AbsorbPointer(
                    absorbing: state.showDealAnimation,
                    child: content,
                  ),
                ),
                if (state.localPlayer != null &&
                    state.isPlaying &&
                    !state.showDealAnimation)
                  PlayerHandView(
                    state: state,
                    onShuffle: onShuffle,
                    onCardTap: onCardTap,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showExitDialog(BuildContext context) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.gameLeaveTitle),
        content: Text(AppStrings.gameLeaveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.gameCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppStrings.gameLeave),
          ),
        ],
      ),
    );
    if (shouldLeave != true || !context.mounted) return;
    await onLeave();
    if (context.mounted) Navigator.pop(context);
  }

  void _showGameMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.leaderboard),
              title: Text(AppStrings.gameScoreboard),
              onTap: () {
                Navigator.pop(sheetContext);
                _showScoreboard(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(AppStrings.gameSettings),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.pushNamed(context, '/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: AppColors.error),
              title: Text(
                AppStrings.gameLeaveGame,
                style: const TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showExitDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showScoreboard(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ScoreboardWidget(
            players: state.players,
            localPlayerId: state.localPlayerId,
          ),
        ),
      ),
    );
  }

  void _copyConnectionInfo(BuildContext context) {
    Clipboard.setData(ClipboardData(text: connectionInfo));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.gameCopied),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
