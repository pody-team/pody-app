import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnvironment {
  AppEnvironment._();

  static const _defaultApiBaseUrl = 'http://172.11.67.156:8080';
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

    final envBaseUrl = dotenv.env['API_BASE_URL']?.trim() ?? '';
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
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

    final envServerClientId =
        dotenv.env['GOOGLE_SERVER_CLIENT_ID']?.trim() ?? '';
    if (envServerClientId.isNotEmpty) {
      return envServerClientId;
    }

    return _defaultGoogleServerClientId;
  }
}
