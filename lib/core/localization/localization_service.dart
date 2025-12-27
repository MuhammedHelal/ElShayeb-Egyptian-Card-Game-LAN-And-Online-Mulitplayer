/// Core - Localization Service
///
/// Centralized localization wrapper for dependency injection.
/// Provides testable and mockable interface for translations.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Localization service for centralized translation access
class LocalizationService {
  /// Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
  ];

  /// Default locale
  static const Locale fallbackLocale = Locale('en');

  /// Path to translations
  static const String translationsPath = 'assets/translations';

  /// Get current locale
  static Locale? getCurrentLocale(BuildContext context) {
    return context.locale;
  }

  /// Set locale
  static Future<void> setLocale(BuildContext context, Locale locale) async {
    await context.setLocale(locale);
  }

  /// Check if current locale is RTL
  static bool isRtl(BuildContext context) {
    return context.locale.languageCode == 'ar';
  }
}

/// Translation keys as constants for type-safe access
abstract class AppStrings {
  // App
  static String get appName => 'app_name'.tr();
  static String get appSubtitle => 'app_subtitle'.tr();
  static String get version => 'version'.tr();

  // Mode selection
  static String get modeLocalWifi => 'mode_local_wifi'.tr();
  static String get modeLocalWifiDesc => 'mode_local_wifi_desc'.tr();
  static String get modeOnline => 'mode_online'.tr();
  static String get modeOnlineDesc => 'mode_online_desc'.tr();

  // Lobby
  static String get lobbyLocalWifiGame => 'lobby_local_wifi_game'.tr();
  static String get lobbyOnlineGame => 'lobby_online_game'.tr();
  static String get lobbyCreateRoom => 'lobby_create_room'.tr();
  static String get lobbyJoinRoom => 'lobby_join_room'.tr();
  static String get lobbyCreateNewRoom => 'lobby_create_new_room'.tr();
  static String get lobbyHostLocal => 'lobby_host_local'.tr();
  static String get lobbyHostOnline => 'lobby_host_online'.tr();
  static String get lobbyYourName => 'lobby_your_name'.tr();
  static String get lobbyCreating => 'lobby_creating'.tr();
  static String get lobbyCreateRoomBtn => 'lobby_create_room_btn'.tr();
  static String get lobbyShareWithFriends => 'lobby_share_with_friends'.tr();
  static String get lobbyRoomCode => 'lobby_room_code'.tr();
  static String get lobbyCopy => 'lobby_copy'.tr();
  static String get lobbyCopyCode => 'lobby_copy_code'.tr();
  static String get lobbyAvailableRooms => 'lobby_available_rooms'.tr();
  static String get lobbyNoRoomsFound => 'lobby_no_rooms_found'.tr();
  static String get lobbySearchingWifi => 'lobby_searching_wifi'.tr();
  static String get lobbyOrEnterManually => 'lobby_or_enter_manually'.tr();
  static String get lobbyIpAddress => 'lobby_ip_address'.tr();
  static String get lobbyPort => 'lobby_port'.tr();
  static String get lobbyJoining => 'lobby_joining'.tr();
  static String get lobbyJoinRoomBtn => 'lobby_join_room_btn'.tr();
  static String get lobbyEnterRoomCode => 'lobby_enter_room_code'.tr();
  static String get lobbyRoomCodeHint => 'lobby_room_code_hint'.tr();
  static String get lobbyInGame => 'lobby_in_game'.tr();
  static String get lobbyFull => 'lobby_full'.tr();

  // Game
  static String get gameWaitingForPlayers => 'game_waiting_for_players'.tr();
  static String gamePlayersJoined(int count) =>
      'game_players_joined'.tr(namedArgs: {'count': count.toString()});
  static String get gameShareAddress => 'game_share_address'.tr();
  static String get gameShareCode => 'game_share_code'.tr();
  static String get gameStart => 'game_start'.tr();
  static String get gameNeedPlayers => 'game_need_players'.tr();
  static String get gameYourTurn => 'game_your_turn'.tr();
  static String get gameShuffleHand => 'game_shuffle_hand'.tr();
  static String get gameNewRound => 'game_new_round'.tr();
  static String get gameLeaveTitle => 'game_leave_title'.tr();
  static String get gameLeaveMessage => 'game_leave_message'.tr();
  static String get gameCancel => 'game_cancel'.tr();
  static String get gameLeave => 'game_leave'.tr();
  static String get gameScoreboard => 'game_scoreboard'.tr();
  static String get gameSettings => 'game_settings'.tr();
  static String get gameLeaveGame => 'game_leave_game'.tr();
  static String get gameCopied => 'game_copied'.tr();

  // Scoreboard
  static String get scoreboardTitle => 'scoreboard_title'.tr();
  static String get scoreboardRoundResults => 'scoreboard_round_results'.tr();
  static String get scoreboardYou => 'scoreboard_you'.tr();
  static String get scoreboardShayeb => 'scoreboard_shayeb'.tr();
  static String scoreboardPts(int score) =>
      'scoreboard_pts'.tr(namedArgs: {'score': score.toString()});

  // Card
  static String cardChooseFrom(String name) =>
      'card_choose_from'.tr(namedArgs: {'name': name});
  static String cardCardsCount(int count) =>
      'card_cards_count'.tr(namedArgs: {'count': count.toString()});
  static String get cardMatch => 'card_match'.tr();
  static String get cardNoCards => 'card_no_cards'.tr();

  // Settings
  static String get settingsTitle => 'settings_title'.tr();
  static String get settingsProfile => 'settings_profile'.tr();
  static String get settingsAudio => 'settings_audio'.tr();
  static String get settingsHaptics => 'settings_haptics'.tr();
  static String get settingsAbout => 'settings_about'.tr();
  static String get settingsBackgroundMusic => 'settings_background_music'.tr();
  static String get settingsMusicVolume => 'settings_music_volume'.tr();
  static String get settingsSoundEffects => 'settings_sound_effects'.tr();
  static String get settingsEffectsVolume => 'settings_effects_volume'.tr();
  static String get settingsVibration => 'settings_vibration'.tr();
  static String get settingsVibrationDesc => 'settings_vibration_desc'.tr();
  static String get settingsPlayerName => 'settings_player_name'.tr();
  static String get settingsVersion => 'settings_version'.tr();
  static String get settingsGameRules => 'settings_game_rules'.tr();

  // Rules
  static String get rulesTitle => 'rules_title'.tr();
  static String get rulesDeckTitle => 'rules_deck_title'.tr();
  static String get rulesDeckDesc => 'rules_deck_desc'.tr();
  static String get rulesDealingTitle => 'rules_dealing_title'.tr();
  static String get rulesDealingDesc => 'rules_dealing_desc'.tr();
  static String get rulesGameplayTitle => 'rules_gameplay_title'.tr();
  static String get rulesGameplayDesc => 'rules_gameplay_desc'.tr();
  static String get rulesWinningTitle => 'rules_winning_title'.tr();
  static String get rulesWinningDesc => 'rules_winning_desc'.tr();
  static String get rulesScoringTitle => 'rules_scoring_title'.tr();
  static String get rulesScoringDesc => 'rules_scoring_desc'.tr();
  static String get rulesGotIt => 'rules_got_it'.tr();

  // Errors
  static String get errorEnterName => 'error_enter_name'.tr();
  static String get errorEnterIp => 'error_enter_ip'.tr();
  static String get errorEnterPort => 'error_enter_port'.tr();
  static String get errorEnterRoomCode => 'error_enter_room_code'.tr();

  // Language settings
  static String get settingsLanguage => 'settings_language'.tr();
  static String get languageEnglish => 'language_english'.tr();
  static String get languageArabic => 'language_arabic'.tr();

  // Game Events (localized messages)
  static String eventPlayerCreatedRoom(String name) =>
      'event_player_created_room'.tr(namedArgs: {'name': name});
  static String eventPlayerJoining(String name) =>
      'event_player_joining'.tr(namedArgs: {'name': name});
  static String eventPlayerJoined(String name) =>
      'event_player_joined'.tr(namedArgs: {'name': name});
  static String eventPlayerMadePair(String name, String card) =>
      'event_player_made_pair'.tr(namedArgs: {'name': name, 'card': card});
  static String eventPlayerDrewCard(String name) =>
      'event_player_drew_card'.tr(namedArgs: {'name': name});
  static String eventPlayerStoleCard(String name, String target) =>
      'event_player_stole_card'.tr(namedArgs: {'name': name, 'target': target});
  static String eventPlayerFinished(String name) =>
      'event_player_finished'.tr(namedArgs: {'name': name});
  static String eventPlayerShuffled(String name) =>
      'event_player_shuffled'.tr(namedArgs: {'name': name});
  static String eventPlayerDisconnected(String name) =>
      'event_player_disconnected'.tr(namedArgs: {'name': name});
  static String get eventGameStarted => 'event_game_started'.tr();
  static String get eventRoundEnded => 'event_round_ended'.tr();
  static String get eventNewRoundStarted => 'event_new_round_started'.tr();
  static String get eventRoundStarted => 'event_round_started'.tr();
  static String get eventStateSync => 'event_state_sync'.tr();
  static String get eventInvalidDraw => 'event_invalid_draw'.tr();
}
