import 'package:flutter/foundation.dart';

class AppEnvironment {
  AppEnvironment._();

  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _configuredGoogleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const _defaultGoogleServerClientId =
      '283249494920-68vd67ss030ik3v5dbruttgsorn30t97.apps.googleusercontent.com';

  static String get apiBaseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:8080';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:8080',
      _ => 'http://localhost:8080',
    };
  }

  static String get publicIdentityBase => '$apiBaseUrl/api/v1/public/identity';

  static String get identityBase => '$apiBaseUrl/api/v1/identity';

  static String get googleServerClientId {
    if (_configuredGoogleServerClientId.isNotEmpty) {
      return _configuredGoogleServerClientId;
    }

    return _defaultGoogleServerClientId;
  }
}
