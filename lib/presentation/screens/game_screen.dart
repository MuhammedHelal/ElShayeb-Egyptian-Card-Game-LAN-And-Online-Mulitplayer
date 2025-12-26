/// Presentation Layer - Game Screen
///
/// Main in-game screen with table, cards, and player interactions.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/localization_service.dart';
import '../../domain/entities/entities.dart';
import '../cubit/cubits.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Main game screen
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late AnimationController _dealAnimController;

  @override
  void initState() {
    super.initState();
    _dealAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _dealAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameCubit, GameUiState>(
      builder: (context, state) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              _showExitDialog(context);
            }
          },
          child: Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.tableGradient,
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Top bar
                    _buildTopBar(context, state),

                    // Game content
                    Expanded(
                      child: _buildGameContent(context, state),
                    ),

                    // Player's hand at bottom
                    if (state.localPlayer != null && state.isPlaying)
                      _buildPlayerHand(context, state),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context, GameUiState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Menu button
          IconButton(
            onPressed: () => _showGameMenu(context, state),
            icon: const Icon(Icons.menu),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface.withOpacity(0.5),
            ),
          ),

          const Spacer(),

          // Room code
          GestureDetector(
            onTap: () => _copyRoomCode(context, state),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.secondary.withOpacity(0.3),
                ),
              ),
              child: Wrap(
                children: [
                  const Icon(Icons.vpn_key,
                      size: 16, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Text(
                    context.read<GameCubit>().connectionInfo,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy,
                      size: 14, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Scoreboard button
          IconButton(
            onPressed: () => _showScoreboard(context, state),
            icon: const Icon(Icons.leaderboard),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent(BuildContext context, GameUiState state) {
    switch (state.phase) {
      case GamePhase.lobby:
        return _buildLobbyView(context, state);
      case GamePhase.dealing:
        return _buildDealingView(context, state);
      case GamePhase.playing:
        return _buildPlayingView(context, state);
      case GamePhase.roundEnd:
        return _buildRoundEndView(context, state);
      case GamePhase.gameEnd:
        return _buildGameEndView(context, state);
    }
  }

  Widget _buildLobbyView(BuildContext context, GameUiState state) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Waiting for players
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.secondary.withOpacity(0.3),
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

                // Player list
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

                // Share info
                if (state.isHost) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          context.read<GameCubit>().currentMode == GameMode.lan
                              ? AppStrings.gameShareAddress
                              : AppStrings.gameShareCode,
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        if (context.read<GameCubit>().currentMode ==
                            GameMode.lan) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.wifi,
                                  color: AppColors.secondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.read<GameCubit>().connectionInfo,
                                  style: AppTypography.headlineMedium.copyWith(
                                    color: AppColors.secondary,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            state.roomCode,
                            style: AppTypography.displayMedium.copyWith(
                              color: AppColors.secondary,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _copyConnectionInfo(context),
                          icon: const Icon(Icons.copy, size: 16),
                          label: Text(AppStrings.lobbyCopy),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Start button
                  if (state.gameState?.canStart == true)
                    ElevatedButton.icon(
                      onPressed: () => context.read<GameCubit>().startGame(),
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

  Widget _buildDealingView(BuildContext context, GameUiState state) {
    // Fallback if we stay in dealing phase, though usually we animate in playing phase
    return DealingAnimationOverlay(
      players: state.players,
      localPlayerId: state.localPlayerId,
      onComplete: () => context.read<GameCubit>().onDealAnimationComplete(),
    );
  }

  Widget _buildPlayingView(BuildContext context, GameUiState state) {
    // Find the player we can draw from
    String? drawFromId;
    if (state.isMyTurn && state.gameState != null) {
      final drawFrom = state.gameState!.drawFromPlayer;
      if (drawFrom != null) {
        drawFromId = drawFrom.id;
      }
    }

    return Stack(
      children: [
        // Game table with players
        Positioned.fill(
          child: GameTableWidget(
            players: state.players,
            localPlayerId: state.localPlayerId,
            currentPlayerId: state.currentPlayer?.id,
            drawFromPlayerId: drawFromId,
            onPlayerTap: state.isMyTurn && state.drawPhase == DrawPhase.idle
                ? (playerId) =>
                    context.read<GameCubit>().initiateDrawFrom(playerId)
                : null,
          ),
        ),

        // Dealing Animation Overlay
        if (state.showDealAnimation)
          Positioned.fill(
            child: DealingAnimationOverlay(
              players: state.players,
              localPlayerId: state.localPlayerId,
              onComplete: () =>
                  context.read<GameCubit>().onDealAnimationComplete(),
            ),
          ),

        // Card Steal Animation Overlay (only for non-active players)
        if (state.pendingCardStealEvent != null)
          Positioned.fill(
            child: CardStealAnimationOverlay(
              players: state.players,
              localPlayerId: state.localPlayerId,
              event: CardStealEvent(
                stealerId: state.pendingCardStealEvent!.stealerId,
                victimId: state.pendingCardStealEvent!.victimId,
                timestamp: state.pendingCardStealEvent!.timestamp,
              ),
              onComplete: () =>
                  context.read<GameCubit>().onStealAnimationComplete(),
            ),
          ),

        // Turn indicator overlay (only when idle and not animating)
        if (state.isMyTurn &&
            state.drawPhase == DrawPhase.idle &&
            !state.showDealAnimation)
          Positioned(
            left: 0,
            right: 0,
            bottom: 150,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.5),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app, color: AppColors.textDark),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.gameYourTurn,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Event message - Top Center, non-blocking
        if (state.lastEventMessage != null &&
            state.lastEventMessage != "State synchronized")
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      state.lastEventMessage!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Card Selection Overlay
        if (state.drawPhase == DrawPhase.selectingCard &&
            state.drawTargetPlayer != null)
          CardSelectionOverlay(
            targetPlayer: state.drawTargetPlayer!,
            onCancel: () => context.read<GameCubit>().cancelCardSelection(),
            onCardSelected: (index) =>
                context.read<GameCubit>().selectCardToDraw(index),
          ),

        // Card Reveal Overlay
        if ((state.drawPhase == DrawPhase.revealingCard ||
                state.drawPhase == DrawPhase.showingMatch) &&
            state.currentDrawAction?.drawnCard != null)
          CardRevealOverlay(
            drawnCard: state.currentDrawAction!.drawnCard!,
            matchedCard: state.currentDrawAction?.matchedCard,
            showMatch: state.drawPhase == DrawPhase.showingMatch,
          ),
      ],
    );
  }

  Widget _buildRoundEndView(BuildContext context, GameUiState state) {
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
          if (state.isHost)
            ElevatedButton.icon(
              onPressed: () => context.read<GameCubit>().startNewRound(),
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

  Widget _buildGameEndView(BuildContext context, GameUiState state) {
    return _buildRoundEndView(context, state);
  }

  Widget _buildPlayerHand(BuildContext context, GameUiState state) {
    final localPlayer = state.localPlayer;
    if (localPlayer == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Shuffle hand button
          if (localPlayer.isPlaying && localPlayer.hand.length > 1)
            TextButton.icon(
              onPressed: () => context.read<GameCubit>().shuffleHand(),
              icon: const Icon(Icons.shuffle,
                  size: 16, color: AppColors.secondary),
              label: Text(
                AppStrings.gameShuffleHand,
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.secondary),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.surface.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          PlayerHandWidget(
            cards: localPlayer.hand,
            selectedIndex: state.selectedCardIndex,
            matchedCardIds: state.matchedCardIds,
            isInteractive: state.isMyTurn && state.drawPhase == DrawPhase.idle,
            onCardTap: (index) => context.read<GameCubit>().selectCard(index),
            maxWidth: MediaQuery.of(context).size.width - 32,
          ),
        ],
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.gameLeaveTitle),
        content: Text(AppStrings.gameLeaveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.gameCancel),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<GameCubit>().leaveGame();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(AppStrings.gameLeave),
          ),
        ],
      ),
    );
  }

  void _showGameMenu(BuildContext context, GameUiState state) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.leaderboard),
              title: Text(AppStrings.gameScoreboard),
              onTap: () {
                Navigator.pop(context);
                _showScoreboard(context, state);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(AppStrings.gameSettings),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: AppColors.error),
              title: Text(AppStrings.gameLeaveGame,
                  style: const TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _showExitDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showScoreboard(BuildContext context, GameUiState state) {
    showDialog(
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

  void _copyRoomCode(BuildContext context, GameUiState state) {
    final gameCubit = context.read<GameCubit>();
    final textToCopy = gameCubit.currentMode == GameMode.lan
        ? gameCubit.connectionInfo
        : state.roomCode;
    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.gameCopied),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _copyConnectionInfo(BuildContext context) {
    final gameCubit = context.read<GameCubit>();
    final textToCopy = gameCubit.currentMode == GameMode.lan
        ? gameCubit.connectionInfo
        : gameCubit.state.roomCode;
    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.gameCopied),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
