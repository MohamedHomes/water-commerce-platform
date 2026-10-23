import 'package:flutter/foundation.dart';

const _configuredApiBaseUrl = String.fromEnvironment('AQUAFLOW_API_BASE_URL');

String get apiBaseUrl {
  if (_configuredApiBaseUrl.isNotEmpty) {
    final uri = Uri.tryParse(_configuredApiBaseUrl);
    if (kReleaseMode && (uri == null || uri.scheme != 'https' || uri.host.isEmpty)) {
      throw StateError('Release builds require an HTTPS AQUAFLOW_API_BASE_URL');
    }
    return _configuredApiBaseUrl;
  }
  if (kReleaseMode) {
    throw StateError('AQUAFLOW_API_BASE_URL must be configured for release builds');
  }
  if (kIsWeb) return 'http://localhost:3000/api/v1';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000/api/v1';
  }
  return 'http://localhost:3000/api/v1';
}
