/// Domain Layer - Network Exceptions
///
/// Custom exceptions for handling online networking errors.
library;

class NetworkException implements Exception {
  final String message;
  final dynamic originalError;

  NetworkException(this.message, [this.originalError]);

  @override
  String toString() =>
      'NetworkException: $message ${originalError != null ? '($originalError)' : ''}';
}

class ConnectionException extends NetworkException {
  ConnectionException(super.message, [super.originalError]);
}

class RoomException extends NetworkException {
  RoomException(super.message, [super.originalError]);
}

class AuthException extends NetworkException {
  AuthException(super.message, [super.originalError]);
}
