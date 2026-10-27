import 'package:aquaflow_mobile/admin/admin_api.dart';
import 'package:aquaflow_mobile/admin/admin_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin login shows errors and does not enter for a customer',
      (tester) async {
    final api = _FakeAdminApi()
      ..loginError = const AdminAuthorizationException(
        'This account does not have administrator access.',
      );
    var signedIn = false;
    await tester.pumpWidget(MaterialApp(
      home: ProviderScope(
        child: AdminLoginScreen(
          api: api,
          onSignedIn: () => signedIn = true,
        ),
      ),
    ));

    await tester.enterText(find.byKey(const Key('admin-email')), 'user@test');
    await tester.enterText(
        find.byKey(const Key('admin-password')), 'not-a-token');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('This account does not have administrator access.'),
        findsOneWidget);
    expect(signedIn, isFalse);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('admin-password')),
              matching: find.byType(TextField),
            ),
          )
          .obscureText,
      isTrue,
    );
  });

  testWidgets('admin login navigates only after successful role validation',
      (tester) async {
    final api = _FakeAdminApi();
    var signedIn = false;
    await tester.pumpWidget(MaterialApp(
      home: ProviderScope(
        child: AdminLoginScreen(
          api: api,
          onSignedIn: () => signedIn = true,
        ),
      ),
    ));

    await tester.enterText(find.byKey(const Key('admin-email')), 'admin@test');
    await tester.enterText(find.byKey(const Key('admin-password')), 'correct');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(api.loggedIn, isTrue);
    expect(signedIn, isTrue);
  });

  testWidgets('admin login translates and lays out right-to-left in Arabic',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AdminLoginScreen(
          api: _FakeAdminApi(),
          onSignedIn: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل دخول المسؤول'), findsOneWidget);
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byKey(const Key('admin-email')))),
      TextDirection.rtl,
    );
  });

  testWidgets(
      'route gate blocks protected screens when no admin session exists',
      (tester) async {
    final api = _FakeAdminApi()..validSession = false;
    await tester.pumpWidget(MaterialApp(
      home: AdminRouteGate(
        api: api,
        child: const Text('Protected Admin content'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Administrator sign-in is required.'), findsOneWidget);
    expect(find.text('Protected Admin content'), findsNothing);
    expect(api.validationCalls, 1);
  });

  testWidgets('dashboard displays API metrics and recent orders',
      (tester) async {
    final api = _FakeAdminApi();
    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardTab(api: api),
    ));
    await tester.pumpAndSettle();

    expect(find.text('42'), findsOneWidget);
    expect(find.text('Recent orders'), findsOneWidget);
    expect(find.text('order-12'), findsOneWidget);
    expect(api.getPaths, contains('/admin/dashboard'));
    expect(api.getPaths, contains('/admin/orders'));
  });

  testWidgets('dashboard exposes a retry state when the API fails',
      (tester) async {
    final api = _FakeAdminApi()..failurePaths.add('/admin/dashboard');
    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardTab(api: api),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Request failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    api.failurePaths.clear();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Recent orders'), findsOneWidget);
  });

  testWidgets('products tab shows real API product data and empty states',
      (tester) async {
    final api = _FakeAdminApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdminProductsTab(api: api)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mineral water'), findsOneWidget);
    expect(find.text('in stock · 12 units · SAR 4.5'), findsOneWidget);
    expect(api.getPaths, contains('/admin/products'));

    api.products = [];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        key: const ValueKey('empty-products'),
        body: AdminProductsTab(api: api),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No products found.'), findsOneWidget);
  });

  testWidgets('products tab uses Arabic names and Arabic stock labels',
      (tester) async {
    final api = _FakeAdminApi()
      ..products = [
        {
          'id': 'product-ar',
          'name': 'Mineral water',
          'name_ar': 'مياه معدنية',
          'quantity': 12,
          'availability': 'in_stock',
          'price': 4.5,
          'is_active': true,
        }
      ];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: AdminProductsTab(api: api)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('مياه معدنية'), findsOneWidget);
    expect(find.textContaining('متوفر'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('مياه معدنية'))),
      TextDirection.rtl,
    );
  });

  testWidgets('product details are editable through the existing Admin API',
      (tester) async {
    final api = _FakeAdminApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdminProductsTab(api: api)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Product actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).at(0), 'Updated mineral water');
    await tester.enterText(find.byType(TextField).at(1), 'مياه معدنية محدثة');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(api.patchPaths, contains('/admin/products/product-1'));
    expect(api.patchData.single, containsPair('nameAr', 'مياه معدنية محدثة'));
  });

  testWidgets('new products submit optional Arabic names to the Admin API',
      (tester) async {
    final api = _FakeAdminApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdminProductsTab(api: api)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add product'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'New mineral water');
    await tester.enterText(find.byType(TextFormField).at(1), 'مياه معدنية');
    await tester.enterText(
        find.byType(TextFormField).at(2), 'new-mineral-water');
    await tester.enterText(find.byType(TextFormField).at(3), '5.25');
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water products').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AquaFlow brand').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create').last);
    await tester.pumpAndSettle();

    expect(api.postPaths, contains('/admin/products'));
    expect(api.postData.single, containsPair('nameAr', 'مياه معدنية'));
  });

  testWidgets('Admin navigation loads operations through supported API',
      (tester) async {
    final api = _FakeAdminApi();
    await tester.pumpWidget(MaterialApp(
      home: ProviderScope(child: AdminHomeScreen(api: api)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Operations'));
    await tester.pumpAndSettle();
    expect(find.text('Inventory'), findsWidgets);
    expect(find.text('12 units · in stock'), findsOneWidget);
    expect(api.getPaths, contains('/admin/inventory'));
  });

  testWidgets('catalog screen loads categories and brands from Admin API',
      (tester) async {
    final api = _FakeAdminApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdminCatalogTab(api: api)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Water products'), findsOneWidget);
    expect(find.text('AquaFlow brand'), findsOneWidget);
    expect(api.getPaths, contains('/admin/catalog-terms'));
  });

  testWidgets('locations screen displays existing city and zone data read-only',
      (tester) async {
    final api = _FakeAdminApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdminLocationsTab(api: api)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Riyadh'), findsOneWidget);
    expect(
      find.text(
        'Standard SAR 5 · Express SAR 10 · 45 minutes',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.text('Zone configuration is not editable through the current API.'),
      findsOneWidget,
    );
    expect(api.getPaths, contains('/addresses/cities'));
    expect(api.getPaths, contains('/addresses/delivery-zones'));
  });
}

class _FakeAdminApi implements AdminApi {
  bool validSession = true;
  bool loggedIn = false;
  int validationCalls = 0;
  Object? loginError;
  final getPaths = <String>[];
  final postPaths = <String>[];
  final postData = <Object?>[];
  final patchPaths = <String>[];
  final patchData = <Object?>[];
  final failurePaths = <String>{};
  List<Map<String, dynamic>> products = [
    {
      'id': 'product-1',
      'name': 'Mineral water',
      'slug': 'mineral-water',
      'quantity': 12,
      'availability': 'in_stock',
      'price': 4.5,
      'is_active': true,
    }
  ];

  @override
  Future<void> login(String email, String password) async {
    if (loginError != null) throw loginError!;
    loggedIn = true;
  }

  @override
  Future<bool> hasStoredSession() async => loggedIn;

  @override
  Future<bool> validateSession() async {
    validationCalls++;
    return validSession;
  }

  @override
  Future<void> logout() async {
    loggedIn = false;
  }

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    getPaths.add(path);
    if (failurePaths.contains(path)) throw StateError('Request failed');
    switch (path) {
      case '/admin/dashboard':
        return {
          'totalOrders': 42,
          'openOrders': 5,
          'awaitingPayment': 2,
          'paidRevenue': 300,
          'pendingDispatch': 1,
          'activeProducts': 8,
          'currency': 'SAR',
        };
      case '/admin/orders':
        return {
          'items': [
            {
              'id': 'order-12345678',
              'status': 'placed',
              'paymentMethod': 'cash',
              'total': 20,
              'currency': 'SAR',
            }
          ]
        };
      case '/admin/products':
        return {'items': products};
      case '/admin/inventory':
        return {
          'items': [
            {
              'id': 'product-1',
              'name': 'Mineral water',
              'quantity': 12,
              'availability': 'in_stock',
            }
          ]
        };
      case '/admin/catalog-terms':
        return {
          'categories': [
            {
              'id': 'category-1',
              'name': 'Water products',
              'slug': 'water-products',
            }
          ],
          'brands': [
            {
              'id': 'brand-1',
              'name': 'AquaFlow brand',
              'slug': 'aquaflow',
            }
          ],
        };
      case '/addresses/cities':
        return {
          'items': [
            {
              'id': 'city-1',
              'name': 'Riyadh',
              'region': 'Central',
              'countryCode': 'SA',
            }
          ],
        };
      case '/addresses/delivery-zones':
        return {
          'items': [
            {
              'id': 'zone-1',
              'city': 'Riyadh',
              'name': 'Central',
              'baseFee': 5,
              'expressFee': 10,
              'estimatedMinutes': 45,
            }
          ],
        };
      default:
        return {'items': []};
    }
  }

  @override
  Future<Map<String, dynamic>> post(String path, {Object? data}) async {
    postPaths.add(path);
    postData.add(data);
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> patch(String path, {Object? data}) async {
    patchPaths.add(path);
    patchData.add(data);
    return <String, dynamic>{};
  }

  @override
  String errorMessage(Object error) =>
      error is AdminAuthorizationException ? error.message : 'Request failed';
}
