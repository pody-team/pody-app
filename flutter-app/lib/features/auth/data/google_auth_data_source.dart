import 'package:google_sign_in/google_sign_in.dart';

abstract class GoogleAuthDataSource {
  Future<String> signIn();

  Future<void> signOut();
}

class GoogleSignInDataSource implements GoogleAuthDataSource {
  GoogleSignInDataSource({required String serverClientId})
    : _googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: serverClientId,
      );

  final GoogleSignIn _googleSignIn;

  @override
  Future<String> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw const GoogleAuthException('Ban da huy dang nhap Google.');
    }

    final authentication = await account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const GoogleAuthException(
        'Khong the lay Google ID token. Hay kiem tra cau hinh Google Sign-In.',
      );
    }

    return idToken;
  }

  @override
  Future<void> signOut() {
    return _googleSignIn.signOut();
  }
}

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);

  final String message;

  @override
  String toString() => 'GoogleAuthException(message: $message)';
}
