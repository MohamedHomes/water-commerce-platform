import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aquaflow_mobile/customer_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemoryTokenStore tokens;
  late _ResponseAdapter adapter;
  late Dio dio;

  setUp(() {
    tokens = _MemoryTokenStore()
      ..values[CustomerSession.accessTokenKey] = 'expired-access'
      ..values[CustomerSession.refreshTokenKey] = 'valid-refresh';
    adapter = _ResponseAdapter();
    dio = CustomerApi.createDio(
      dio: Dio(BaseOptions(baseUrl: 'http://api.example.test/api/v1'))
        ..httpClientAdapter = adapter,
      tokenStore: tokens,
    );
  });

  tearDown(() => dio.close(force: true));

  test('refreshes an expired customer token and retries the original request',
      () async {
    adapter.respond = (request) {
      if (request.path == '/auth/refresh') {
        return _ApiResponse(200, {
          'accessToken': 'renewed-access',
          'refreshToken': 'rotated-refresh',
        });
      }
      if (request.headers['Authorization'] == 'Bearer expired-access') {
        return _ApiResponse(401, {'message': 'Invalid or expired token'});
      }
      return _ApiResponse(200, {'items': []});
    };

    final response = await dio.get<Map<String, dynamic>>(
      '/cart',
      options: Options(headers: {'Authorization': 'Bearer expired-access'}),
    );

    expect(response.data, {'items': []});
    expect(adapter.requests.map((request) => request.path), [
      '/cart',
      '/auth/refresh',
      '/cart',
    ]);
    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer renewed-access',
    );
    expect(tokens.values[CustomerSession.accessTokenKey], 'renewed-access');
    expect(tokens.values[CustomerSession.refreshTokenKey], 'rotated-refresh');
  });

  test('clears customer tokens when the refresh token has expired', () async {
    var sessionChanges = 0;
    dio.interceptors.clear();
    dio.interceptors.add(
      CustomerAuthInterceptor(
        dio: dio,
        tokenStore: tokens,
        onSessionChanged: () => sessionChanges++,
      ),
    );
    adapter.respond = (request) => request.path == '/auth/refresh'
        ? _ApiResponse(401, {'message': 'Invalid or expired refresh token'})
        : _ApiResponse(401, {'message': 'Invalid or expired token'});

    await expectLater(
      dio.get<void>(
        '/catalog/favorites',
        options: Options(headers: {'Authorization': 'Bearer expired-access'}),
      ),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'status code',
          401,
        ),
      ),
    );

    expect(tokens.values, isEmpty);
    expect(sessionChanges, 1);
    expect(adapter.requests.map((request) => request.path), [
      '/catalog/favorites',
      '/auth/refresh',
    ]);
  });

  test('coalesces expired-session refresh across customer API clients',
      () async {
    final otherDio = CustomerApi.createDio(
      dio: Dio(BaseOptions(baseUrl: 'http://api.example.test/api/v1'))
        ..httpClientAdapter = adapter,
      tokenStore: tokens,
    );
    addTearDown(() => otherDio.close(force: true));
    adapter.respond = (request) {
      if (request.path == '/auth/refresh') {
        return _ApiResponse(200, {
          'accessToken': 'renewed-access',
          'refreshToken': 'rotated-refresh',
        });
      }
      if (request.headers['Authorization'] == 'Bearer expired-access') {
        return _ApiResponse(401, {'message': 'Invalid or expired token'});
      }
      return _ApiResponse(200, {'items': []});
    };

    await Future.wait([
      dio.get<void>(
        '/cart',
        options: Options(headers: {'Authorization': 'Bearer expired-access'}),
      ),
      otherDio.get<void>(
        '/catalog/favorites',
        options: Options(headers: {'Authorization': 'Bearer expired-access'}),
      ),
    ]);

    expect(
      adapter.requests.where((request) => request.path == '/auth/refresh'),
      hasLength(1),
    );
  });

  test('does not refresh an unauthenticated public request', () async {
    adapter.respond = (_) => _ApiResponse(200, {'items': []});

    await dio.get<void>('/catalog/products');

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, '/catalog/products');
  });
}

class _MemoryTokenStore implements CustomerTokenStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _ApiResponse {
  const _ApiResponse(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
}

class _ResponseAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  _ApiResponse Function(RequestOptions request) respond =
      (_) => const _ApiResponse(200, {});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = respond(options);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
