import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_resume_listener.dart';
import '../../../../presentation/theme/app_theme.dart';
import '../../domain/entities/online_lobby.dart';
import '../cubit/online_session_cubit.dart';
import '../cubit/online_session_state.dart';
import '../widgets/online_game_widgets.dart';

/// Developer-only view of the authoritative online protocol and room state.
class OnlineDiagnosticsScreen extends StatefulWidget {
  const OnlineDiagnosticsScreen({super.key});

  @override
  State<OnlineDiagnosticsScreen> createState() =>
      _OnlineDiagnosticsScreenState();
}

class _OnlineDiagnosticsScreenState extends State<OnlineDiagnosticsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _roomCodeController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Diagnostic Player');
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
    final cubit = context.read<OnlineSessionCubit>();
    return AppResumeListener(
      onInitial: cubit.restoreSession,
      onResume: cubit.onAppResumed,
      child: Scaffold(
        appBar: AppBar(title: Text('online_diagnostics_title'.tr())),
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.tableGradient),
          child: SafeArea(
            top: false,
            child: BlocBuilder<OnlineSessionCubit, OnlineSessionState>(
              builder: (context, state) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  OnlineConnectionChip(
                    status: state.connectionStatus,
                    onReconnect: state is OnlineSessionReady &&
                            state.connectionStatus !=
                                OnlineServerConnectionStatus.connected
                        ? context.read<OnlineSessionCubit>().reconnect
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _ConnectionForm(
                    nameController: _nameController,
                    roomCodeController: _roomCodeController,
                    isLoading: state is OnlineSessionLoading,
                    onCreate: () => _createRoom(context),
                    onJoin: () => _joinRoom(context),
                  ),
                  const SizedBox(height: 16),
                  switch (state) {
                    OnlineSessionInitial() => _DiagnosticCard(
                        title: 'State: initial',
                        children: const [Text('No active server room.')],
                      ),
                    OnlineSessionLoading() => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    OnlineSessionFailure(:final message, :final code) =>
                      _DiagnosticCard(
                        title: 'State: failure',
                        children: [
                          Text('message: $message'),
                          Text('code: ${code ?? '-'}'),
                        ],
                      ),
                    OnlineSessionReady() => _ReadyDiagnostics(state: state),
                  },
                ],
              ),
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
          avatarId: 'diagnostic',
        );
  }

  void _joinRoom(BuildContext context) {
    final name = _nameController.text.trim();
    final roomCode = _roomCodeController.text.trim().toUpperCase();
    if (name.isEmpty || roomCode.length != 6) {
      _showMessage(context, 'online_error_join_fields'.tr());
      return;
    }
    context.read<OnlineSessionCubit>().joinRoom(
          roomCode: roomCode,
          playerName: name,
          avatarId: 'diagnostic',
        );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ConnectionForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController roomCodeController;
  final bool isLoading;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const _ConnectionForm({
    required this.nameController,
    required this.roomCodeController,
    required this.isLoading,
    required this.onCreate,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return _DiagnosticCard(
      title: 'Connection controls',
      children: [
        TextField(
          controller: nameController,
          maxLength: 24,
          decoration: InputDecoration(labelText: 'online_player_name'.tr()),
        ),
        TextField(
          controller: roomCodeController,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
          ],
          decoration: InputDecoration(labelText: 'online_room_code'.tr()),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: isLoading ? null : onCreate,
                child: Text('online_create'.tr()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading ? null : onJoin,
                child: Text('online_join'.tr()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReadyDiagnostics extends StatelessWidget {
  final OnlineSessionReady state;

  const _ReadyDiagnostics({required this.state});

  @override
  Widget build(BuildContext context) {
    final lobby = state.value;
    final cubit = context.read<OnlineSessionCubit>();
    final drawTarget = lobby.drawFromPlayer;
    final isUnavailable = state.isActionInFlight ||
        state.connectionStatus != OnlineServerConnectionStatus.connected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DiagnosticCard(
          title: 'Authoritative snapshot',
          children: [
            _Field(label: 'roomCode', value: lobby.roomCode),
            _Field(label: 'stateVersion', value: '${lobby.stateVersion}'),
            _Field(label: 'phase', value: lobby.phase.name),
            _Field(label: 'roundNumber', value: '${lobby.roundNumber}'),
            _Field(label: 'localUserId', value: lobby.localUserId),
            _Field(
              label: 'currentPlayerUserId',
              value: lobby.currentPlayerUserId ?? '-',
            ),
            _Field(
              label: 'drawFromUserId',
              value: lobby.drawFromUserId ?? '-',
            ),
            _Field(label: 'canStart', value: '${lobby.canStart}'),
            _Field(
              label: 'canStartNewRound',
              value: '${lobby.canStartNewRound}',
            ),
            _Field(
              label: 'actionInFlight',
              value: '${state.isActionInFlight}',
            ),
            _Field(
              label: 'actionError',
              value: state.actionErrorMessage ?? '-',
            ),
            _Field(
              label: 'actionErrorCode',
              value: state.actionErrorCode ?? '-',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DiagnosticCard(
          title: 'Players (${lobby.players.length})',
          children: [
            for (final player in lobby.players) _PlayerSnapshot(player: player),
          ],
        ),
        const SizedBox(height: 12),
        _DiagnosticCard(
          title: 'Last action',
          children: [
            if (lobby.lastAction case final action?) ...[
              _Field(label: 'type', value: action.type.name),
              _Field(label: 'actorUserId', value: action.actorUserId),
              _Field(label: 'targetUserId', value: action.targetUserId ?? '-'),
              _Field(label: 'madePair', value: '${action.madePair ?? '-'}'),
              _Field(
                label: 'privateDrawnCard',
                value: action.drawnCard?.label ?? '-',
              ),
            ] else
              const Text('No action received.'),
          ],
        ),
        const SizedBox(height: 12),
        _DiagnosticCard(
          title: 'Server commands',
          children: [
            if (lobby.phase == OnlineRoomPhase.lobby)
              ElevatedButton(
                onPressed:
                    lobby.canStart && !isUnavailable ? cubit.startGame : null,
                child: const Text('start_game'),
              ),
            if (lobby.phase == OnlineRoomPhase.playing) ...[
              if (lobby.isMyTurn && drawTarget != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var index = 0;
                        index < drawTarget.cardCount;
                        index += 1)
                      OutlinedButton(
                        onPressed: isUnavailable
                            ? null
                            : () {
                                cubit.initiateDrawFrom(drawTarget.userId);
                                cubit.drawCard(index);
                              },
                        child: Text('draw_card[$index]'),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: isUnavailable ? null : cubit.shuffleHand,
                child: const Text('shuffle_hand'),
              ),
            ],
            if (lobby.phase == OnlineRoomPhase.roundEnd)
              ElevatedButton(
                onPressed: lobby.canStartNewRound && !isUnavailable
                    ? cubit.startNewRound
                    : null,
                child: const Text('start_round'),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: cubit.leaveRoom,
              icon: const Icon(Icons.logout),
              label: const Text('leave_room'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlayerSnapshot extends StatelessWidget {
  final OnlineLobbyPlayer player;

  const _PlayerSnapshot({required this.player});

  @override
  Widget build(BuildContext context) {
    final privateHand = player.hand;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText('${player.name} (${player.userId})'),
          Text(
            'connected=${player.isConnected} · cards=${player.cardCount} · '
            'score=${player.score} · status=${player.status.name} · '
            'finishPosition=${player.finishPosition}',
          ),
          Text(
            privateHand == null
                ? 'privateHand=<redacted>'
                : 'privateHand=${privateHand.map((card) => card.label).join(', ')}',
          ),
        ],
      ),
    );
  }
}

class _DiagnosticCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DiagnosticCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTypography.titleMedium),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;

  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SelectableText('$label: $value'),
    );
  }
}
