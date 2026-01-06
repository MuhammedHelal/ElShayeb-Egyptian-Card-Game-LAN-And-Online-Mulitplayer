/// Dependency Injection Container to init get_it

library;

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/core.dart';
import 'domain/domain.dart';
import 'presentation/presentation.dart';
import 'data/network/online_network_service.dart';
import 'data/network/supabase/supabase_network_service.dart';

/// Global service locator instance
final getIt = GetIt.instance;

/// Initialize all dependencies
Future<void> initDependencies() async {
  // SharedPreferences
  final sharedPrefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPrefs);

  // Settings Repository
  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepository(getIt<SharedPreferences>()),
  );

  // Audio Manager
  getIt.registerLazySingleton<AudioManager>(() => AudioManager());

  // Haptic Manager
  getIt.registerLazySingleton<HapticManager>(() => HapticManager());

  // Game Rules Engine
  getIt.registerLazySingleton<GameRulesEngine>(() => GameRulesEngine());

  // ============ Network ============

  // Online Network Service (Supabase)
  getIt.registerLazySingleton<OnlineNetworkService>(
    () => SupabaseNetworkService(),
  );

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
