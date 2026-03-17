class AuthPolicy {
  AuthPolicy._();

  static const int minPasswordLength = 8;

  static String get passwordHint => 'Tối thiểu $minPasswordLength ký tự';
}
