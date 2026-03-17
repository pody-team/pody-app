import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/password_reset_challenge.dart';
import '../domain/verification_challenge.dart';

enum AuthStatus { initializing, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.initializing;
  AuthSession? _session;

  AuthStatus get status => _status;

  AuthSession? get session => _session;

  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _session != null;

  Future<void> initialize() async {
    _status = AuthStatus.initializing;
    notifyListeners();

    _session = await _repository.restoreSession();
    _status = _session == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    _session = await _repository.signIn(email: email, password: password);
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    _session = await _repository.signInWithGoogle();
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<VerificationChallenge> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _repository.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
  }

  Future<VerificationChallenge> resendVerification(String email) {
    return _repository.resendVerification(email);
  }

  Future<PasswordResetChallenge> forgotPassword(String email) {
    return _repository.forgotPassword(email);
  }

  Future<String> verifyResetOTP({required String email, required String otp}) {
    return _repository.verifyResetOTP(email: email, otp: otp);
  }

  Future<String> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _repository.resetPassword(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
  }

  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> signOut() async {
    final currentSession = _session;
    _session = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();

    await _repository.signOut(currentSession);
  }
}
