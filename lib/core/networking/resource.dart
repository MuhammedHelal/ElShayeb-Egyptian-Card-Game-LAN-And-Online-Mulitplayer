import 'package:equatable/equatable.dart';

enum RequestState { initial, loading, success, error }

class Resource<T> extends Equatable {
  final RequestState state;
  final T? data;
  final String? message;

  const Resource._(this.state, {this.data, this.message});

  const Resource.initial() : this._(RequestState.initial);

  const Resource.loading() : this._(RequestState.loading);

  const Resource.success(T value) : this._(RequestState.success, data: value);

  const Resource.error(String error)
      : this._(RequestState.error, message: error);

  @override
  List<Object?> get props => [state, data, message];
}
