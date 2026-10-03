abstract class OnlineServerConstants {
  static const String httpsBaseUrl =
      'https://elshayeb-online.elshayeb.workers.dev';
  static const String websocketBaseUrl =
      'wss://elshayeb-online.elshayeb.workers.dev';
  static const int protocolVersion = 2;
  static const Duration commandTimeout = Duration(seconds: 12);
}
