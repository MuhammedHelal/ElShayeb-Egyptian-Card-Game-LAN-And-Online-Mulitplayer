import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/entities/card.dart';
import '../../../../presentation/theme/app_theme.dart';
import '../../../../presentation/widgets/common/playing_card_widget.dart';
import '../../../../presentation/widgets/game_components/player_hand_widget.dart';
import '../../domain/entities/online_lobby.dart';

class OnlineConnectionChip extends StatelessWidget {
  final OnlineServerConnectionStatus status;
  final VoidCallback? onReconnect;

  const OnlineConnectionChip({
    super.key,
    required this.status,
    this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      OnlineServerConnectionStatus.disconnected => (
          'online_status_disconnected'.tr(),
          AppColors.textSecondary,
          Icons.cloud_off,
        ),
      OnlineServerConnectionStatus.connecting => (
          'online_status_connecting'.tr(),
          AppColors.info,
          Icons.cloud_sync,
        ),
      OnlineServerConnectionStatus.authenticating => (
          'online_status_authenticating'.tr(),
          AppColors.warning,
          Icons.verified_user_outlined,
        ),
      OnlineServerConnectionStatus.connected => (
          'online_status_connected'.tr(),
          AppColors.success,
          Icons.cloud_done,
        ),
      OnlineServerConnectionStatus.reconnecting => (
          'online_status_reconnecting'.tr(),
          AppColors.warning,
          Icons.sync,
        ),
    };

    return Semantics(
      button: onReconnect != null,
      label: label,
      hint: onReconnect == null ? null : 'online_tap_to_reconnect'.tr(),
      child: Tooltip(
        message: onReconnect == null
            ? 'online_room_connection_ok'.tr()
            : 'online_tap_to_reconnect'.tr(),
        child: InkWell(
          onTap: onReconnect,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnlineLobbyView extends StatelessWidget {
  final OnlineLobby lobby;
  final bool isActionInFlight;
  final VoidCallback onStartGame;

  const OnlineLobbyView({
    super.key,
    required this.lobby,
    required this.isActionInFlight,
    required this.onStartGame,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.groups_rounded,
                      size: 46, color: AppColors.secondary),
                  const SizedBox(height: 12),
                  Text('game_waiting_for_players'.tr(),
                      style: AppTypography.headlineMedium),
                  const SizedBox(height: 16),
                  _RoomCodeButton(roomCode: lobby.roomCode),
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 18,
                    runSpacing: 18,
                    children: [
                      for (final player in lobby.players)
                        OnlinePlayerAvatar(
                          player: player,
                          isLocalPlayer: player.userId == lobby.localUserId,
                          showCards: false,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    lobby.canStart
                        ? 'online_lobby_ready'.tr()
                        : 'online_waiting_players'.tr(),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge.copyWith(
                      color: lobby.canStart
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (lobby.canStart) ...[
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: isActionInFlight ? null : onStartGame,
                      icon: isActionInFlight
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text('online_start_game'.tr()),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnlinePlayingView extends StatelessWidget {
  final OnlineLobby lobby;
  final bool isActionInFlight;
  final ValueChanged<int> onDrawCard;
  final VoidCallback onShuffle;

  const OnlinePlayingView({
    super.key,
    required this.lobby,
    required this.isActionInFlight,
    required this.onDrawCard,
    required this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final hand = lobby.localPlayer?.hand ?? const <OnlinePlayingCard>[];
    return Column(
      children: [
        _GameStatusBar(lobby: lobby),
        Expanded(
          child: OnlineGameTable(
            lobby: lobby,
            isActionInFlight: isActionInFlight,
            onDrawCard: onDrawCard,
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.88),
              border: Border(
                top: BorderSide(
                  color: AppColors.secondary.withValues(alpha: 0.25),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'online_your_hand_count'.tr(
                        namedArgs: {'count': hand.length.toString()},
                      ),
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'online_shuffle_hand'.tr(),
                      onPressed: isActionInFlight ? null : onShuffle,
                      icon: const Icon(Icons.shuffle, size: 20),
                    ),
                  ],
                ),
                PlayerHandWidget(
                  cards: hand.map(_toPlayingCard).toList(growable: false),
                  isInteractive: false,
                  cardWidth: 58,
                  cardHeight: 84,
                  maxWidth: math.max(
                    0,
                    math.min(MediaQuery.sizeOf(context).width - 24, 520),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class OnlineGameTable extends StatelessWidget {
  final OnlineLobby lobby;
  final bool isActionInFlight;
  final ValueChanged<int> onDrawCard;

  const OnlineGameTable({
    super.key,
    required this.lobby,
    required this.isActionInFlight,
    required this.onDrawCard,
  });

  @override
  Widget build(BuildContext context) {
    final players = _localPlayerFirst(lobby);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = math.min(constraints.maxWidth * 0.92, 720.0);
        final tableHeight = math.min(constraints.maxHeight * 0.76, 410.0);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Container(
                width: tableWidth,
                height: tableHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(tableWidth / 2, tableHeight / 2),
                  ),
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryLight.withValues(alpha: 0.7),
                      AppColors.primary.withValues(alpha: 0.74),
                      AppColors.primaryDark.withValues(alpha: 0.9),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.55),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            for (var index = 0; index < players.length; index += 1)
              Align(
                alignment: _seatAlignment(index, players.length),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: OnlinePlayerAvatar(
                    player: players[index],
                    isLocalPlayer: players[index].userId == lobby.localUserId,
                    isCurrentTurn:
                        players[index].userId == lobby.currentPlayerUserId,
                  ),
                ),
              ),
            Center(
              child: _DrawArea(
                lobby: lobby,
                isActionInFlight: isActionInFlight,
                onDrawCard: onDrawCard,
              ),
            ),
          ],
        );
      },
    );
  }

  List<OnlineLobbyPlayer> _localPlayerFirst(OnlineLobby lobby) {
    final local = lobby.localPlayer;
    if (local == null) return lobby.players;
    return [local, ...lobby.players.where((p) => p.userId != local.userId)];
  }

  Alignment _seatAlignment(int index, int count) {
    if (index == 0) return const Alignment(0, 0.96);
    final opponentCount = math.max(1, count - 1);
    final angle = math.pi + (index - 0.5) * math.pi / opponentCount;
    return Alignment(math.cos(angle) * 0.92, math.sin(angle) * 0.8 - 0.08);
  }
}

class _DrawArea extends StatelessWidget {
  final OnlineLobby lobby;
  final bool isActionInFlight;
  final ValueChanged<int> onDrawCard;

  const _DrawArea({
    required this.lobby,
    required this.isActionInFlight,
    required this.onDrawCard,
  });

  @override
  Widget build(BuildContext context) {
    final target = lobby.drawFromPlayer;
    if (lobby.isPausedForDisconnectedPlayer) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.warning),
        ),
        child: Text(
          'online_waiting_reconnect'.tr(namedArgs: {
            'name': lobby.disconnectedPlayer?.name ?? 'online_player'.tr(),
          }),
          textAlign: TextAlign.center,
          style: AppTypography.titleMedium,
        ),
      );
    }
    if (!lobby.canDraw || target == null) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          'online_player_turn'.tr(namedArgs: {
            'name': lobby.currentPlayer?.name ?? 'online_player'.tr(),
          }),
          textAlign: TextAlign.center,
          style: AppTypography.titleMedium,
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 330),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'online_draw_from'.tr(namedArgs: {'name': target.name}),
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.secondaryLight,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 82,
            child: isActionInFlight
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    scrollDirection: Axis.horizontal,
                    itemCount: target.cardCount,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) => Semantics(
                      button: true,
                      label: 'online_hidden_card'.tr(
                        namedArgs: {'number': '${index + 1}'},
                      ),
                      child: PlayingCardWidget(
                        faceUp: false,
                        width: 48,
                        height: 70,
                        onTap: () => onDrawCard(index),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class OnlineRoundEndView extends StatelessWidget {
  final OnlineLobby lobby;
  final bool isActionInFlight;
  final VoidCallback onStartNewRound;

  const OnlineRoundEndView({
    super.key,
    required this.lobby,
    required this.isActionInFlight,
    required this.onStartNewRound,
  });

  @override
  Widget build(BuildContext context) {
    final ranked = [...lobby.players]..sort((a, b) {
        if (a.status == OnlinePlayerStatus.shayeb) return 1;
        if (b.status == OnlinePlayerStatus.shayeb) return -1;
        return a.finishPosition.compareTo(b.finishPosition);
      });
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events,
                      size: 54, color: AppColors.secondary),
                  Text('online_round_finished'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineMedium),
                  const SizedBox(height: 20),
                  for (var index = 0; index < ranked.length; index += 1)
                    _ScoreRow(
                      position: index + 1,
                      player: ranked[index],
                      isLocal: ranked[index].userId == lobby.localUserId,
                    ),
                  if (lobby.canStartNewRound) ...[
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      onPressed: isActionInFlight ? null : onStartNewRound,
                      icon: isActionInFlight
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.replay),
                      label: Text('online_start_new_round'.tr()),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnlinePlayerAvatar extends StatelessWidget {
  final OnlineLobbyPlayer player;
  final bool isLocalPlayer;
  final bool isCurrentTurn;
  final bool showCards;

  const OnlinePlayerAvatar({
    super.key,
    required this.player,
    required this.isLocalPlayer,
    this.isCurrentTurn = false,
    this.showCards = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor(player.avatarId);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 88,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentTurn
              ? AppColors.secondary
              : Colors.white.withValues(alpha: 0.12),
          width: isCurrentTurn ? 3 : 1,
        ),
        boxShadow: isCurrentTurn
            ? [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.45),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor:
                    player.isConnected ? color : AppColors.textSecondary,
                child: Text(_avatarEmoji(player)),
              ),
              if (showCards)
                Positioned(
                  right: -8,
                  top: -5,
                  child: _Badge(text: player.cardCount.toString()),
                ),
              Positioned(
                left: -4,
                bottom: -3,
                child: Icon(
                  player.isConnected ? Icons.circle : Icons.wifi_off,
                  size: 13,
                  color: player.isConnected
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            isLocalPlayer
                ? '${player.name} (${'online_you'.tr()})'
                : player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(
              color: isLocalPlayer
                  ? AppColors.secondaryLight
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${player.score} ${'online_points_short'.tr()}',
            style: AppTypography.bodyMedium.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Color _avatarColor(String avatarId) {
    const colors = [
      Color(0xFF4A90D9),
      Color(0xFF7C4DFF),
      Color(0xFFE91E63),
      Color(0xFF00BCD4),
      Color(0xFFFF9800),
      Color(0xFF4CAF50),
    ];
    return colors[avatarId.hashCode.abs() % colors.length];
  }

  String _avatarEmoji(OnlineLobbyPlayer player) {
    if (player.status == OnlinePlayerStatus.shayeb) return '👴';
    if (player.status == OnlinePlayerStatus.finished) return '🏆';
    const avatars = ['😀', '😎', '🤠', '🧔', '👩‍🎤', '🧑‍💻'];
    return avatars[player.avatarId.hashCode.abs() % avatars.length];
  }
}

class OnlineActionBanner extends StatelessWidget {
  final OnlineLobby lobby;

  const OnlineActionBanner({super.key, required this.lobby});

  @override
  Widget build(BuildContext context) {
    final action = lobby.lastAction;
    if (action == null) return const SizedBox.shrink();
    final actor = lobby.players
        .where((player) => player.userId == action.actorUserId)
        .firstOrNull;
    final message = switch (action.type) {
      OnlineGameActionType.gameStarted => 'event_game_started'.tr(),
      OnlineGameActionType.roundStarted => 'event_new_round_started'.tr(),
      OnlineGameActionType.handShuffled => 'event_player_shuffled'.tr(
          namedArgs: {'name': actor?.name ?? 'online_player'.tr()},
        ),
      OnlineGameActionType.playerLeft =>
        'online_player_left_disconnected'.tr(namedArgs: {
          'name': action.actorName ?? actor?.name ?? 'online_player'.tr(),
        }),
      OnlineGameActionType.cardDrawn =>
        action.actorUserId == lobby.localUserId && action.drawnCard != null
            ? (action.madePair == true
                ? 'online_you_drew_pair'.tr(
                    namedArgs: {'card': action.drawnCard!.label},
                  )
                : 'online_you_drew_card'.tr(
                    namedArgs: {'card': action.drawnCard!.label},
                  ))
            : 'event_player_drew_card'.tr(
                namedArgs: {'name': actor?.name ?? 'online_player'.tr()},
              ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey('${lobby.stateVersion}-$message'),
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: action.madePair == true
                ? AppColors.success
                : AppColors.secondary.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              action.madePair == true ? Icons.auto_awesome : Icons.casino,
              size: 18,
              color: action.madePair == true
                  ? AppColors.success
                  : AppColors.secondary,
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(message, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

class OnlineActionErrorBanner extends StatelessWidget {
  final String message;

  const OnlineActionErrorBanner({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _GameStatusBar extends StatelessWidget {
  final OnlineLobby lobby;

  const _GameStatusBar({required this.lobby});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              lobby.isPausedForDisconnectedPlayer
                  ? 'online_game_paused'.tr()
                  : lobby.canDraw
                      ? 'online_your_turn'.tr()
                      : 'online_waiting_turn'.tr(),
              style: AppTypography.titleMedium.copyWith(
                color: lobby.isPausedForDisconnectedPlayer
                    ? AppColors.warning
                    : lobby.canDraw
                        ? AppColors.secondaryLight
                        : AppColors.textSecondary,
              ),
            ),
          ),
        ),
        OnlineActionBanner(lobby: lobby),
      ],
    );
  }
}

class _RoomCodeButton extends StatelessWidget {
  final String roomCode;

  const _RoomCodeButton({required this.roomCode});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Clipboard.setData(ClipboardData(text: roomCode));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('online_room_code_copied'.tr())),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.secondary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              roomCode,
              textDirection: TextDirection.ltr,
              style: AppTypography.headlineMedium.copyWith(
                letterSpacing: 5,
                color: AppColors.secondaryLight,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.copy, size: 20, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final int position;
  final OnlineLobbyPlayer player;
  final bool isLocal;

  const _ScoreRow({
    required this.position,
    required this.player,
    required this.isLocal,
  });

  @override
  Widget build(BuildContext context) {
    final isShayeb = player.status == OnlinePlayerStatus.shayeb;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isLocal
            ? AppColors.secondary.withValues(alpha: 0.13)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isShayeb
              ? AppColors.error
              : isLocal
                  ? AppColors.secondary
                  : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Text(isShayeb ? '👴' : '#$position',
              style: AppTypography.titleMedium),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isLocal ? '${player.name} (${'online_you'.tr()})' : player.name,
              style: AppTypography.bodyLarge,
            ),
          ),
          Text(
            '${player.score} ${'online_points_short'.tr()}',
            style: AppTypography.titleMedium.copyWith(
              color: player.score < 0 ? AppColors.error : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: AppTypography.bodyMedium.copyWith(fontSize: 11)),
    );
  }
}

PlayingCard _toPlayingCard(OnlinePlayingCard card) {
  final suit = switch (card.suit) {
    OnlineCardSuit.hearts => Suit.hearts,
    OnlineCardSuit.diamonds => Suit.diamonds,
    OnlineCardSuit.clubs => Suit.clubs,
    OnlineCardSuit.spades => Suit.spades,
  };
  return PlayingCard(
    id: card.id,
    suit: suit,
    rank: Rank.values[card.rank - 1],
  );
}
