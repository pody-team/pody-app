class VerificationChallenge {
  const VerificationChallenge({
    required this.email,
    required this.verificationRequired,
    required this.verificationSentAt,
    required this.verificationExpiresAt,
    required this.message,
  });

  final String email;
  final bool verificationRequired;
  final DateTime verificationSentAt;
  final DateTime verificationExpiresAt;
  final String message;

  factory VerificationChallenge.fromJson(Map<String, dynamic> json) {
    return VerificationChallenge(
      email: json['email'] as String? ?? '',
      verificationRequired: json['verification_required'] as bool? ?? false,
      verificationSentAt: DateTime.parse(
        json['verification_sent_at'] as String,
      ),
      verificationExpiresAt: DateTime.parse(
        json['verification_expires_at'] as String,
      ),
      message: json['message'] as String? ?? '',
    );
  }
}
