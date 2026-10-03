import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _roomCodeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _roomCodeController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.locale;
    return Scaffold(
      appBar: AppBar(
        title: BlocSelector<OnlineSessionCubit, OnlineSessionState, String?>(
          selector: (state) =>
              state is OnlineSessionReady ? state.value.roomCode : null,
          builder: (context, roomCode) => Text(
            roomCode == null
                ? 'online_lobby_title'.tr()
                : 'online_room_title'.tr(namedArgs: {'code': roomCode}),
          ),
        ),
        actions: [
          BlocSelector<OnlineSessionCubit, OnlineSessionState,
              OnlineServerConnectionStatus>(
            selector: (state) => state.connectionStatus,
            builder: (context, status) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Center(child: OnlineConnectionChip(status: status)),
            ),
          ),
          BlocSelector<OnlineSessionCubit, OnlineSessionState, bool>(
            selector: (state) => state is OnlineSessionReady,
            builder: (context, isInRoom) => isInRoom
                ? IconButton(
                    tooltip: 'online_leave_room'.tr(),
                    onPressed: () => _confirmLeave(context),
                    icon: const Icon(Icons.logout),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.tableGradient),
        child: SafeArea(
          top: false,
          child: BlocBuilder<OnlineSessionCubit, OnlineSessionState>(
            builder: (context, state) => switch (state) {
              OnlineSessionInitial() => _RoomEntryView(
                  nameController: _nameController,
                  roomCodeController: _roomCodeController,
                  onCreate: () => _createRoom(context),
                  onJoin: () => _joinRoom(context),
                ),
              OnlineSessionLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              OnlineSessionFailure(:final message, :final code) =>
                _RoomEntryView(
                  nameController: _nameController,
                  roomCodeController: _roomCodeController,
                  errorMessage: code == null ? message : '$message ($code)',
                  onCreate: () => _createRoom(context),
                  onJoin: () => _joinRoom(context),
                ),
              OnlineSessionReady() => _ReadyRoomView(state: state),
            },
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
          avatarId: 'avatar_${name.hashCode.abs() % 6 + 1}',
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
          avatarId: 'avatar_${name.hashCode.abs() % 6 + 1}',
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
    return Column(
      children: [
        if (state.actionErrorMessage case final message?)
          OnlineActionErrorBanner(
            message: message,
            code: state.actionErrorCode,
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
                isActionInFlight: state.isActionInFlight,
                onStartGame: cubit.startGame,
              ),
            OnlineRoomPhase.playing => OnlinePlayingView(
                lobby: state.value,
                isActionInFlight: state.isActionInFlight,
                onDrawCard: cubit.drawCard,
                onShuffle: cubit.shuffleHand,
              ),
            OnlineRoomPhase.roundEnd => OnlineRoundEndView(
                lobby: state.value,
                isActionInFlight: state.isActionInFlight,
                onStartNewRound: cubit.startNewRound,
              ),
          },
        ),
      ],
    );
  }
}

class _RoomEntryView extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController roomCodeController;
  final String? errorMessage;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const _RoomEntryView({
    required this.nameController,
    required this.roomCodeController,
    required this.onCreate,
    required this.onJoin,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.public,
                      size: 54, color: AppColors.secondary),
                  const SizedBox(height: 12),
                  Text(
                    'online_real_time_title'.tr(),
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'online_real_time_description'.tr(),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium,
                  ),
                  if (errorMessage case final message?) ...[
                    const SizedBox(height: 16),
                    OnlineActionErrorBanner(message: message),
                  ],
                  const SizedBox(height: 22),
                  TextField(
                    controller: nameController,
                    maxLength: 24,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'online_player_name'.tr(),
                      hintText: 'online_player_name_hint'.tr(),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onCreate,
                          icon: const Icon(Icons.add),
                          label: Text('online_create'.tr()),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('online_or_join'.tr()),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  TextField(
                    controller: roomCodeController,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onJoin(),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                      _UpperCaseTextFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'online_room_code'.tr(),
                      hintText: 'online_room_code_hint'.tr(),
                      prefixIcon: const Icon(Icons.key),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onJoin,
                    icon: const Icon(Icons.login),
                    label: Text('online_join'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
