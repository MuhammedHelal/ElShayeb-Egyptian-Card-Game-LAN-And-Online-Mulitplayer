abstract class AppConsts {
  static const bool isTestMode = false;

  /// Enables the isolated Cloudflare Durable Objects lobby test route.
  ///
  /// Run with `--dart-define=DURABLE_OBJECT_ONLINE=true` while this transport
  /// is being validated. The legacy online path remains the default otherwise.
  static const bool durableObjectOnlineEnabled = bool.fromEnvironment(
    'DURABLE_OBJECT_ONLINE',
    defaultValue: false,
  );
}
