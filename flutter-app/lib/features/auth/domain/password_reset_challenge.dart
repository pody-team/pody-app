class PasswordResetChallenge {
  const PasswordResetChallenge({
    required this.email,
    required this.message,
    required this.otpRequired,
    required this.otpSentAt,
    required this.otpExpiresAt,
    required this.otpLength,
  });

  final String email;
  final String message;
  final bool otpRequired;
  final DateTime otpSentAt;
  final DateTime otpExpiresAt;
  final int otpLength;

  factory PasswordResetChallenge.fromJson(Map<String, dynamic> json) {
    return PasswordResetChallenge(
      email: json['email'] as String? ?? '',
      message: json['message'] as String? ?? '',
      otpRequired: json['otp_required'] as bool? ?? false,
      otpSentAt:
          DateTime.tryParse(json['otp_sent_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      otpExpiresAt:
          DateTime.tryParse(json['otp_expires_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      otpLength: json['otp_length'] as int? ?? 6,
    );
  }
}
