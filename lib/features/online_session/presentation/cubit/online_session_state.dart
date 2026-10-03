import 'package:equatable/equatable.dart';

import '../../../../core/networking/resource.dart';
import '../../domain/entities/online_lobby.dart';

sealed class OnlineSessionState extends Equatable {
  final Resource<OnlineLobby> lobby;
  final OnlineServerConnectionStatus connectionStatus;

  const OnlineSessionState({
    required this.lobby,
    required this.connectionStatus,
  });

  @override
  List<Object?> get props => [lobby, connectionStatus];
}

class OnlineSessionInitial extends OnlineSessionState {
  const OnlineSessionInitial()
      : super(
          lobby: const Resource.initial(),
          connectionStatus: OnlineServerConnectionStatus.disconnected,
        );
}

class OnlineSessionLoading extends OnlineSessionState {
  const OnlineSessionLoading(OnlineServerConnectionStatus status)
      : super(lobby: const Resource.loading(), connectionStatus: status);
}

class OnlineSessionReady extends OnlineSessionState {
  final OnlineLobby value;

  OnlineSessionReady(
    this.value, {
    OnlineServerConnectionStatus status =
        OnlineServerConnectionStatus.connected,
  }) : super(lobby: Resource.success(value), connectionStatus: status);

  @override
  List<Object?> get props => [...super.props, value];
}

class OnlineSessionFailure extends OnlineSessionState {
  final String message;
  final String? code;

  OnlineSessionFailure(
    this.message, {
    this.code,
    OnlineServerConnectionStatus status =
        OnlineServerConnectionStatus.disconnected,
  }) : super(lobby: Resource.error(message), connectionStatus: status);

  @override
  List<Object?> get props => [...super.props, message, code];
}
