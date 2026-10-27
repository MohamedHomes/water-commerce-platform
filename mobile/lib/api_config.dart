import 'package:flutter/foundation.dart';

const _configuredApiBaseUrl = String.fromEnvironment('AQUAFLOW_API_BASE_URL');

String get apiBaseUrl {
  if (_configuredApiBaseUrl.isNotEmpty) {
    final uri = Uri.tryParse(_configuredApiBaseUrl);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        !uri.path.endsWith('/api/v1')) {
      throw StateError(
        'AQUAFLOW_API_BASE_URL must be an HTTP(S) URL ending in /api/v1',
      );
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError('Release builds require an HTTPS AQUAFLOW_API_BASE_URL');
    }
    return _configuredApiBaseUrl;
  }
  if (kReleaseMode) {
    throw StateError(
        'AQUAFLOW_API_BASE_URL must be configured for release builds');
  }
  if (kIsWeb) return 'http://localhost:3000/api/v1';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000/api/v1';
  }
  return 'http://localhost:3000/api/v1';
}
