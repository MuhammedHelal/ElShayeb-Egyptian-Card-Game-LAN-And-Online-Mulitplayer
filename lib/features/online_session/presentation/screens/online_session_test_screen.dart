import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../presentation/theme/app_theme.dart';
import '../../domain/entities/online_lobby.dart';
import '../cubit/online_session_cubit.dart';
import '../cubit/online_session_state.dart';

class OnlineSessionTestScreen extends StatefulWidget {
  const OnlineSessionTestScreen({super.key});

  @override
  State<OnlineSessionTestScreen> createState() =>
      _OnlineSessionTestScreenState();
}

class _OnlineSessionTestScreenState extends State<OnlineSessionTestScreen> {
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
      appBar: AppBar(title: Text('online_lobby_title'.tr())),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.tableGradient),
        child: SafeArea(
          child: BlocBuilder<OnlineSessionCubit, OnlineSessionState>(
            builder: (context, state) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _ConnectionBanner(status: state.connectionStatus),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    maxLength: 24,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'online_player_name'.tr(),
                      hintText: 'online_player_name_hint'.tr(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _roomCodeController,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                      _UpperCaseTextFormatter(),
                    ],
                    decoration: InputDecoration(
                      labelText: 'online_room_code'.tr(),
                      hintText: 'online_room_code_hint'.tr(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: state is OnlineSessionLoading
                              ? null
                              : () => _createRoom(context),
                          icon: const Icon(Icons.add),
                          label: Text('online_create'.tr()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state is OnlineSessionLoading
                              ? null
                              : () => _joinRoom(context),
                          icon: const Icon(Icons.login),
                          label: Text('online_join'.tr()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  switch (state) {
                    OnlineSessionInitial() => _InfoCard(
                        message: 'online_lobby_intro'.tr(),
                      ),
                    OnlineSessionLoading() => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    OnlineSessionReady(:final value) => _LobbyCard(
                        lobby: value,
                        onLeave: () =>
                            context.read<OnlineSessionCubit>().leaveRoom(),
                      ),
                    OnlineSessionFailure(:final message, :final code) =>
                      _ErrorCard(message: message, code: code),
                  },
                ],
              );
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
          avatarId: 'default',
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
          avatarId: 'default',
        );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ConnectionBanner extends StatelessWidget {
  final OnlineServerConnectionStatus status;

  const _ConnectionBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OnlineServerConnectionStatus.disconnected => (
          'online_status_disconnected'.tr(),
          AppColors.textSecondary
        ),
      OnlineServerConnectionStatus.connecting => (
          'online_status_connecting'.tr(),
          AppColors.info,
        ),
      OnlineServerConnectionStatus.authenticating => (
          'online_status_authenticating'.tr(),
          AppColors.warning
        ),
      OnlineServerConnectionStatus.connected => (
          'online_status_connected'.tr(),
          AppColors.success
        ),
      OnlineServerConnectionStatus.reconnecting => (
          'online_status_reconnecting'.tr(),
          AppColors.warning
        ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.circle, size: 12, color: color),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _LobbyCard extends StatelessWidget {
  final OnlineLobby lobby;
  final VoidCallback onLeave;

  const _LobbyCard({required this.lobby, required this.onLeave});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'online_room_title'.tr(
                      namedArgs: {'code': lobby.roomCode},
                    ),
                    style: AppTypography.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: lobby.roomCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('online_room_code_copied'.tr())),
                    );
                  },
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
            Text(
              'online_server_version'.tr(
                namedArgs: {'version': lobby.stateVersion.toString()},
              ),
            ),
            const Divider(height: 24),
            for (final player in lobby.players)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  player.isConnected ? Icons.person : Icons.person_off,
                  color: player.isConnected
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
                title: Text(player.name),
                subtitle: Text(
                  player.userId == lobby.localUserId
                      ? 'online_you'.tr()
                      : 'online_player'.tr(),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              lobby.canStart
                  ? 'online_lobby_verified'.tr()
                  : 'online_waiting_players'.tr(),
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onLeave,
              icon: const Icon(Icons.logout),
              label: Text('online_leave_room'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String message;

  const _InfoCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: AppTypography.bodyLarge),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final String? code;

  const _ErrorCard({required this.message, this.code});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'online_connection_failed'.tr(),
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message),
            if (code != null)
              Text('online_error_code'.tr(namedArgs: {'code': code!})),
          ],
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
