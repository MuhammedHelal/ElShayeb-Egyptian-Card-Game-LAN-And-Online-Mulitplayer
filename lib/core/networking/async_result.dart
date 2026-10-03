import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

typedef FailureOrSuccess<T> = Either<AppFailure, T>;

class AppFailure extends Equatable {
  final String message;
  final String? code;

  const AppFailure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

Future<FailureOrSuccess<T>> executeAndHandleErrorsAsyncWrapper<T>(
  Future<T> Function() operation, {
  AppFailure Function(Exception error)? mapFailure,
}) async {
  try {
    return Right(await operation());
  } on Exception catch (error) {
    return Left(mapFailure?.call(error) ?? AppFailure(error.toString()));
  }
}
