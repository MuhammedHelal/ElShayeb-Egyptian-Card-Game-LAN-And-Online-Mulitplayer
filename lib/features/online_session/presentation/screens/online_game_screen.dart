import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/localization_service.dart';
import '../../../../core/widgets/app_resume_listener.dart';
import '../../../../presentation/cubit/settings/settings_cubit.dart';
import '../../../../presentation/theme/app_theme.dart';
import '../../domain/entities/online_lobby.dart';
import '../cubit/online_session_cubit.dart';
import '../cubit/online_session_state.dart';
import '../widgets/online_game_widgets.dart';

class OnlineGameScreen extends StatefulWidget {
  const OnlineGameScreen({super.key});

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _nameController;
  late final TextEditingController _roomCodeController;

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
      child: BlocBuilder<OnlineSessionCubit, OnlineSessionState>(
        builder: (context, state) => Scaffold(
          appBar: state is OnlineSessionReady
              ? AppBar(
                  title: Text(
                    'online_room_title'.tr(
                      namedArgs: {'code': state.value.roomCode},
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: Center(
                        child: OnlineConnectionChip(
                          status: state.connectionStatus,
                          onReconnect: state.connectionStatus ==
                                  OnlineServerConnectionStatus.connected
                              ? null
                              : context.read<OnlineSessionCubit>().reconnect,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'online_leave_room'.tr(),
                      onPressed: () => _confirmLeave(context),
                      icon: const Icon(Icons.logout),
                    ),
                  ],
                )
              : null,
          body: Container(
            decoration: const BoxDecoration(gradient: AppColors.tableGradient),
            child: SafeArea(
              top: state is! OnlineSessionReady,
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
                OnlineSessionReady() => _ReadyRoomView(state: state),
              },
            ),
          ),
        ),
      ),
    );
  }

  void _createRoom(BuildContext context) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage(context, 'online_error_name'.tr());
      return;
    }
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
    context.read<OnlineSessionCubit>().joinRoom(
          roomCode: roomCode,
          playerName: name,
          avatarId: context.read<SettingsCubit>().state.avatarId,
        );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('game_leave_title'.tr()),
        content: Text('game_leave_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('game_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('game_leave'.tr()),
          ),
        ],
      ),
    );
    if (shouldLeave == true && context.mounted) {
      await context.read<OnlineSessionCubit>().leaveRoom();
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReadyRoomView extends StatelessWidget {
  final OnlineSessionReady state;

  const _ReadyRoomView({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnlineSessionCubit>();
    final isUnavailable = state.isActionInFlight ||
        state.connectionStatus != OnlineServerConnectionStatus.connected;
    return Column(
      children: [
        if (state.actionErrorMessage != null)
          OnlineActionErrorBanner(
            message: _onlineErrorTranslationKey(state.actionErrorCode).tr(),
          ),
        if (state.connectionStatus == OnlineServerConnectionStatus.reconnecting)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'online_reconnecting_notice'.tr(),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: switch (state.value.phase) {
            OnlineRoomPhase.lobby => OnlineLobbyView(
                lobby: state.value,
                isActionInFlight: isUnavailable,
                onStartGame: cubit.startGame,
              ),
            OnlineRoomPhase.playing => OnlinePlayingView(
                lobby: state.value,
                isActionInFlight: isUnavailable,
                onDrawCard: cubit.drawCard,
                onShuffle: cubit.shuffleHand,
              ),
            OnlineRoomPhase.roundEnd => OnlineRoundEndView(
                lobby: state.value,
                isActionInFlight: isUnavailable,
                onStartNewRound: cubit.startNewRound,
              ),
          },
        ),
      ],
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
