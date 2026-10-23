import 'package:flutter/foundation.dart';

const _configuredApiBaseUrl = String.fromEnvironment('AQUAFLOW_API_BASE_URL');

String get apiBaseUrl {
  if (_configuredApiBaseUrl.isNotEmpty) return _configuredApiBaseUrl;
  if (kIsWeb) return 'http://localhost:3000/api/v1';
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000/api/v1';
  }
  return 'http://localhost:3000/api/v1';
}
