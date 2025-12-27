/// El-Shayeb - Egyptian Card Game
///
/// Main application entry point.
/// Initializes dependencies and launches the app.
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'core/localization/localization_service.dart';
import 'injection_container.dart';
import 'presentation/presentation.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize easy_localization
  await EasyLocalization.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A1F14),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize dependencies
  await initDependencies();
  await initServices();

  // Run the app with localization
  runApp(
    EasyLocalization(
      supportedLocales: LocalizationService.supportedLocales,
      path: LocalizationService.translationsPath,
      fallbackLocale: LocalizationService.fallbackLocale,
      child: const ElShayebApp(),
    ),
  );
}

/// Main application widget
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
        },
      ),
    );
  }
}
