/// Dependency Injection Container
///
/// Configures all dependencies using get_it.
/// Provides singleton instances for services and managers.
library;

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/core.dart';
import 'domain/domain.dart';
import 'presentation/presentation.dart';

/// Global service locator instance
final getIt = GetIt.instance;

/// Initialize all dependencies
Future<void> initDependencies() async {
  // ============ External ============

  // SharedPreferences
  final sharedPrefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPrefs);

  // ============ Core ============

  // Settings Repository
  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepository(getIt<SharedPreferences>()),
  );

  // Audio Manager
  getIt.registerLazySingleton<AudioManager>(() => AudioManager());

  // Haptic Manager
  getIt.registerLazySingleton<HapticManager>(() => HapticManager());

  // ============ Domain ============

  // Game Rules Engine
  getIt.registerLazySingleton<GameRulesEngine>(() => GameRulesEngine());

  // ============ Presentation ============

  // Settings Cubit
  getIt.registerFactory<SettingsCubit>(
    () => SettingsCubit(
      repository: getIt<SettingsRepository>(),
      audioManager: getIt<AudioManager>(),
      hapticManager: getIt<HapticManager>(),
    ),
  );

  // Game Cubit
  getIt.registerFactory<GameCubit>(
    () => GameCubit(
      audioManager: getIt<AudioManager>(),
      hapticManager: getIt<HapticManager>(),
      settingsRepository: getIt<SettingsRepository>(),
    ),
  );
}

/// Initialize core services (call after DI setup)
Future<void> initServices() async {
  // Initialize audio manager
  await getIt<AudioManager>().init();

  // Initialize haptic manager
  await getIt<HapticManager>().init();
}
