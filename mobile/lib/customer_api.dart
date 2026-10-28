import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';

abstract interface class CustomerTokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureCustomerTokenStore implements CustomerTokenStore {
  SecureCustomerTokenStore([FlutterSecureStorage? storage])
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

class CustomerSession {
  CustomerSession._();

  static const accessTokenKey = 'auth_token';
  static const refreshTokenKey = 'refresh_token';
  static final CustomerTokenStore tokens = SecureCustomerTokenStore();
  static final ValueNotifier<int> changes = ValueNotifier(0);
  static Future<String?>? _refreshInProgress;

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await tokens.write(accessTokenKey, accessToken);
    await tokens.write(refreshTokenKey, refreshToken);
    notifyChanged();
  }

  static Future<void> clearTokens() async {
    await tokens.delete(accessTokenKey);
    await tokens.delete(refreshTokenKey);
    notifyChanged();
  }

  static void notifyChanged() {
    changes.value++;
  }

  static Future<String?> refreshAccessToken({
    required CustomerTokenStore tokenStore,
    required String expiredAccessToken,
    required Future<String?> Function() refresh,
  }) async {
    final pendingRefresh = _refreshInProgress;
    if (pendingRefresh != null) return pendingRefresh;

    final storedAccessToken = await tokenStore.read(accessTokenKey);
    if (storedAccessToken != null &&
        storedAccessToken.isNotEmpty &&
        storedAccessToken != expiredAccessToken) {
      return storedAccessToken;
    }

    final refreshFuture = refresh();
    _refreshInProgress = refreshFuture;
    try {
      return await refreshFuture;
    } finally {
      if (identical(_refreshInProgress, refreshFuture)) {
        _refreshInProgress = null;
      }
    }
  }
}

class CustomerApi {
  CustomerApi._();

  static Dio createDio({
    Dio? dio,
    CustomerTokenStore? tokenStore,
    VoidCallback? onSessionChanged,
  }) {
    final client = dio ?? Dio(BaseOptions(baseUrl: apiBaseUrl));
    client.interceptors.add(
      CustomerAuthInterceptor(
        dio: client,
        tokenStore: tokenStore ?? CustomerSession.tokens,
        onSessionChanged: onSessionChanged ?? CustomerSession.notifyChanged,
      ),
    );
    return client;
  }
}

class CustomerAuthInterceptor extends Interceptor {
  CustomerAuthInterceptor({
    required Dio dio,
    required CustomerTokenStore tokenStore,
    required VoidCallback onSessionChanged,
  })  : _dio = dio,
        _tokenStore = tokenStore,
        _onSessionChanged = onSessionChanged;

  static const _retryKey = 'customerAuthRetried';
  static const _skipKey = 'skipCustomerAuth';

  final Dio _dio;
  final CustomerTokenStore _tokenStore;
  final VoidCallback _onSessionChanged;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final authorization = options.headers['Authorization'];
    if (options.extra[_skipKey] == true || authorization is! String) {
      handler.next(options);
      return;
    }

    try {
      final currentToken =
          await _tokenStore.read(CustomerSession.accessTokenKey);
      if (currentToken != null && currentToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $currentToken';
      }
      handler.next(options);
    } catch (error) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          message: 'Unable to read the customer session',
        ),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final authorization = options.headers['Authorization'];
    if (err.response?.statusCode != 401 ||
        options.extra[_retryKey] == true ||
        options.extra[_skipKey] == true ||
        authorization is! String ||
        !authorization.startsWith('Bearer ')) {
      handler.next(err);
      return;
    }

    try {
      final accessToken = authorization.substring('Bearer '.length).trim();
      final refreshedToken = await _refreshAccessToken(accessToken);
      if (refreshedToken == null) {
        handler.next(err);
        return;
      }

      final retryOptions = options.copyWith(
        headers: {
          ...options.headers,
          'Authorization': 'Bearer $refreshedToken',
        },
        extra: {...options.extra, _retryKey: true},
      );
      handler.resolve(await _dio.fetch<dynamic>(retryOptions));
    } catch (refreshError) {
      handler.reject(
        refreshError is DioException
            ? refreshError
            : DioException(
                requestOptions: options,
                error: refreshError,
                message: 'Unable to refresh the customer session',
              ),
      );
    }
  }

  Future<String?> _refreshAccessToken(String expiredAccessToken) async {
    return CustomerSession.refreshAccessToken(
      tokenStore: _tokenStore,
      expiredAccessToken: expiredAccessToken,
      refresh: _refreshTokens,
    );
  }

  Future<String?> _refreshTokens() async {
    final refreshToken =
        await _tokenStore.read(CustomerSession.refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      await _expireSession();
      return null;
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {_skipKey: true}),
      );
      final accessToken = response.data?['accessToken'];
      final nextRefreshToken = response.data?['refreshToken'];
      if (accessToken is! String ||
          accessToken.isEmpty ||
          nextRefreshToken is! String ||
          nextRefreshToken.isEmpty) {
        throw const FormatException('Invalid token refresh response');
      }
      await _tokenStore.write(CustomerSession.accessTokenKey, accessToken);
      await _tokenStore.write(
        CustomerSession.refreshTokenKey,
        nextRefreshToken,
      );
      return accessToken;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) await _expireSession();
      rethrow;
    }
  }

  Future<void> _expireSession() async {
    await _tokenStore.delete(CustomerSession.accessTokenKey);
    await _tokenStore.delete(CustomerSession.refreshTokenKey);
    _onSessionChanged();
  }
}
