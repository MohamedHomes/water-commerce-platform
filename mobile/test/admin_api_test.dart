import 'dart:convert';
import 'dart:typed_data';

import 'package:aquaflow_mobile/admin/admin_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemoryTokenStore store;
  late _ResponseAdapter adapter;
  late Dio dio;
  late AdminApiClient api;

  setUp(() {
    store = _MemoryTokenStore();
    adapter = _ResponseAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
      ..httpClientAdapter = adapter;
    api = AdminApiClient(dio: dio, tokenStore: store);
  });

  tearDown(() => dio.close(force: true));

  test('stores admin session only in its dedicated secure storage keys',
      () async {
    adapter.respond = (request) => {
          'accessToken': 'access-test',
          'refreshToken': 'refresh-test',
          'customer': {'role': 'admin'},
        };

    await api.login('admin@example.test', 'password');

    expect(store.values[AdminApiClient.accessTokenKey], 'access-test');
    expect(store.values[AdminApiClient.refreshTokenKey], 'refresh-test');
    expect(store.values, isNot(contains('auth_token')));
    expect(adapter.requests.single.path, '/auth/login');
  });

  test('rejects customer login and clears any prior admin session', () async {
    store.values[AdminApiClient.accessTokenKey] = 'old-admin-token';
    store.values[AdminApiClient.refreshTokenKey] = 'old-admin-refresh';
    adapter.respond = (_) => {
          'accessToken': 'customer-access',
          'refreshToken': 'customer-refresh',
          'customer': {'role': 'customer'},
        };

    await expectLater(
      api.login('customer@example.test', 'password'),
      throwsA(isA<AdminAuthorizationException>()),
    );

    expect(await api.hasStoredSession(), isFalse);
    expect(store.values, isNot(contains('auth_token')));
  });

  test('validates admin role and sends the stored token on admin requests',
      () async {
    store.values[AdminApiClient.accessTokenKey] = 'admin-access';
    adapter.respond = (request) {
      if (request.path.endsWith('/auth/profile')) return {'role': 'admin'};
      return {'items': []};
    };

    expect(await api.validateSession(), isTrue);
    expect(await api.get('/admin/products'), {'items': []});

    expect(adapter.requests.last.path, '/admin/products');
    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer admin-access',
    );
  });

  test('clears stored session when profile role is no longer admin', () async {
    store.values[AdminApiClient.accessTokenKey] = 'former-admin-access';
    store.values[AdminApiClient.refreshTokenKey] = 'former-admin-refresh';
    adapter.respond = (_) => {'role': 'customer'};

    expect(await api.validateSession(), isFalse);
    expect(await api.hasStoredSession(), isFalse);
  });

  test('does not issue an admin request without an admin access token',
      () async {
    await expectLater(
      api.get('/admin/dashboard'),
      throwsA(isA<AdminAuthorizationException>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test('admin logout removes only admin session keys', () async {
    store.values[AdminApiClient.accessTokenKey] = 'admin-access';
    store.values[AdminApiClient.refreshTokenKey] = 'admin-refresh';
    store.values['auth_token'] = 'customer-access';
    store.values['refresh_token'] = 'customer-refresh';

    await api.logout();

    expect(await api.hasStoredSession(), isFalse);
    expect(store.values['auth_token'], 'customer-access');
    expect(store.values['refresh_token'], 'customer-refresh');
  });
}

class _MemoryTokenStore implements AdminTokenStore {
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

class _ResponseAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Map<String, dynamic> Function(RequestOptions request) respond =
      (_) => <String, dynamic>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(respond(options)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
