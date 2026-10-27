import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api_config.dart';

abstract interface class AdminTokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterAdminTokenStore implements AdminTokenStore {
  FlutterAdminTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

abstract interface class AdminApi {
  Future<void> login(String email, String password);
  Future<bool> hasStoredSession();
  Future<bool> validateSession();
  Future<void> logout();
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  });
  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
  });
  Future<Map<String, dynamic>> patch(
    String path, {
    Object? data,
  });
  String errorMessage(Object error);
}

class AdminAuthorizationException implements Exception {
  const AdminAuthorizationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminApiClient implements AdminApi {
  AdminApiClient({
    Dio? dio,
    AdminTokenStore? tokenStore,
  })  : _dio = dio ?? Dio(BaseOptions(baseUrl: apiBaseUrl)),
        _tokenStore = tokenStore ?? FlutterAdminTokenStore();

  static const accessTokenKey = 'admin_access_token';
  static const refreshTokenKey = 'admin_refresh_token';

  final Dio _dio;
  final AdminTokenStore _tokenStore;

  @override
  Future<bool> hasStoredSession() async {
    final token = await _tokenStore.read(accessTokenKey);
    return token != null && token.isNotEmpty;
  }

  @override
  Future<void> login(String email, String password) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final payload = response.data;
    if (payload == null || payload['customer']?['role'] != 'admin') {
      await logout();
      throw const AdminAuthorizationException(
        'This account does not have administrator access.',
      );
    }
    final accessToken = payload['accessToken'];
    final refreshToken = payload['refreshToken'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
      throw const AdminAuthorizationException(
        'The server returned an incomplete administrator session.',
      );
    }
    await _tokenStore.write(accessTokenKey, accessToken);
    await _tokenStore.write(refreshTokenKey, refreshToken);
  }

  @override
  Future<bool> validateSession() async {
    final token = await _tokenStore.read(accessTokenKey);
    if (token == null || token.isEmpty) return false;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/auth/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final isAdmin = response.data?['role'] == 'admin';
      if (!isAdmin) await logout();
      return isAdmin;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        await logout();
        return false;
      }
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    await _tokenStore.delete(accessTokenKey);
    await _tokenStore.delete(refreshTokenKey);
  }

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) =>
      _request('GET', path, query: query);

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
  }) =>
      _request('POST', path, data: data);

  @override
  Future<Map<String, dynamic>> patch(
    String path, {
    Object? data,
  }) =>
      _request('PATCH', path, data: data);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    final token = await _tokenStore.read(accessTokenKey);
    if (token == null || token.isEmpty) {
      throw const AdminAuthorizationException(
        'Administrator sign-in is required.',
      );
    }
    final response = await _dio.request<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: query,
      options: Options(
        method: method,
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    return response.data ?? <String, dynamic>{};
  }

  @override
  String errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.isNotEmpty) return message;
        if (message is List && message.isNotEmpty) {
          return message.join(', ');
        }
      }
      if (error.response == null) {
        return 'Unable to reach the AquaFlow server. Check the API URL and network.';
      }
      return 'The request failed (${error.response?.statusCode ?? 'unknown'}).';
    }
    if (error is AdminAuthorizationException) return error.message;
    return 'The request could not be completed.';
  }
}
