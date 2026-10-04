/// Dependency Injection Container to init get_it

library;

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/core.dart';
import 'domain/domain.dart';
import 'presentation/presentation.dart';
import 'data/network/online_network_service.dart';
import 'data/network/supabase/supabase_network_service.dart';
import 'features/online_session/online_session.dart';

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

  // Cloudflare Durable Objects online-session test path. This is isolated
  // from the host-oriented NetworkManager until server-side gameplay ships.
  getIt.registerLazySingleton<http.Client>(() => http.Client());
  getIt.registerLazySingleton<OnlineSessionRemoteDataSource>(
    () => CloudflareOnlineSessionDataSource(
      supabase: Supabase.instance.client,
      httpClient: getIt<http.Client>(),
    ),
  );
  getIt.registerLazySingleton<OnlineSessionLocalDataSource>(
    () => SharedPreferencesOnlineSessionLocalDataSource(
      getIt<SharedPreferences>(),
    ),
  );
  getIt.registerLazySingleton<OnlineSessionRepository>(
    () => OnlineSessionRepositoryImpl(
      getIt<OnlineSessionRemoteDataSource>(),
      getIt<OnlineSessionLocalDataSource>(),
    ),
  );
  getIt.registerLazySingleton(
    () => ObserveOnlineSessionUseCase(getIt<OnlineSessionRepository>()),
  );
  getIt.registerLazySingleton(
    () => CreateOnlineRoomUseCase(getIt<OnlineSessionRepository>()),
  );
  getIt.registerLazySingleton(
    () => JoinOnlineRoomUseCase(getIt<OnlineSessionRepository>()),
  );
  getIt.registerLazySingleton(
    () => RestoreOnlineSessionUseCase(getIt<OnlineSessionRepository>()),
  );
  getIt.registerLazySingleton(
    () => ReconnectOnlineSessionUseCase(getIt<OnlineSessionRepository>()),
  );
  getIt.registerLazySingleton(
    () => LeaveOnlineRoomUseCase(getIt<OnlineSessionRepository>()),
  );
  getIt.registerLazySingleton(
    () => StartOnlineGameUseCase(getIt<OnlineSessionRepository>()),
  );
  getIt.registerLazySingleton(
    () => DrawOnlineCardUseCase(getIt<OnlineSessionRepository>()),
  );
  getIt.registerLazySingleton(
    () => ShuffleOnlineHandUseCase(getIt<OnlineSessionRepository>()),
  );
  getIt.registerLazySingleton(
    () => StartOnlineRoundUseCase(getIt<OnlineSessionRepository>()),
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

  getIt.registerFactory<OnlineSessionCubit>(
    () => OnlineSessionCubit(
      observeOnlineSession: getIt<ObserveOnlineSessionUseCase>(),
      createOnlineRoom: getIt<CreateOnlineRoomUseCase>(),
      joinOnlineRoom: getIt<JoinOnlineRoomUseCase>(),
      restoreOnlineSession: getIt<RestoreOnlineSessionUseCase>(),
      reconnectOnlineSession: getIt<ReconnectOnlineSessionUseCase>(),
      leaveOnlineRoom: getIt<LeaveOnlineRoomUseCase>(),
      startOnlineGame: getIt<StartOnlineGameUseCase>(),
      drawOnlineCard: getIt<DrawOnlineCardUseCase>(),
      shuffleOnlineHand: getIt<ShuffleOnlineHandUseCase>(),
      startOnlineRound: getIt<StartOnlineRoundUseCase>(),
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
