import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/localization_service.dart';
import '../../../../core/audio_manager.dart';
import '../../../../core/haptic_manager.dart';
import '../../../../core/widgets/app_resume_listener.dart';
import '../../../../domain/entities/entities.dart';
import '../../../../presentation/cubit/game/game_cubit.dart';
import '../../../../presentation/cubit/settings/settings_cubit.dart';
import '../../../../presentation/theme/app_theme.dart';
import '../../../../presentation/widgets/widgets.dart';
import '../../domain/entities/online_lobby.dart';
import '../cubit/online_session_cubit.dart';
import '../cubit/online_session_state.dart';
import '../widgets/online_game_widgets.dart';

class OnlineGameScreen extends StatefulWidget {
  final AudioManager audioManager;
  final HapticManager hapticManager;

  const OnlineGameScreen({
    super.key,
    required this.audioManager,
    required this.hapticManager,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _nameController;
  late final TextEditingController _roomCodeController;
  bool _createdRoom = false;
  OnlineRoomPhase? _lastRoomPhase;
  OnlinePlayerStatus? _lastLocalPlayerStatus;
  int? _lastHandledStateVersion;
  DrawPhase _drawPhase = DrawPhase.idle;
  DrawActionInfo? _drawAction;
  CardStealEventInfo? _pendingCardStealEvent;
  bool _showDealAnimation = false;
  int? _selectedCardIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController = TextEditingController(
      text: context.read<SettingsCubit>().state.playerName,
    );
    _roomCodeController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.locale;
    final cubit = context.read<OnlineSessionCubit>();
    return AppResumeListener(
      onInitial: cubit.restoreSession,
      onResume: cubit.onAppResumed,
      child: BlocConsumer<OnlineSessionCubit, OnlineSessionState>(
        listener: _handleSessionState,
        builder: (context, state) => state is OnlineSessionReady
            ? _buildGame(context, state)
            : _buildRoomEntry(context, state),
      ),
    );
  }

  Widget _buildRoomEntry(BuildContext context, OnlineSessionState state) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.tableGradient),
        child: SafeArea(
          child: switch (state) {
            OnlineSessionInitial() => _RoomEntryView(
                tabController: _tabController,
                nameController: _nameController,
                roomCodeController: _roomCodeController,
                onCreate: () => _createRoom(context),
                onJoin: () => _joinRoom(context),
              ),
            OnlineSessionLoading() => _RoomEntryView(
                tabController: _tabController,
                nameController: _nameController,
                roomCodeController: _roomCodeController,
                isLoading: true,
                onCreate: () => _createRoom(context),
                onJoin: () => _joinRoom(context),
              ),
            OnlineSessionFailure(:final code) => _RoomEntryView(
                tabController: _tabController,
                nameController: _nameController,
                roomCodeController: _roomCodeController,
                errorMessage: _onlineErrorTranslationKey(code).tr(),
                onCreate: () => _createRoom(context),
                onJoin: () => _joinRoom(context),
              ),
            OnlineSessionReady() => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }

  Widget _buildGame(BuildContext context, OnlineSessionReady session) {
    final lobby = session.value;
    final isUnavailable = session.isActionInFlight ||
        session.connectionStatus != OnlineServerConnectionStatus.connected;
    final canManageLobby = _createdRoom || lobby.canStart;
    final uiState = _toGameUiState(lobby, isHost: canManageLobby);
    final cubit = context.read<OnlineSessionCubit>();

    return GameScreenView(
      state: uiState,
      connectionInfo: lobby.roomCode,
      onLeave: cubit.leaveRoom,
      onShuffle: isUnavailable ? null : () => _shuffleHand(cubit),
      onCardTap: isUnavailable ? null : (index) => _selectHandCard(index),
      content: Stack(
        children: [
          Positioned.fill(
            child: switch (lobby.phase) {
              OnlineRoomPhase.lobby => LobbyView(
                  state: uiState,
                  connectionInfo: HostConnectionInfo(
                    isLan: false,
                    connectionInfo: lobby.roomCode,
                    roomCode: lobby.roomCode,
                  ),
                  onStartGame:
                      canManageLobby && !isUnavailable ? cubit.startGame : null,
                ),
              OnlineRoomPhase.playing => PlayingView(
                  state: uiState,
                  drawFromPlayerId: lobby.canDraw ? lobby.drawFromUserId : null,
                  onPlayerTap: isUnavailable
                      ? null
                      : (playerId) => _startCardSelection(lobby, playerId),
                  onDealAnimationComplete: () =>
                      setState(() => _showDealAnimation = false),
                  onStealAnimationComplete: () =>
                      setState(() => _pendingCardStealEvent = null),
                  onCancelCardSelection: _cancelCardSelection,
                  onCardSelected: (index) => _selectOnlineCard(lobby, index),
                ),
              OnlineRoomPhase.roundEnd => RoundEndView(
                  state: uiState,
                  onStartNewRound: lobby.canStartNewRound && !isUnavailable
                      ? () => _startNewRound(cubit)
                      : null,
                ),
            },
          ),
          if (session.actionErrorMessage != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: OnlineActionErrorBanner(
                message:
                    _onlineErrorTranslationKey(session.actionErrorCode).tr(),
              ),
            ),
          if (session.connectionStatus !=
              OnlineServerConnectionStatus.connected)
            Positioned(
              top: session.actionErrorMessage == null ? 0 : 56,
              left: 0,
              right: 0,
              child: _ConnectionNotice(
                status: session.connectionStatus,
                onReconnect: cubit.reconnect,
              ),
            ),
        ],
      ),
    );
  }

  void _createRoom(BuildContext context) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage(context, 'online_error_name'.tr());
      return;
    }
    _createdRoom = true;
    context.read<OnlineSessionCubit>().createRoom(
          playerName: name,
          avatarId: context.read<SettingsCubit>().state.avatarId,
        );
  }

  void _joinRoom(BuildContext context) {
    final name = _nameController.text.trim();
    final roomCode = _roomCodeController.text.trim();
    if (name.isEmpty || roomCode.length != 6) {
      _showMessage(context, 'online_error_join_fields'.tr());
      return;
    }
    _createdRoom = false;
    context.read<OnlineSessionCubit>().joinRoom(
          roomCode: roomCode,
          playerName: name,
          avatarId: context.read<SettingsCubit>().state.avatarId,
        );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleSessionState(BuildContext context, OnlineSessionState state) {
    if (state is! OnlineSessionReady) {
      _lastRoomPhase = null;
      _lastLocalPlayerStatus = null;
      _lastHandledStateVersion = null;
      return;
    }

    final lobby = state.value;
    final previousPhase = _lastRoomPhase;
    final previousLocalStatus = _lastLocalPlayerStatus;
    final shouldDeal = _lastRoomPhase == OnlineRoomPhase.lobby &&
        lobby.phase == OnlineRoomPhase.playing;
    final shouldFinishRound = previousPhase == OnlineRoomPhase.playing &&
        lobby.phase == OnlineRoomPhase.roundEnd;
    final localStatus = lobby.localPlayer?.status;
    final shouldCelebrateFinish = !shouldFinishRound &&
        previousLocalStatus == OnlinePlayerStatus.playing &&
        localStatus == OnlinePlayerStatus.finished;
    final action = lobby.lastAction;
    final shouldAnimateSteal = _lastHandledStateVersion != null &&
        _lastHandledStateVersion != lobby.stateVersion &&
        action?.type == OnlineGameActionType.cardDrawn &&
        action?.actorUserId != lobby.localUserId &&
        action?.targetUserId != null;

    _lastRoomPhase = lobby.phase;
    _lastLocalPlayerStatus = localStatus;
    _lastHandledStateVersion = lobby.stateVersion;

    if (shouldDeal) {
      unawaited(widget.audioManager.playSoundEffect(SoundEffect.deal));
      unawaited(widget.hapticManager.cardDraw());
    }
    if (shouldFinishRound) {
      final didLose = localStatus == OnlinePlayerStatus.shayeb;
      unawaited(widget.audioManager.playSoundEffect(
        didLose ? SoundEffect.lose : SoundEffect.win,
      ));
      unawaited(
        didLose
            ? widget.hapticManager.defeat()
            : widget.hapticManager.victory(),
      );
    } else if (shouldCelebrateFinish) {
      unawaited(widget.audioManager.playSoundEffect(SoundEffect.win));
      unawaited(widget.hapticManager.victory());
    }

    if (shouldDeal || shouldAnimateSteal) {
      setState(() {
        if (shouldDeal) _showDealAnimation = true;
        if (shouldAnimateSteal) {
          _pendingCardStealEvent = CardStealEventInfo(
            stealerId: action!.actorUserId,
            victimId: action.targetUserId!,
            timestamp: DateTime.now(),
          );
        }
      });
    }
  }

  void _startCardSelection(OnlineLobby lobby, String playerId) {
    if (!lobby.canDraw || lobby.drawFromUserId != playerId) return;
    unawaited(widget.hapticManager.cardTap());
    setState(() {
      _drawPhase = DrawPhase.selectingCard;
      _drawAction = DrawActionInfo(targetPlayerId: playerId);
    });
  }

  void _cancelCardSelection() {
    setState(() {
      _drawPhase = DrawPhase.idle;
      _drawAction = null;
    });
  }

  Future<void> _selectOnlineCard(OnlineLobby lobby, int cardIndex) async {
    final target = lobby.drawFromPlayer;
    if (_drawPhase != DrawPhase.selectingCard ||
        target == null ||
        cardIndex < 0 ||
        cardIndex >= target.cardCount) {
      return;
    }

    final previousHand = lobby.localPlayer?.hand ?? const <OnlinePlayingCard>[];
    setState(() => _drawPhase = DrawPhase.completing);
    await context.read<OnlineSessionCubit>().drawCard(cardIndex);
    if (!mounted) return;

    final latestState = context.read<OnlineSessionCubit>().state;
    final latestLobby =
        latestState is OnlineSessionReady ? latestState.value : null;
    final action = latestLobby?.lastAction;
    if (latestLobby == null ||
        latestLobby.stateVersion <= lobby.stateVersion ||
        action?.type != OnlineGameActionType.cardDrawn ||
        action?.actorUserId != lobby.localUserId ||
        action?.targetUserId != target.userId ||
        action?.drawnCard == null) {
      _cancelCardSelection();
      return;
    }

    final drawnCard = _toPlayingCard(action!.drawnCard!);
    unawaited(widget.audioManager.playSoundEffect(SoundEffect.flip));
    unawaited(widget.hapticManager.cardDraw());
    PlayingCard? matchedCard;
    if (action.madePair == true) {
      for (final card in previousHand) {
        if (card.rank == action.drawnCard!.rank) {
          matchedCard = _toPlayingCard(card);
          break;
        }
      }
    }

    setState(() {
      _drawPhase = DrawPhase.revealingCard;
      _drawAction = DrawActionInfo(
        targetPlayerId: target.userId,
        selectedCardIndex: cardIndex,
        drawnCard: drawnCard,
        matchedCard: matchedCard,
        madeMatch: matchedCard != null,
      );
    });
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    if (matchedCard != null) {
      setState(() => _drawPhase = DrawPhase.showingMatch);
      unawaited(widget.audioManager.playSoundEffect(SoundEffect.match));
      unawaited(widget.hapticManager.matchFound());
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
    }
    _cancelCardSelection();
  }

  void _selectHandCard(int index) {
    setState(() => _selectedCardIndex = index);
    unawaited(widget.hapticManager.cardTap());
  }

  Future<void> _shuffleHand(OnlineSessionCubit cubit) async {
    await cubit.shuffleHand();
    if (mounted) unawaited(widget.hapticManager.cardTap());
  }

  Future<void> _startNewRound(OnlineSessionCubit cubit) async {
    await cubit.startNewRound();
    if (mounted) {
      unawaited(widget.audioManager.playSoundEffect(SoundEffect.deal));
    }
  }

  GameUiState _toGameUiState(OnlineLobby lobby, {required bool isHost}) {
    final players = lobby.players
        .map((player) => _toPlayer(player, lobby.localUserId, isHost))
        .toList(growable: false);
    final currentPlayerIndex = players.indexWhere(
      (player) => player.id == lobby.currentPlayerUserId,
    );
    final gameState = GameState(
      roomId: lobby.roomCode,
      roomCode: lobby.roomCode,
      players: players,
      currentPlayerIndex: currentPlayerIndex < 0 ? 0 : currentPlayerIndex,
      phase: switch (lobby.phase) {
        OnlineRoomPhase.lobby => GamePhase.lobby,
        OnlineRoomPhase.playing => GamePhase.playing,
        OnlineRoomPhase.roundEnd => GamePhase.roundEnd,
      },
      roundNumber: lobby.roundNumber,
      hostId: isHost ? lobby.localUserId : '',
    );
    return GameUiState(
      gameState: gameState,
      status: LoadingStatus.success,
      localPlayerId: lobby.localUserId,
      isHost: isHost,
      isReconnecting: false,
      lastEventMessage: _onlineActionMessage(lobby),
      selectedCardIndex: _selectedCardIndex,
      drawPhase: _drawPhase,
      currentDrawAction: _drawAction,
      showDealAnimation: _showDealAnimation,
      pendingCardStealEvent: _pendingCardStealEvent,
    );
  }
}

Player _toPlayer(
  OnlineLobbyPlayer player,
  String localUserId,
  bool isHost,
) {
  final visibleHand = player.hand;
  final hand = visibleHand != null
      ? visibleHand.map(_toPlayingCard).toList(growable: false)
      : List<PlayingCard>.generate(
          player.cardCount,
          (index) => PlayingCard(
            id: 'hidden_${player.userId}_$index',
            suit: Suit.spades,
            rank: Rank.ace,
          ),
          growable: false,
        );
  return Player(
    id: player.userId,
    name: player.name,
    avatarId: player.avatarId,
    hand: hand,
    score: player.score,
    status: switch (player.status) {
      OnlinePlayerStatus.playing => PlayerStatus.playing,
      OnlinePlayerStatus.finished => PlayerStatus.finished,
      OnlinePlayerStatus.shayeb => PlayerStatus.shayeb,
    },
    finishPosition: player.finishPosition,
    isHost: isHost && player.userId == localUserId,
    isConnected: player.isConnected,
  );
}

PlayingCard _toPlayingCard(OnlinePlayingCard card) {
  return PlayingCard(
    id: card.id,
    suit: switch (card.suit) {
      OnlineCardSuit.hearts => Suit.hearts,
      OnlineCardSuit.diamonds => Suit.diamonds,
      OnlineCardSuit.clubs => Suit.clubs,
      OnlineCardSuit.spades => Suit.spades,
    },
    rank: Rank.values[card.rank - 1],
  );
}

String? _onlineActionMessage(OnlineLobby lobby) {
  final action = lobby.lastAction;
  if (action == null) return null;
  OnlineLobbyPlayer? actor;
  for (final player in lobby.players) {
    if (player.userId == action.actorUserId) {
      actor = player;
      break;
    }
  }
  final actorName = action.actorName ?? actor?.name ?? 'online_player'.tr();
  return switch (action.type) {
    OnlineGameActionType.gameStarted => 'event_game_started'.tr(),
    OnlineGameActionType.roundStarted => 'event_new_round_started'.tr(),
    OnlineGameActionType.handShuffled =>
      'event_player_shuffled'.tr(namedArgs: {'name': actorName}),
    OnlineGameActionType.playerLeft =>
      'online_player_left_disconnected'.tr(namedArgs: {'name': actorName}),
    OnlineGameActionType.cardDrawn =>
      action.actorUserId == lobby.localUserId && action.drawnCard != null
          ? (action.madePair == true
              ? 'online_you_drew_pair'.tr(
                  namedArgs: {'card': action.drawnCard!.label},
                )
              : 'online_you_drew_card'.tr(
                  namedArgs: {'card': action.drawnCard!.label},
                ))
          : 'event_player_drew_card'.tr(namedArgs: {'name': actorName}),
  };
}

class _ConnectionNotice extends StatelessWidget {
  final OnlineServerConnectionStatus status;
  final VoidCallback onReconnect;

  const _ConnectionNotice({
    required this.status,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: OnlineConnectionChip(
          status: status,
          onReconnect: onReconnect,
        ),
      ),
    );
  }
}

class _RoomEntryView extends StatelessWidget {
  final TabController tabController;
  final TextEditingController nameController;
  final TextEditingController roomCodeController;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const _RoomEntryView({
    required this.tabController,
    required this.nameController,
    required this.roomCodeController,
    required this.onCreate,
    required this.onJoin,
    this.errorMessage,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Text(
                AppStrings.lobbyOnlineGame,
                style: AppTypography.headlineMedium,
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: tabController,
            indicator: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: AppColors.textDark,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: AppTypography.labelLarge,
            dividerHeight: 0,
            tabs: [
              Tab(text: AppStrings.lobbyCreateRoom),
              Tab(text: AppStrings.lobbyJoinRoom),
            ],
          ),
        ),
        if (errorMessage case final message?)
          OnlineActionErrorBanner(message: message),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _buildCreateTab(context),
              _buildJoinTab(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreateTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              Icons.add_circle_outline,
              size: 60,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            AppStrings.lobbyCreateNewRoom,
            style: AppTypography.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.lobbyHostOnline,
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildNameField(context),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onCreate,
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                isLoading
                    ? AppStrings.lobbyCreating
                    : AppStrings.lobbyCreateRoomBtn,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildNameField(context),
          const SizedBox(height: 24),
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
            ),
            child: const Icon(
              Icons.login,
              size: 50,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.lobbyEnterRoomCode,
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: roomCodeController,
            decoration: InputDecoration(
              labelText: AppStrings.lobbyRoomCode,
              prefixIcon: const Icon(Icons.vpn_key),
              hintText: 'online_room_code_hint'.tr(),
            ),
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: isLoading ? null : (_) => onJoin(),
            maxLength: 6,
            textAlign: TextAlign.center,
            style: AppTypography.headlineMedium.copyWith(letterSpacing: 4),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              _UpperCaseTextFormatter(),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onJoin,
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(
                isLoading
                    ? AppStrings.lobbyJoining
                    : AppStrings.lobbyJoinRoomBtn,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(BuildContext context) {
    return TextField(
      controller: nameController,
      maxLength: 24,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: AppStrings.lobbyYourName,
        prefixIcon: const Icon(Icons.person),
      ),
      onChanged: context.read<SettingsCubit>().setPlayerName,
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

String _onlineErrorTranslationKey(String? code) {
  return switch (code) {
    'invalid_room_code' => 'online_error_invalid_room',
    'room_not_found' => 'online_error_room_not_found',
    'room_full' => 'online_error_room_full',
    'game_in_progress' => 'online_error_game_in_progress',
    'invalid_player_name' => 'online_error_name',
    'authentication_failed' => 'online_error_authentication',
    'stale_state' => 'online_error_state_changed',
    _ => 'online_error_connection',
  };
}
