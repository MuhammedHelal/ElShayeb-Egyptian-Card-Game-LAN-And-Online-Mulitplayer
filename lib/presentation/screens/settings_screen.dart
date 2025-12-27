/// Presentation Layer - Settings Screen
///
/// App settings for audio, vibration, and profile.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/localization_service.dart';
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
                    Text(
                      AppStrings.settingsTitle,
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
                        _SectionHeader(title: AppStrings.settingsProfile),
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

                        // Language section
                        _SectionHeader(title: AppStrings.settingsLanguage),
                        _SettingsCard(
                          children: [
                            _LanguageTile(
                              icon: Icons.language,
                              title: AppStrings.languageEnglish,
                              isSelected: context.locale.languageCode == 'en',
                              onTap: () {
                                context.setLocale(const Locale('en'));
                                context
                                    .read<SettingsCubit>()
                                    .setLocaleCode('en');
                              },
                            ),
                            const Divider(),
                            _LanguageTile(
                              icon: Icons.language,
                              title: AppStrings.languageArabic,
                              isSelected: context.locale.languageCode == 'ar',
                              onTap: () {
                                context.setLocale(const Locale('ar'));
                                context
                                    .read<SettingsCubit>()
                                    .setLocaleCode('ar');
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Audio section
                        _SectionHeader(title: AppStrings.settingsAudio),
                        _SettingsCard(
                          children: [
                            _SwitchTile(
                              icon: Icons.music_note,
                              title: AppStrings.settingsBackgroundMusic,
                              value: state.isMusicEnabled,
                              onChanged: (_) {
                                context.read<SettingsCubit>().toggleMusic();
                              },
                            ),
                            if (state.isMusicEnabled)
                              _SliderTile(
                                icon: Icons.volume_up,
                                title: AppStrings.settingsMusicVolume,
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
                              title: AppStrings.settingsSoundEffects,
                              value: state.isSfxEnabled,
                              onChanged: (_) {
                                context.read<SettingsCubit>().toggleSfx();
                              },
                            ),
                            if (state.isSfxEnabled)
                              _SliderTile(
                                icon: Icons.volume_up,
                                title: AppStrings.settingsEffectsVolume,
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
                        _SectionHeader(title: AppStrings.settingsHaptics),
                        _SettingsCard(
                          children: [
                            _SwitchTile(
                              icon: Icons.vibration,
                              title: AppStrings.settingsVibration,
                              subtitle: AppStrings.settingsVibrationDesc,
                              value: state.isVibrationEnabled,
                              onChanged: (_) {
                                context.read<SettingsCubit>().toggleVibration();
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // About section
                        _SectionHeader(title: AppStrings.settingsAbout),
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
                              title: Text(AppStrings.appName),
                              subtitle: Text(AppStrings.settingsVersion),
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.info_outline),
                              title: Text(AppStrings.settingsGameRules),
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
        title: Text(AppStrings.rulesTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.rulesDeckTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(AppStrings.rulesDeckDesc),
              const SizedBox(height: 16),
              Text(
                AppStrings.rulesDealingTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(AppStrings.rulesDealingDesc),
              const SizedBox(height: 16),
              Text(
                AppStrings.rulesGameplayTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(AppStrings.rulesGameplayDesc),
              const SizedBox(height: 16),
              Text(
                AppStrings.rulesWinningTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(AppStrings.rulesWinningDesc),
              const SizedBox(height: 16),
              Text(
                AppStrings.rulesScoringTitle,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(AppStrings.rulesScoringDesc),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.rulesGotIt),
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

/// Language selection tile
class _LanguageTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.secondary),
      title: Text(title),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.secondary)
          : const Icon(Icons.circle_outlined, color: AppColors.textSecondary),
      onTap: onTap,
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
            decoration: InputDecoration(
              labelText: AppStrings.settingsPlayerName,
              prefixIcon: const Icon(Icons.person),
            ),
            onChanged: onNameChanged,
          ),
        ],
      ),
    );
  }
}
