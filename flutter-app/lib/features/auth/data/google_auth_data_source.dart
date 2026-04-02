import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

abstract class GoogleAuthDataSource {
  Future<String> signIn();

  Future<void> signOut();
}

class GoogleSignInDataSource implements GoogleAuthDataSource {
  GoogleSignInDataSource({String? clientId, String? serverClientId})
    : _clientId = _normalize(clientId),
      _serverClientId = _normalize(serverClientId),
      _googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        clientId: _supportsClientId ? _normalize(clientId) : null,
        serverClientId: kIsWeb ? null : _normalize(serverClientId),
      );

  final String? _clientId;
  final String? _serverClientId;
  final GoogleSignIn _googleSignIn;

  @override
  Future<String> signIn() async {
    if (kIsWeb && (_clientId == null || _clientId!.isEmpty)) {
      throw const GoogleAuthException(
        'Google Sign-In tren web can GOOGLE_WEB_CLIENT_ID hoac GOOGLE_CLIENT_ID.',
      );
    }

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const GoogleAuthException('Ban da huy dang nhap Google.');
      }

      final authentication = await account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw GoogleAuthException(_missingIdTokenMessage);
      }

      return idToken;
    } on PlatformException catch (error) {
      throw GoogleAuthException(_humanizePlatformError(error));
    } catch (error) {
      if (error is GoogleAuthException) {
        rethrow;
      }

      throw const GoogleAuthException(
        'Dang nhap Google that bai. Vui long thu lai.',
      );
    }
  }

  @override
  Future<void> signOut() {
    return _googleSignIn.signOut();
  }

  String get _missingIdTokenMessage {
    if (kIsWeb) {
      return 'Khong the lay Google ID token. Hay kiem tra GOOGLE_WEB_CLIENT_ID va GOOGLE_CLIENT_IDS o backend.';
    }

    if (_supportsClientId && (_clientId == null || _clientId!.isEmpty)) {
      return 'Khong the lay Google ID token. Hay kiem tra Google client ID cua ung dung.';
    }

    if (!kIsWeb && (_serverClientId == null || _serverClientId!.isEmpty)) {
      return 'Khong the lay Google ID token. Hay kiem tra GOOGLE_SERVER_CLIENT_ID.';
    }

    return 'Khong the lay Google ID token. Hay kiem tra cau hinh Google Sign-In.';
  }

  String _humanizePlatformError(PlatformException error) {
    switch (error.code) {
      case GoogleSignIn.kSignInCanceledError:
        return 'Ban da huy dang nhap Google.';
      case GoogleSignIn.kNetworkError:
        return 'Khong ket noi duoc toi Google. Vui long thu lai.';
      case GoogleSignIn.kSignInFailedError:
        break;
    }

    final message = (error.message ?? '').trim();
    if (message.contains('ClientID not set')) {
      return 'Google Sign-In tren web chua duoc cau hinh client ID.';
    }
    if (message.contains('serverClientId is not supported on Web')) {
      return 'Google Sign-In tren web dang duoc cau hinh sai client ID.';
    }
    if (message.contains('missing support for the following URL schemes')) {
      return 'Google Sign-In tren iPhone chua duoc cau hinh URL scheme.';
    }

    return _missingIdTokenMessage;
  }

  static bool get _supportsClientId {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  static String? _normalize(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);

  final String message;

  @override
  String toString() => 'GoogleAuthException(message: $message)';
}
