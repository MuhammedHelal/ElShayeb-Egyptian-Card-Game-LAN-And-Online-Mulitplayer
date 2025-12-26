/// Domain Layer - Connection States
///
/// Represents the current state of the online connection.
library;

enum OnlineConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class OnlineConnectionState {
  final OnlineConnectionStatus status;
  final String? error;

  const OnlineConnectionState({
    this.status = OnlineConnectionStatus.disconnected,
    this.error,
  });

  const OnlineConnectionState.disconnected()
      : status = OnlineConnectionStatus.disconnected,
        error = null;

  const OnlineConnectionState.connecting()
      : status = OnlineConnectionStatus.connecting,
        error = null;

  const OnlineConnectionState.connected()
      : status = OnlineConnectionStatus.connected,
        error = null;

  const OnlineConnectionState.reconnecting()
      : status = OnlineConnectionStatus.reconnecting,
        error = null;

  const OnlineConnectionState.error(this.error)
      : status = OnlineConnectionStatus.error;

  @override
  String toString() => 'OnlineConnectionState(status: $status, error: $error)';
}
