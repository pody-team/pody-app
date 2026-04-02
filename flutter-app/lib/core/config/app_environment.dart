import 'package:flutter/foundation.dart';

class AppEnvironment {
  AppEnvironment._();

  static const _defaultApiBaseUrl = 'https://laihieu2714.ddns.net';
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _configuredGoogleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );
  static const _configuredGoogleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const _configuredGoogleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
  static const _configuredGoogleMacosClientId = String.fromEnvironment(
    'GOOGLE_MACOS_CLIENT_ID',
  );
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

  static String? get googleClientId {
    if (kIsWeb) {
      return _firstNonEmpty([
        _configuredGoogleWebClientId,
        _configuredGoogleClientId,
        googleServerClientId,
      ]);
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => _firstNonEmpty([
        _configuredGoogleIosClientId,
        _configuredGoogleClientId,
      ]),
      TargetPlatform.macOS => _firstNonEmpty([
        _configuredGoogleMacosClientId,
        _configuredGoogleIosClientId,
        _configuredGoogleClientId,
      ]),
      _ => _firstNonEmpty([_configuredGoogleClientId]),
    };
  }

  static String? get googleServerClientId {
    return _firstNonEmpty([
      _configuredGoogleServerClientId,
      _defaultGoogleServerClientId,
    ]);
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return null;
  }
}
