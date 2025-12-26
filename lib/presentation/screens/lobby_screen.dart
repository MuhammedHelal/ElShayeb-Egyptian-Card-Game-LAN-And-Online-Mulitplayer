/// Presentation Layer - Lobby Screen
///
/// Create or join game rooms.
/// For LAN mode: Shows IP:Port and auto-discovers rooms on the network.
/// For Online mode: Uses room codes.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/room_info.dart';
import '../cubit/cubits.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';

/// Lobby screen for creating/joining games
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _addressController = TextEditingController();
  final _portController = TextEditingController();
  final _roomCodeController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Load saved player name
    final settingsState = context.read<SettingsCubit>().state;
    _nameController.text = settingsState.playerName;

    // Start room discovery for LAN mode
    final gameCubit = context.read<GameCubit>();
    if (gameCubit.currentMode == GameMode.lan) {
      gameCubit.startRoomDiscovery();
    }
  }

  @override
  void dispose() {
    context.read<GameCubit>().stopRoomDiscovery();
    _tabController.dispose();
    _addressController.dispose();
    _portController.dispose();
    _roomCodeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameCubit = context.watch<GameCubit>();
    final isLan = gameCubit.currentMode == GameMode.lan;

    return BlocListener<GameCubit, GameUiState>(
      listener: (context, state) {
        if (state.status == LoadingStatus.success && state.gameState != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const GameScreen(),
            ),
          );
        } else if (state.status == LoadingStatus.failure &&
            state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: AppColors.error,
            ),
          );
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
                // App bar
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
                        isLan ? 'Local Wi-Fi Game' : 'Online Game',
                        style: AppTypography.headlineMedium,
                      ),
                    ],
                  ),
                ),

                // Tab bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.textDark,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: AppTypography.labelLarge,
                    dividerHeight: 0,
                    tabs: const [
                      Tab(text: 'Create Room'),
                      Tab(text: 'Join Room'),
                    ],
                  ),
                ),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCreateTab(context, gameCubit),
                      _buildJoinTab(context, gameCubit, isLan),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateTab(BuildContext context, GameCubit cubit) {
    final isLan = cubit.currentMode == GameMode.lan;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),

          // Create room illustration
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.3),
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

          const Text(
            'Create a New Room',
            style: AppTypography.headlineMedium,
          ),

          const SizedBox(height: 8),

          Text(
            isLan
                ? 'Host a game on your local network'
                : 'Host a game and share the code',
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Player name input
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              prefixIcon: Icon(Icons.person),
            ),
            onChanged: (value) {
              context.read<SettingsCubit>().setPlayerName(value);
            },
          ),

          const SizedBox(height: 32),

          // Create button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  cubit.state.isConnecting ? null : () => _createGame(context),
              icon: cubit.state.isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                  cubit.state.isConnecting ? 'Creating...' : 'Create Room'),
            ),
          ),

          // Show connection info after room is created
          if (cubit.state.isHost && cubit.state.gameState != null) ...[
            const SizedBox(height: 24),
            _buildConnectionInfo(context, cubit, isLan),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionInfo(
      BuildContext context, GameCubit cubit, bool isLan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            isLan ? 'Share this with friends:' : 'Room Code:',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (isLan) ...[
            // Show IP:Port for LAN
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi, color: AppColors.secondary),
                const SizedBox(width: 8),
                Text(
                  cubit.connectionInfo,
                  style: AppTypography.headlineMedium.copyWith(
                    color: AppColors.secondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _copyToClipboard(context, cubit.connectionInfo),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy'),
            ),
          ] else ...[
            // Show room code for Online
            Text(
              cubit.state.roomCode,
              style: AppTypography.displayMedium.copyWith(
                color: AppColors.secondary,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _copyToClipboard(context, cubit.state.roomCode),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy Code'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJoinTab(BuildContext context, GameCubit cubit, bool isLan) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Player name input
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              prefixIcon: Icon(Icons.person),
            ),
            onChanged: (value) {
              context.read<SettingsCubit>().setPlayerName(value);
            },
          ),

          const SizedBox(height: 24),

          if (isLan) ...[
            // LAN Mode: Show discovered rooms and manual entry
            _buildDiscoveredRooms(context, cubit),
            const SizedBox(height: 24),
            _buildManualEntry(context, cubit),
          ] else ...[
            // Online Mode: Room code entry
            _buildOnlineJoin(context, cubit),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscoveredRooms(BuildContext context, GameCubit cubit) {
    final rooms = cubit.discoveredRooms;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.wifi_find, color: AppColors.secondary),
            const SizedBox(width: 8),
            const Text(
              'Availabe Rooms',
              style: AppTypography.titleMedium,
            ),
            const Spacer(),
            if (cubit.isDiscovering)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            IconButton(
              onPressed: () => cubit.startRoomDiscovery(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rooms.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    size: 48,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No rooms found yet',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Searching for games on your Wi-Fi...',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...rooms.map((room) => _buildRoomCard(context, cubit, room)),
      ],
    );
  }

  Widget _buildRoomCard(BuildContext context, GameCubit cubit, RoomInfo room) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.devices, color: AppColors.secondary),
        ),
        title: Text(room.hostName),
        subtitle: Text(
          '${room.hostAddress}:${room.port} • ${room.playerCountDisplay}',
        ),
        trailing: room.canJoin
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size.fromWidth(10),
                  padding: EdgeInsets.zero, // remove default padding
                  alignment: Alignment.center,
                ),
                onPressed: cubit.state.isConnecting
                    ? null
                    : () => _joinDiscoveredRoom(context, room),
                child: Center(
                  child: Transform.rotate(
                      angle: 3.14,
                      child: const Icon(
                        Icons.arrow_back_ios_outlined,
                        size: 24,
                      )),
                ),
              )
            : Chip(
                label: Text(room.isStarted ? 'In Game' : 'Full'),
                backgroundColor: AppColors.surfaceLight,
              ),
      ),
    );
  }

  Widget _buildManualEntry(BuildContext context, GameCubit cubit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.keyboard, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Or enter manually',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // IP Address
            Expanded(
              flex: 3,
              child: TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'IP Address',
                  hintText: '192.168.x.x',
                  prefixIcon: Icon(Icons.computer),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Port
            Expanded(
              flex: 2,
              child: TextField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  prefixIcon: Icon(Icons.tag),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed:
                cubit.state.isConnecting ? null : () => _joinManual(context),
            icon: cubit.state.isConnecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(cubit.state.isConnecting ? 'Joining...' : 'Join Room'),
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineJoin(BuildContext context, GameCubit cubit) {
    return Column(
      children: [
        // Join room illustration
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

        const Text(
          'Enter the room code',
          style: AppTypography.titleMedium,
        ),

        const SizedBox(height: 16),

        // Room code input
        TextField(
          controller: _roomCodeController,
          decoration: const InputDecoration(
            labelText: 'Room Code',
            prefixIcon: Icon(Icons.vpn_key),
            hintText: 'ABCD',
          ),
          textCapitalization: TextCapitalization.characters,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: AppTypography.headlineMedium.copyWith(letterSpacing: 4),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
            UpperCaseTextFormatter(),
          ],
        ),

        const SizedBox(height: 24),

        // Join button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                cubit.state.isConnecting ? null : () => _joinOnline(context),
            icon: cubit.state.isConnecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(cubit.state.isConnecting ? 'Joining...' : 'Join Room'),
          ),
        ),
      ],
    );
  }

  void _createGame(BuildContext context) {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    context.read<GameCubit>().createGame();
  }

  void _joinDiscoveredRoom(BuildContext context, RoomInfo room) {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    context.read<GameCubit>().joinDiscoveredRoom(room);
  }

  void _joinManual(BuildContext context) {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    final address = _addressController.text.trim();
    final port = int.tryParse(_portController.text) ?? 0;

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the host IP address')),
      );
      return;
    }

    if (port <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid port number')),
      );
      return;
    }

    context.read<GameCubit>().joinGame(address, port);
  }

  void _joinOnline(BuildContext context) {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    final roomCode = _roomCodeController.text.trim().toUpperCase();

    if (roomCode.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid room code')),
      );
      return;
    }

    context.read<GameCubit>().joinGameByCode(roomCode);
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

/// Text formatter to convert to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
