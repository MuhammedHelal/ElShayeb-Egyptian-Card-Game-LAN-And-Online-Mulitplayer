abstract class AppConsts {
  static const bool isTestMode = false;

  /// Enables the Cloudflare Durable Objects online game.
  ///
  /// Run with `--dart-define=DURABLE_OBJECT_ONLINE=true` while this transport
  /// is being validated. The legacy online path remains the default otherwise.
  static const bool durableObjectOnlineEnabled = bool.fromEnvironment(
    'DURABLE_OBJECT_ONLINE',
    defaultValue: false,
  );

  /// Exposes the developer-facing online protocol diagnostics screen.
  ///
  /// This is intentionally separate from the player-facing online game and
  /// remains unavailable unless explicitly enabled at compile time.
  static const bool onlineDiagnosticsEnabled = bool.fromEnvironment(
    'ONLINE_DIAGNOSTICS',
    defaultValue: false,
  );
}
