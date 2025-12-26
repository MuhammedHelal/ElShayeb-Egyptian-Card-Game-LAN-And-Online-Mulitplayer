/// Presentation Layer - Settings Screen
///
/// App settings for audio, vibration, and profile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/cubits.dart';
import '../theme/app_theme.dart';

/// Settings screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    const Text(
                      'Settings',
                      style: AppTypography.headlineMedium,
                    ),
                  ],
                ),
              ),

              // Settings content
              Expanded(
                child: BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (context, state) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Profile section
                        const _SectionHeader(title: 'Profile'),
                        _SettingsCard(
                          children: [
                            _ProfileTile(
                              name: state.playerName,
                              avatarId: state.avatarId,
                              onNameChanged: (name) {
                                context
                                    .read<SettingsCubit>()
                                    .setPlayerName(name);
                              },
                              onAvatarChanged: (id) {
                                context.read<SettingsCubit>().setAvatarId(id);
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Audio section
                        const _SectionHeader(title: 'Audio'),
                        _SettingsCard(
                          children: [
                            _SwitchTile(
                              icon: Icons.music_note,
                              title: 'Background Music',
                              value: state.isMusicEnabled,
                              onChanged: (_) {
                                context.read<SettingsCubit>().toggleMusic();
                              },
                            ),
                            if (state.isMusicEnabled)
                              _SliderTile(
                                icon: Icons.volume_up,
                                title: 'Music Volume',
                                value: state.musicVolume,
                                onChanged: (value) {
                                  context
                                      .read<SettingsCubit>()
                                      .setMusicVolume(value);
                                },
                              ),
                            const Divider(),
                            _SwitchTile(
                              icon: Icons.campaign,
                              title: 'Sound Effects',
                              value: state.isSfxEnabled,
                              onChanged: (_) {
                                context.read<SettingsCubit>().toggleSfx();
                              },
                            ),
                            if (state.isSfxEnabled)
                              _SliderTile(
                                icon: Icons.volume_up,
                                title: 'Effects Volume',
                                value: state.sfxVolume,
                                onChanged: (value) {
                                  context
                                      .read<SettingsCubit>()
                                      .setSfxVolume(value);
                                },
                              ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Haptics section
                        const _SectionHeader(title: 'Haptics'),
                        _SettingsCard(
                          children: [
                            _SwitchTile(
                              icon: Icons.vibration,
                              title: 'Vibration',
                              subtitle: 'Haptic feedback for game actions',
                              value: state.isVibrationEnabled,
                              onChanged: (_) {
                                context.read<SettingsCubit>().toggleVibration();
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // About section
                        const _SectionHeader(title: 'About'),
                        _SettingsCard(
                          children: [
                            ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: AppColors.goldGradient,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Text(
                                    'ش',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                              ),
                              title: const Text('El-Shayeb'),
                              subtitle: const Text('Version 1.0.0'),
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.info_outline),
                              title: const Text('Game Rules'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showRulesDialog(context),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('El-Shayeb Rules'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🎴 The Deck',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Standard deck with only ONE King (the Shayeb). '
                'The other three Kings are removed.',
              ),
              SizedBox(height: 16),
              Text(
                '🃏 Dealing',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'All cards are dealt one by one until the deck is empty. '
                'Each player removes any matching pairs from their hand.',
              ),
              SizedBox(height: 16),
              Text(
                '🎮 Gameplay',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'On your turn, draw ONE random card from the player next to you. '
                'If it matches a card in your hand, remove the pair. '
                'If not, keep the card.',
              ),
              SizedBox(height: 16),
              Text(
                '🏆 Winning',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Players who empty their hand are winners! '
                'The last player holding the King (Shayeb) loses.',
              ),
              SizedBox(height: 16),
              Text(
                '📊 Scoring',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '1st: +100 | 2nd: +60 | 3rd: +40 | 4th: +20 | 5th: +10\n'
                'Shayeb (last): -50',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

/// Section header
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: AppTypography.labelLarge.copyWith(
          color: AppColors.secondary,
        ),
      ),
    );
  }
}

/// Settings card container
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

/// Switch setting tile
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.secondary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Slider setting tile
class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final double value;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondary, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyMedium),
                Slider(
                  value: value,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Profile settings tile
class _ProfileTile extends StatelessWidget {
  final String name;
  final String avatarId;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onAvatarChanged;

  const _ProfileTile({
    required this.name,
    required this.avatarId,
    required this.onNameChanged,
    required this.onAvatarChanged,
  });

  @override
  Widget build(BuildContext context) {
    final avatars = ['😀', '😎', '🤠', '👨‍💻', '👩‍🎤', '🧔'];
    final currentIndex = int.tryParse(avatarId.split('_').last) ?? 1;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar selection
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 8, // horizontal space between avatars
            runSpacing: 8, // vertical space between rows
            children: List.generate(avatars.length, (index) {
              final isSelected = currentIndex == index + 1;

              return GestureDetector(
                onTap: () => onAvatarChanged('avatar_${index + 1}'),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: AnimatedScale(
                    scale: isSelected ? 1.0 : 44 / 56,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppColors.secondary
                            : AppColors.surfaceLight,
                        border: isSelected
                            ? Border.all(color: AppColors.secondary, width: 3)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          avatars[index],
                          style: TextStyle(
                            fontSize: isSelected ? 28 : 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // Name input
          TextField(
            controller: TextEditingController(text: name),
            decoration: const InputDecoration(
              labelText: 'Player Name',
              prefixIcon: Icon(Icons.person),
            ),
            onChanged: onNameChanged,
          ),
        ],
      ),
    );
  }
}
