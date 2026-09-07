import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Unified error type surfaced to the UI.
///
/// Mapping rules (fixed 3-catch pattern, AGENTS.md):
/// - Supabase / Postgrest / RLS / constraint / RPC exceptions -> [AppException] (validation)
/// - [SocketException] / [TimeoutException] -> [NetworkException]
/// - anything else -> [UnknownException]
/// Raw Supabase errors are never leaked to the UI.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Recoverable validation/business errors with a user-facing Arabic message
/// (incl. RPC-raised exceptions forwarded from Postgres).
final class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// No connectivity / server timeout — retry is appropriate.
final class NetworkException extends AppException {
  const NetworkException([super.message = 'تعذر الاتصال بالخادم، حاول مرة أخرى']);
}

/// Unexpected internal failure.
final class UnknownException extends AppException {
  const UnknownException([super.message = 'حدث خطأ غير متوقع، حاول مرة أخرى']);
}

/// Normalizes any thrown error into an [AppException].
AppException mapErrorToAppException(Object error) {
  if (error is AppException) return error;
  if (error is PostgrestException) return ValidationException(error.message);
  if (error is AuthException) return ValidationException(error.message);
  if (error is SocketException || error is TimeoutException) {
    return const NetworkException();
  }
  return const UnknownException();
}