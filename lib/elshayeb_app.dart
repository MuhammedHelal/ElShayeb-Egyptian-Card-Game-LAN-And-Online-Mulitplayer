import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'injection_container.dart';
import 'core/audio_manager.dart';
import 'core/constants/app_consts.dart';
import 'core/haptic_manager.dart';
import 'features/online_session/online_session.dart';
import 'presentation/presentation.dart';

class ElShayebApp extends StatelessWidget {
  const ElShayebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Settings Cubit - global
        BlocProvider<SettingsCubit>(
          create: (_) => getIt<SettingsCubit>()..loadSettings(),
        ),
        // Game Cubit - global for game state
        BlocProvider<GameCubit>(
          create: (_) => getIt<GameCubit>(),
        ),
      ],
      child: MaterialApp(
        title: 'El-Shayeb',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        // Localization delegates
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        // RTL support builder
        builder: (context, child) {
          return Directionality(
            textDirection: context.locale.languageCode == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: child!,
          );
        },
        home: const HomeScreen(),
        routes: {
          '/home': (_) => const HomeScreen(),
          '/lobby': (_) => const LobbyScreen(),
          '/game': (_) => const GameScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/online-game': (_) => BlocProvider<OnlineSessionCubit>(
                create: (_) => getIt<OnlineSessionCubit>(),
                child: OnlineGameScreen(
                  audioManager: getIt<AudioManager>(),
                  hapticManager: getIt<HapticManager>(),
                ),
              ),
          if (AppConsts.onlineDiagnosticsEnabled)
            '/online-diagnostics': (_) => BlocProvider<OnlineSessionCubit>(
                  create: (_) => getIt<OnlineSessionCubit>(),
                  child: const OnlineDiagnosticsScreen(),
                ),
        },
      ),
    );
  }
}
