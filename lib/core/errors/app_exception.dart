///base class errors
///Lus
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});
   ///original error for log
  final Object? cause;
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

///user input
class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause});
}

///login/session fails
class AuthException extends AppException {
  const AuthException(super.message, {super.cause});
}

///database operations
class DataAccessException extends AppException {
  const DataAccessException(super.message, {super.cause});
}

///missing row
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.cause});
}

///action not allowed in domain
class BusinessRuleException extends AppException {
  const BusinessRuleException(super.message, {super.cause});
}