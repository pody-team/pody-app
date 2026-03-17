class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  bool get isForbidden => statusCode == 403;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}
