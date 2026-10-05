abstract class AppConsts {
  static const bool isTestMode = false;

  /// Exposes the developer-facing online protocol diagnostics screen.
  ///
  /// This is intentionally separate from the player-facing online game and
  /// remains unavailable unless explicitly enabled at compile time.
  static const bool onlineDiagnosticsEnabled = bool.fromEnvironment(
    'ONLINE_DIAGNOSTICS',
    defaultValue: false,
  );
}
