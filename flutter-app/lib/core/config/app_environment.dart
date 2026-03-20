import 'package:flutter/foundation.dart';

class AppEnvironment {
  AppEnvironment._();

  // static const _defaultApiBaseUrl = 'http://laihieu2714.ddns.net:8080';
  static const _defaultApiBaseUrl = 'http://192.168.100.206:8080';
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
      return _defaultApiBaseUrl;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _defaultApiBaseUrl,
      _ => _defaultApiBaseUrl,
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
