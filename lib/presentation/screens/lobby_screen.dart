/// Presentation Layer - Lobby Screen
///
/// Create or join game rooms.
/// For LAN mode: Shows IP:Port and auto-discovers rooms on the network.
/// For Online mode: Uses room codes.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:elshayeb/presentation/widgets/lobby_views/create_tab.dart';
import 'package:elshayeb/presentation/widgets/lobby_views/join_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/localization_service.dart';
import '../../domain/entities/room_info.dart';
import '../cubit/cubits.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';
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
    context.locale; // Register dependency for easy_localization rebuild
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
                        isLan
                            ? AppStrings.lobbyLocalWifiGame
                            : AppStrings.lobbyOnlineGame,
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
                    tabs: [
                      Tab(text: AppStrings.lobbyCreateRoom),
                      Tab(text: AppStrings.lobbyJoinRoom),
                    ],
                  ),
                ),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      CreateTab(
                        cubit: gameCubit,
                        nameController: _nameController,
                        onCreateGame: () => _createGame(context),
                      ),
                      JoinTab(
                        cubit: gameCubit,
                        isLan: isLan,
                        nameController: _nameController,
                        addressController: _addressController,
                        portController: _portController,
                        roomCodeController: _roomCodeController,
                        onJoinManual: () => _joinManual(context),
                        onJoinOnline: () => _joinOnline(context),
                        onJoinDiscoveredRoom: (room) =>
                            _joinDiscoveredRoom(context, room),
                      ),
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

  void _createGame(BuildContext context) {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.errorEnterName)),
      );
      return;
    }

    context.read<GameCubit>().createGame();
  }

  void _joinDiscoveredRoom(BuildContext context, RoomInfo room) {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.errorEnterName)),
      );
      return;
    }

    context.read<GameCubit>().joinDiscoveredRoom(room);
  }

  void _joinManual(BuildContext context) {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.errorEnterName)),
      );
      return;
    }

    final address = _addressController.text.trim();
    final port = int.tryParse(_portController.text) ?? 0;

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.errorEnterIp)),
      );
      return;
    }

    if (port <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.errorEnterPort)),
      );
      return;
    }

    context.read<GameCubit>().joinGame(address, port);
  }

  void _joinOnline(BuildContext context) {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.errorEnterName)),
      );
      return;
    }

    final roomCode = _roomCodeController.text.trim().toUpperCase();

    if (roomCode.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.errorEnterRoomCode)),
      );
      return;
    }

    context.read<GameCubit>().joinGameByCode(roomCode);
  }
}
