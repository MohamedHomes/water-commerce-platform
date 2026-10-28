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
    expect(find.text('12345678'), findsOneWidget);
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

  testWidgets(
      'orders support API status filtering, current-page search, and pagination',
      (tester) async {
    final api = _FakeAdminApi()..ordersTotal = 25;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdminOperationsTab(api: api)),
    ));
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    expect(api.getPaths, contains('/admin/orders'));
    expect(api.orderQueries.last, containsPair('limit', 20));
    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(find.textContaining('Regular Customer'), findsOneWidget);
    expect(find.textContaining('Order status: Placed'), findsOneWidget);
    expect(find.textContaining('Delivery status: Pending dispatch'),
        findsOneWidget);

    await tester.enterText(find.byType(TextField), 'no-such-order');
    await tester.pumpAndSettle();
    expect(find.text('No matching results.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(api.orderQueries.last, containsPair('page', 2));
    expect(find.text('Page 2 of 2'), findsOneWidget);
  });

  testWidgets(
      'order details show real API fields and confirm supported delivery transitions',
      (tester) async {
    final api = _FakeAdminApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdminOperationsTab(api: api)),
    ));
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Order 12345678'));
    await tester.pumpAndSettle();

    expect(api.getPaths, contains('/admin/orders/${_FakeAdminApi.orderId}'));
    expect(find.text('Aqua Admin'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Test water'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Test water'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('TESTTRACK001'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('TESTTRACK001'), findsOneWidget);

    await tester.ensureVisible(find.text('Mark Assigned'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark Assigned'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm delivery status change to Assigned?'),
        findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(api.patchPaths, contains('/admin/deliveries/delivery-1/status'));
    expect(api.patchData.last, containsPair('status', 'assigned'));
    expect(find.text('Assigned'), findsWidgets);
  });

  testWidgets(
      'a saved delivery update is not reported as failed on refresh error',
      (tester) async {
    final api = _FakeAdminApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdminOperationsTab(api: api)),
    ));
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Order 12345678'));
    await tester.pumpAndSettle();
    api.failurePaths.add('/admin/orders/${_FakeAdminApi.orderId}');

    await tester.ensureVisible(find.text('Mark Assigned'));
    await tester.tap(find.text('Mark Assigned'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(api.patchPaths, contains('/admin/deliveries/delivery-1/status'));
    expect(find.textContaining('Refresh failed; saved changes remain applied.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('order details use Arabic labels and right-to-left layout',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AdminOrderDetailsScreen(
          api: _FakeAdminApi(),
          orderId: _FakeAdminApi.orderId,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final title = find.text('تفاصيل الطلب');
    expect(title, findsOneWidget);
    expect(
      Directionality.of(tester.element(title)),
      TextDirection.rtl,
    );
  });

  testWidgets('delivery list filters statuses and searches the loaded results',
      (tester) async {
    final api = _FakeAdminApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdminOperationsTab(api: api)),
    ));
    await tester.tap(find.text('Deliveries'));
    await tester.pumpAndSettle();

    expect(api.getPaths, contains('/admin/deliveries'));
    expect(find.text('Order 12345678'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assigned').last);
    await tester.pumpAndSettle();
    expect(find.text('No matching results.'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'no-such-delivery');
    await tester.pumpAndSettle();
    expect(find.text('No matching results.'), findsOneWidget);
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

  testWidgets('inventory history displays persisted movement details',
      (tester) async {
    final api = _FakeAdminApi();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdminOperationsTab(api: api)),
    ));
    await tester.tap(find.text('Operations'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View stock movements'));
    await tester.pumpAndSettle();

    expect(
      api.getPaths,
      contains('/admin/inventory/product-1/movements'),
    );
    expect(find.textContaining('Administrator adjustment'), findsOneWidget);
    expect(find.textContaining('admin-1'), findsOneWidget);
  });

  testWidgets('inventory adjustment errors stay in the Admin screen',
      (tester) async {
    final api = _FakeAdminApi()..postError = StateError('Request failed');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AdminOperationsTab(api: api)),
    ));
    await tester.tap(find.text('Operations'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Adjust stock'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '-2');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Request failed'), findsOneWidget);
    expect(find.text('Mineral water'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
  static const orderId = '12345678-0000-4000-8000-000000000001';

  bool validSession = true;
  bool loggedIn = false;
  int validationCalls = 0;
  int ordersTotal = 1;
  Object? loginError;
  Object? postError;
  final getPaths = <String>[];
  final orderQueries = <Map<String, dynamic>?>[];
  final postPaths = <String>[];
  final postData = <Object?>[];
  final patchPaths = <String>[];
  final patchData = <Object?>[];
  final failurePaths = <String>{};
  final orders = <Map<String, dynamic>>[
    {
      'id': orderId,
      'customerId': 'customer-12345678',
      'customerName': 'Regular Customer',
      'status': 'placed',
      'deliveryStatus': 'pending_dispatch',
      'paymentMethod': 'cash',
      'total': 17,
      'currency': 'SAR',
      'createdAt': '2026-10-28T12:00:00.000Z',
    },
  ];
  final deliveries = <Map<String, dynamic>>[
    {
      'id': 'delivery-1',
      'order_id': orderId,
      'status': 'pending_dispatch',
      'estimated_minutes': 45,
    },
  ];
  final orderDetails = <String, dynamic>{
    'id': orderId,
    'status': 'paid',
    'paymentStatus': 'succeeded',
    'paymentMethod': 'card',
    'deliveryOption': 'standard',
    'customer': {
      'id': 'customer-1',
      'email': 'admin@example.test',
      'firstName': 'Aqua',
      'lastName': 'Admin',
      'phone': '+966500000123',
    },
    'items': [
      {
        'productId': 'product-test',
        'name': 'Test water',
        'quantity': 2,
        'unitPrice': 5,
        'lineTotal': 10,
      },
    ],
    'address': {'recipientName': 'Aqua Admin', 'city': 'Riyadh'},
    'deliveryZone': {'city': 'Riyadh', 'name': 'Central'},
    'summary': {
      'subtotal': 10,
      'discount': 0,
      'deliveryFee': 5,
      'serviceFee': 2,
      'total': 17,
      'currency': 'SAR',
    },
    'payments': [
      {
        'provider': 'test-provider',
        'status': 'succeeded',
        'amount': 17,
        'currency': 'SAR',
        'createdAt': '2026-10-28T12:00:00.000Z',
      },
    ],
    'delivery': {
      'id': 'delivery-1',
      'status': 'pending_dispatch',
      'estimatedMinutes': 45,
      'trackingCode': 'TESTTRACK001',
      'events': [
        {
          'status': 'pending_dispatch',
          'note': 'Order is ready for dispatch',
          'createdAt': '2026-10-28T12:00:00.000Z',
        },
      ],
    },
    'createdAt': '2026-10-28T12:00:00.000Z',
    'updatedAt': '2026-10-28T12:00:00.000Z',
  };
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
    if (path == '/admin/orders') {
      orderQueries.add(query == null ? null : Map.of(query));
      return {
        'items': orders,
        'total': ordersTotal,
        'page': query?['page'] ?? 1,
        'limit': query?['limit'] ?? 20,
      };
    }
    if (path == '/admin/orders/$orderId') return orderDetails;
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
      case '/admin/inventory/product-1/movements':
        return {
          'items': [
            {
              'id': 'movement-1',
              'orderId': null,
              'adminId': 'admin-12345678',
              'quantityDelta': 3,
              'reason': 'inventory_adjustment',
              'createdAt': '2026-10-28T12:00:00.000Z',
            }
          ],
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
      case '/admin/deliveries':
        return {'items': deliveries};
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
    if (postError != null) throw postError!;
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> patch(String path, {Object? data}) async {
    patchPaths.add(path);
    patchData.add(data);
    if (path == '/admin/deliveries/delivery-1/status' &&
        data is Map<String, dynamic>) {
      final delivery = orderDetails['delivery'] as Map<String, dynamic>;
      delivery['status'] = data['status'];
      (delivery['events'] as List<Map<String, dynamic>>).add({
        'status': data['status'],
        'note': data['note'],
        'createdAt': '2026-10-28T12:01:00.000Z',
      });
      return {'id': 'delivery-1', 'status': data['status']};
    }
    return <String, dynamic>{};
  }

  @override
  String errorMessage(Object error) =>
      error is AdminAuthorizationException ? error.message : 'Request failed';
}
