import 'package:easy_localization/easy_localization.dart';
import 'package:elshayeb/elshayeb_app.dart';
import 'package:elshayeb/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'core/localization/localization_service.dart';
import 'injection_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    EasyLocalization.ensureInitialized(),
    Supabase.initialize(
      url: SupabaseConstants.url,
      anonKey: SupabaseConstants.anonKey,
    ),
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ),
    // El-Shayeb only allows portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
    // Initialize required dependencies
    initDependencies(),
  ]);
  // Must call after Di injection (After initDependencies())
  await initServices();

  runApp(
    EasyLocalization(
      supportedLocales: LocalizationService.supportedLocales,
      path: LocalizationService.translationsPath,
      fallbackLocale: LocalizationService.fallbackLocale,
      child: const ElShayebApp(),
    ),
  );

  // Change system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A1F14),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
}
