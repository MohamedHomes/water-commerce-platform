import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'api_config.dart';
import 'admin/admin_api.dart';
import 'admin/admin_mobile.dart';
import 'cart_screen.dart';
import 'catalog_screen.dart';
import 'customer_ui.dart';
import 'customer_api.dart';
import 'customer_navigation.dart';
import 'customer_profile.dart';
import 'favorites_screen.dart';
import 'localization.dart';

void main() {
  runApp(const ProviderScope(child: AquaFlowApp()));
}

final _secureStorage = FlutterSecureStorage();
final AdminApi _adminApi = AdminApiClient();
final ThemeData _adminTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E9F6E)),
  useMaterial3: true,
);

Address? _findAddress(List<Address> addresses, String? addressId) {
  for (final address in addresses) {
    if (address.id == addressId) return address;
  }
  return null;
}

class Address {
  const Address({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.city,
    required this.district,
    required this.street,
    required this.building,
    this.apartment,
    this.floor,
    this.latitude,
    this.longitude,
    this.notes,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String recipientName;
  final String phone;
  final String city;
  final String district;
  final String street;
  final String building;
  final String? apartment;
  final String? floor;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final bool isDefault;

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Home',
      recipientName: json['recipientName']?.toString() ?? 'Customer',
      phone: json['phone']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      street: json['street']?.toString() ?? '',
      building: json['building']?.toString() ?? '',
      apartment: json['apartment']?.toString(),
      floor: json['floor']?.toString(),
      latitude:
          json['latitude'] is num ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] is num
          ? (json['longitude'] as num).toDouble()
          : null,
      notes: json['notes']?.toString(),
      isDefault: json['isDefault'] == true,
    );
  }
}

class CheckoutSummary {
  const CheckoutSummary({
    required this.checkoutId,
    required this.subtotal,
    required this.discount,
    required this.promotionCode,
    required this.deliveryFee,
    required this.serviceFee,
    required this.total,
    required this.currency,
  });

  final String checkoutId;
  final double subtotal;
  final double discount;
  final String? promotionCode;
  final double deliveryFee;
  final double serviceFee;
  final double total;
  final String currency;

  factory CheckoutSummary.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    return CheckoutSummary(
      checkoutId: json['checkoutId']?.toString() ?? '',
      subtotal: (summary['subtotal'] ?? 0).toDouble(),
      discount: (summary['discount'] ?? 0).toDouble(),
      promotionCode: summary['promotionCode']?.toString(),
      deliveryFee: (summary['deliveryFee'] ?? 0).toDouble(),
      serviceFee: (summary['serviceFee'] ?? 0).toDouble(),
      total: (summary['total'] ?? 0).toDouble(),
      currency: (summary['currency'] ?? 'SAR').toString(),
    );
  }
}

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.name,
    this.nameAr,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String productId;
  final String name;
  final String? nameAr;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    return OrderLine(
      productId: json['productId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Product',
      nameAr: json['nameAr']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
    );
  }
}

class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.status,
    required this.paymentMethod,
    this.paymentStatus,
    this.deliveryStatus,
    required this.deliveryOption,
    required this.address,
    required this.items,
    required this.total,
    required this.currency,
    required this.createdAt,
  });

  final String id;
  final String status;
  final String paymentMethod;
  final String? paymentStatus;
  final String? deliveryStatus;
  final String deliveryOption;
  final Address address;
  final List<OrderLine> items;
  final double total;
  final String currency;
  final DateTime createdAt;

  factory OrderRecord.fromJson(Map<String, dynamic> json) {
    final addressJson = json['address'] as Map<String, dynamic>? ?? {};
    final summary = json['summary'] as Map<String, dynamic>? ?? {};
    final rawItems = json['items'] as List? ?? [];
    return OrderRecord(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      paymentMethod: json['paymentMethod']?.toString() ?? '',
      paymentStatus: json['paymentStatus']?.toString(),
      deliveryStatus: json['deliveryStatus']?.toString(),
      deliveryOption: json['deliveryOption']?.toString() ?? '',
      address: Address.fromJson(addressJson),
      items: rawItems
          .map((item) => OrderLine.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: (summary['total'] as num?)?.toDouble() ?? 0,
      currency: summary['currency']?.toString() ?? 'SAR',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

String customerOrderDisplayStatus(OrderRecord order) {
  if (order.status == 'cancelled') return 'cancelled';
  if (order.status == 'payment_pending' || order.status == 'payment_failed') {
    return order.status;
  }
  return order.deliveryStatus ?? order.status;
}

class PaymentIntent {
  const PaymentIntent({
    required this.id,
    required this.provider,
    required this.status,
    required this.amount,
    required this.currency,
    this.checkoutUrl,
  });

  final String id;
  final String provider;
  final String status;
  final double amount;
  final String currency;
  final String? checkoutUrl;

  factory PaymentIntent.fromJson(Map<String, dynamic> json) {
    return PaymentIntent(
      id: json['id']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'SAR',
      checkoutUrl: json['checkoutUrl']?.toString(),
    );
  }
}

class DeliveryTracking {
  const DeliveryTracking({
    required this.status,
    required this.estimatedMinutes,
    required this.trackingCode,
    required this.trackingAvailable,
    required this.events,
  });

  final String status;
  final int estimatedMinutes;
  final String trackingCode;
  final bool trackingAvailable;
  final List<String> events;

  factory DeliveryTracking.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'] as List? ?? [];
    return DeliveryTracking(
      status: json['status']?.toString() ?? 'unknown',
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 0,
      trackingCode: json['trackingCode']?.toString() ?? '',
      trackingAvailable: json['trackingAvailable'] == true,
      events: rawEvents
          .map((event) => (event as Map<String, dynamic>)['note'].toString())
          .toList(),
    );
  }
}

class CustomerNotification {
  const CustomerNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.readAt,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory CustomerNotification.fromJson(Map<String, dynamic> json) {
    return CustomerNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      readAt: json['readAt']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class DeliveryZone {
  const DeliveryZone({
    required this.id,
    required this.city,
    required this.name,
    required this.baseFee,
    required this.estimatedMinutes,
  });

  final String id;
  final String city;
  final String name;
  final double baseFee;
  final int estimatedMinutes;

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    return DeliveryZone(
      id: json['id'].toString(),
      city: json['city'].toString(),
      name: json['name'].toString(),
      baseFee: (json['baseFee'] as num).toDouble(),
      estimatedMinutes: (json['estimatedMinutes'] as num).toInt(),
    );
  }
}

class ApiClient {
  ApiClient._();
  static final Dio dio = CustomerApi.createDio(
    dio: Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      headers: {'Content-Type': 'application/json'},
    )),
  );

  static Future<void> authenticate({
    required bool register,
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
  }) async {
    final response = await dio.post(
      register ? '/auth/register' : '/auth/login',
      data: register
          ? {
              'email': email,
              'password': password,
              'firstName': firstName,
              'lastName': lastName,
            }
          : {'email': email, 'password': password},
    );
    await CustomerSession.saveTokens(
      accessToken: response.data['accessToken'] as String,
      refreshToken: response.data['refreshToken'] as String,
    );
  }

  static Future<String> readToken() async {
    final token = await _secureStorage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw StateError('Sign in is required to manage addresses or checkout.');
    }
    return token;
  }

  static Future<List<Address>> fetchAddresses() async {
    final token = await readToken();
    final response = await dio.get(
      '/addresses',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final items = (response.data['items'] as List? ?? []);
    return items
        .map((item) => Address.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<List<String>> fetchCities() async {
    final token = await readToken();
    final response = await dio.get(
      '/addresses/cities',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final items = response.data['items'] as List? ?? [];
    return items
        .map((item) => (item as Map<String, dynamic>)['name'].toString())
        .toList();
  }

  static Future<List<DeliveryZone>> fetchDeliveryZones(String city) async {
    final token = await readToken();
    final response = await dio.get(
      '/addresses/delivery-zones',
      queryParameters: {'city': city},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final items = response.data['items'] as List? ?? [];
    return items
        .map((item) => DeliveryZone.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveAddress(Map<String, dynamic> payload,
      {String? addressId}) async {
    final token = await readToken();
    final options = Options(headers: {'Authorization': 'Bearer $token'});
    if (addressId != null) {
      await dio.patch('/addresses/$addressId', data: payload, options: options);
    } else {
      await dio.post('/addresses', data: payload, options: options);
    }
  }

  static Future<CheckoutSummary> prepareCheckout({
    required String addressId,
    required String deliveryZoneId,
    required String deliveryOption,
    required String paymentMethod,
    String? promotionCode,
  }) async {
    final token = await readToken();
    final response = await dio.post(
      '/checkout/prepare',
      data: {
        'addressId': addressId,
        'deliveryZoneId': deliveryZoneId,
        'deliveryOption': deliveryOption,
        'paymentMethod': paymentMethod,
        if (promotionCode != null && promotionCode.trim().isNotEmpty)
          'promotionCode': promotionCode.trim(),
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return CheckoutSummary.fromJson(response.data);
  }

  static Future<OrderRecord> placeOrder(String checkoutId) async {
    final token = await readToken();
    final response = await dio.post(
      '/orders',
      data: {'checkoutId': checkoutId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return OrderRecord.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<List<OrderRecord>> fetchOrders(
      {int page = 1, int limit = 20}) async {
    final token = await readToken();
    final response = await dio.get(
      '/orders',
      queryParameters: {'page': page, 'limit': limit},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final items = response.data['items'] as List? ?? [];
    return items
        .map((item) => OrderRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> cancelOrder(String orderId) async {
    final token = await readToken();
    await dio.post(
      '/orders/$orderId/cancel',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  static Future<void> reorder(String orderId) async {
    final token = await readToken();
    await dio.post(
      '/orders/$orderId/reorder',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  static Future<PaymentIntent> createPaymentIntent({
    required String orderId,
    required String idempotencyKey,
  }) async {
    final token = await readToken();
    final response = await dio.post(
      '/payments/intents',
      data: {'orderId': orderId, 'idempotencyKey': idempotencyKey},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return PaymentIntent.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<DeliveryTracking> fetchDelivery(String orderId) async {
    final token = await readToken();
    final response = await dio.get(
      '/deliveries/orders/$orderId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return DeliveryTracking.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> submitProductReview({
    required String productId,
    required String orderId,
    required int rating,
    required String comment,
  }) async {
    final token = await readToken();
    await dio.post(
      '/catalog/products/$productId/reviews',
      data: {'orderId': orderId, 'rating': rating, 'comment': comment},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  static Future<List<CustomerNotification>> fetchNotifications(
      {int limit = 50}) async {
    final token = await readToken();
    final response = await dio.get(
      '/notifications',
      queryParameters: {'limit': limit},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final items = response.data['items'] as List? ?? [];
    return items
        .map((item) =>
            CustomerNotification.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> markNotificationRead(String id) async {
    final token = await readToken();
    await dio.patch(
      '/notifications/$id/read',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }
}

class AddressState {
  const AddressState({
    required this.items,
    required this.loading,
    required this.error,
  });

  final List<Address> items;
  final bool loading;
  final String? error;

  AddressState copyWith({
    List<Address>? items,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return AddressState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final addressProvider =
    StateNotifierProvider<AddressController, AddressState>((ref) {
  return AddressController();
});

class AddressController extends StateNotifier<AddressState> {
  AddressController()
      : super(const AddressState(items: [], loading: false, error: null));

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await ApiClient.fetchAddresses();
      state = state.copyWith(items: items, loading: false, clearError: true);
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> create(Map<String, dynamic> payload) async {
    try {
      await ApiClient.saveAddress(payload);
      await load();
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> update(Map<String, dynamic> payload, String id) async {
    try {
      await ApiClient.saveAddress(payload, addressId: id);
      await load();
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> remove(String id) async {
    final token = await ApiClient.readToken();
    try {
      await ApiClient.dio.delete(
        '/addresses/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      await load();
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
      rethrow;
    }
  }

  Future<void> setDefault(String id) async {
    try {
      final token = await ApiClient.readToken();
      await ApiClient.dio.post(
        '/addresses/$id/default',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      await load();
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
      rethrow;
    }
  }
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: CustomerSession.changes,
  redirect: (_, state) async {
    if (state.matchedLocation.startsWith('/admin')) {
      final hasAdminSession = await _adminApi.hasStoredSession();
      if (state.matchedLocation == '/admin/login' && hasAdminSession) {
        return '/admin';
      }
      if (state.matchedLocation == '/admin' && !hasAdminSession) {
        return '/admin/login';
      }
      return null;
    }
    final token = await _secureStorage.read(key: 'auth_token');
    final atLogin = state.matchedLocation == '/login';
    if ((token == null || token.isEmpty) && !atLogin) return '/login';
    if (token != null && token.isNotEmpty && atLogin) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: '/admin/login',
      builder: (_, __) => Theme(
        data: _adminTheme,
        child: AdminLoginScreen(
          api: _adminApi,
          onSignedIn: () => appRouter.go('/admin'),
        ),
      ),
    ),
    GoRoute(
      path: '/admin',
      builder: (_, __) => Theme(
        data: _adminTheme,
        child: AdminRouteGate(
          api: _adminApi,
          child: AdminHomeScreen(api: _adminApi),
        ),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          CustomerNavigationShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/categories',
              builder: (_, state) => CatalogScreen(
                initialCategoryId: state.extra as String?,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/favorites',
              builder: (_, __) => const FavoritesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const CustomerProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/catalog',
      redirect: (_, __) => '/categories',
    ),
    GoRoute(
      path: '/product/:productId',
      builder: (_, state) => ProductDetailScreen(
        productId: state.pathParameters['productId']!,
        initialProduct: state.extra as CatalogProduct?,
      ),
    ),
    GoRoute(
      path: '/addresses',
      builder: (_, __) => const AddressListScreen(),
    ),
    GoRoute(
      path: '/addresses/new',
      builder: (_, __) => const AddressEditorScreen(),
    ),
    GoRoute(
      path: '/addresses/:addressId/edit',
      builder: (_, state) =>
          AddressEditorScreen(address: state.extra as Address?),
    ),
    GoRoute(
      path: '/checkout',
      builder: (_, __) => const CheckoutScreen(),
    ),
    GoRoute(
      path: '/order-confirmation',
      builder: (_, state) {
        final order = state.extra;
        if (order is! OrderRecord) return const OrdersScreen();
        return OrderConfirmationScreen(order: order);
      },
    ),
    GoRoute(
      path: '/orders',
      builder: (_, __) => const OrdersScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (_, __) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/change-password',
      builder: (_, __) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (_, __) => const ForgotPasswordScreen(),
    ),
  ],
);

class AquaFlowApp extends ConsumerWidget {
  const AquaFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'AquaFlow',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      locale: ref.watch(appLocaleProvider),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AquaFlowCustomerTheme.theme,
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Dio _dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  List<CatalogCategory> _categories = [];
  List<CatalogProduct> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  Future<void> _loadHome() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait([
        _dio.get<Map<String, dynamic>>('/catalog/categories'),
        _dio.get<Map<String, dynamic>>(
          '/catalog/products',
          queryParameters: {'page': 1, 'limit': 8, 'sort': 'newest'},
        ),
      ]);
      if (!mounted) return;
      final categoryData = responses[0].data ?? {};
      final productData = responses[1].data ?? {};
      setState(() {
        _categories = (categoryData['items'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CatalogCategory.fromJson)
            .toList();
        _products = (productData['items'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CatalogProduct.fromJson)
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = localizedError(context, error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final productWidth = ((width - 44) / 2).clamp(132.0, 280.0);
    final discountedProducts = _products
        .where((product) =>
            product.compareAtPrice != null &&
            product.compareAtPrice! > product.price)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('AquaFlow'),
        actions: [
          const LanguageSwitch(compact: true),
          IconButton(
            tooltip: localized(context, 'Cart'),
            onPressed: () => context.go('/cart'),
            icon: const Icon(Icons.shopping_bag_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHome,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [Color(0xFF075C69), Color(0xFF0A8E91)],
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localized(context, 'Fresh water, delivered with care'),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localized(
                          context, 'Browse and add products to your cart'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                    ),
                    const SizedBox(height: 18),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.go('/catalog'),
                      child: IgnorePointer(
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText:
                                localized(context, 'Search AquaFlow products'),
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            SectionHeading(
              title: localized(context, 'Explore categories'),
              action: localized(context, 'Shop now'),
              onAction: () => context.go('/catalog'),
            ),
            const SizedBox(height: 10),
            if (_loading && _categories.isEmpty)
              const LinearProgressIndicator()
            else if (_categories.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories
                    .map(
                      (category) => ActionChip(
                        avatar: const Icon(Icons.water_drop_outlined, size: 18),
                        label: Text(category.displayName(
                          Localizations.localeOf(context).languageCode,
                        )),
                        onPressed: () => context.go(
                          '/catalog',
                          extra: category.id,
                        ),
                      ),
                    )
                    .toList(),
              ),
            if (discountedProducts.isNotEmpty) ...[
              const SizedBox(height: 24),
              SectionHeading(
                title: localized(context, 'Offers'),
                action: localized(context, 'Shop now'),
                onAction: () => context.go('/catalog'),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: discountedProducts
                    .map(
                      (product) => SizedBox(
                        width: productWidth,
                        child: CatalogProductCard(product: product),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
            SectionHeading(
              title: localized(context, 'Featured products'),
              action: localized(context, 'Shop now'),
              onAction: () => context.go('/catalog'),
            ),
            const SizedBox(height: 10),
            if (_loading && _products.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null && _products.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(_error!),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _loadHome,
                        child: Text(localized(context, 'Retry')),
                      ),
                    ],
                  ),
                ),
              )
            else if (_products.isEmpty)
              Text(localized(context, 'No products available right now.'))
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _products
                    .map(
                      (product) => SizedBox(
                        width: productWidth,
                        child: CatalogProductCard(product: product),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 24),
            SectionHeading(title: localized(context, 'More')),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _HomeAction(
                  width: productWidth,
                  icon: Icons.location_on_outlined,
                  title: localized(context, 'Addresses'),
                  onPressed: () => context.go('/addresses'),
                ),
                _HomeAction(
                  width: productWidth,
                  icon: Icons.receipt_long_outlined,
                  title: localized(context, 'Orders'),
                  onPressed: () => context.go('/orders'),
                ),
                _HomeAction(
                  width: productWidth,
                  icon: Icons.notifications_outlined,
                  title: localized(context, 'Notifications'),
                  onPressed: () => context.go('/notifications'),
                ),
                _HomeAction(
                  width: productWidth,
                  icon: Icons.shopping_cart_outlined,
                  title: localized(context, 'Cart'),
                  onPressed: () => context.go('/cart'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.width,
    required this.icon,
    required this.title,
    required this.onPressed,
  });

  final double width;
  final IconData icon;
  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _register = false;
  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiClient.authenticate(
        register: _register,
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
      if (mounted) context.go('/');
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = localizedError(context, error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AquaFlow'),
        actions: const [LanguageSwitch(compact: true)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Text(
                    localized(
                        context, _register ? 'Create account' : 'Sign in'),
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                if (_register) ...[
                  TextFormField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                        labelText: localized(context, 'First name')),
                    validator: (value) =>
                        _register && (value == null || value.trim().isEmpty)
                            ? localized(context, 'Enter your first name')
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                        labelText: localized(context, 'Last name')),
                    validator: (value) =>
                        _register && (value == null || value.trim().isEmpty)
                            ? localized(context, 'Enter your last name')
                            : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      InputDecoration(labelText: localized(context, 'Email')),
                  validator: (value) => value == null ||
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value.trim())
                      ? localized(context, 'Enter a valid email')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: localized(context, 'Password'),
                    suffixIcon: IconButton(
                      tooltip: localized(
                        context,
                        _showPassword ? 'Hide password' : 'Show password',
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return localized(context, 'Enter your password');
                    }
                    if (!_register) return null;
                    if (value.length < 8) {
                      return localized(
                        context,
                        'Password must be at least 8 characters',
                      );
                    }
                    if (!RegExp(
                      r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z\d]).+$',
                    ).hasMatch(value)) {
                      return localized(
                        context,
                        'Password must include a letter, number, and symbol',
                      );
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : Text(localized(
                          context, _register ? 'Create account' : 'Sign in')),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _register = !_register;
                            _error = null;
                          }),
                  child: Text(localized(
                      context,
                      _register
                          ? 'I already have an account'
                          : 'Create an account')),
                ),
                if (!_register)
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => context.push('/forgot-password'),
                    child: Text(localized(context, 'Forgot password?')),
                  ),
                if (!_register)
                  TextButton(
                    onPressed:
                        _loading ? null : () => context.go('/admin/login'),
                    child: Text(localized(context, 'Administrator sign in')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddressListScreen extends ConsumerStatefulWidget {
  const AddressListScreen({super.key});

  @override
  ConsumerState<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends ConsumerState<AddressListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(addressProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addressProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localized(context, 'Addresses')),
        actions: const [LanguageSwitch(compact: true)],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/addresses/new'),
        child: const Icon(Icons.add),
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(localizedError(context, state.error!)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            ref.read(addressProvider.notifier).load(),
                        child: Text(localized(context, 'Retry')),
                      ),
                    ],
                  ),
                )
              : state.items.isEmpty
                  ? Center(
                      child: Text(localized(context,
                          'No addresses yet. Add your first delivery address.')),
                    )
                  : ListView.builder(
                      itemCount: state.items.length,
                      itemBuilder: (_, index) {
                        final item = state.items[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: ListTile(
                            title: Text(item.label),
                            subtitle: Text(
                                '${item.recipientName}\n${item.city}, ${item.district}\n${item.street}, ${item.building}${item.apartment != null ? ' - ${localized(context, 'Apt {apartment}', {
                                        'apartment': item.apartment!
                                      })}' : ''}'),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                    value: 'edit',
                                    child: Text(localized(context, 'Edit'))),
                                PopupMenuItem(
                                    value: 'default',
                                    child: Text(
                                        localized(context, 'Set default'))),
                                PopupMenuItem(
                                    value: 'delete',
                                    child: Text(localized(context, 'Delete'))),
                              ],
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  context.push('/addresses/${item.id}/edit',
                                      extra: item);
                                }
                                if (value == 'default') {
                                  try {
                                    await ref
                                        .read(addressProvider.notifier)
                                        .setDefault(item.id);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(localized(context,
                                                'Could not update the default address.'))),
                                      );
                                    }
                                  }
                                }
                                if (value == 'delete') {
                                  try {
                                    await ref
                                        .read(addressProvider.notifier)
                                        .remove(item.id);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(localized(context,
                                                'Could not delete the address.'))),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class AddressEditorScreen extends ConsumerStatefulWidget {
  const AddressEditorScreen({this.address, this.initialCities, super.key});

  final Address? address;
  final List<String>? initialCities;

  @override
  ConsumerState<AddressEditorScreen> createState() =>
      _AddressEditorScreenState();
}

class _AddressEditorScreenState extends ConsumerState<AddressEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController(text: 'Home');
  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingController = TextEditingController();
  final _apartmentController = TextEditingController();
  final _floorController = TextEditingController();
  final _notesController = TextEditingController();
  List<String> _cities = [];
  bool _loadingCities = true;
  bool _saving = false;
  bool _isDefault = false;
  bool _localizedDefaultLabel = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final address = widget.address;
    if (address != null) {
      _labelController.text = address.label;
      _recipientController.text = address.recipientName;
      _phoneController.text = address.phone;
      _cityController.text = address.city;
      _districtController.text = address.district;
      _streetController.text = address.street;
      _buildingController.text = address.building;
      _apartmentController.text = address.apartment ?? '';
      _floorController.text = address.floor ?? '';
      _notesController.text = address.notes ?? '';
      _isDefault = address.isDefault;
    }
    if (widget.initialCities != null) {
      _cities = widget.initialCities!;
      _loadingCities = false;
    } else {
      _loadCities();
    }
  }

  Future<void> _loadCities() async {
    try {
      final cities = await ApiClient.fetchCities();
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _loadingCities = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCities = false;
        _error = error.toString();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_localizedDefaultLabel && widget.address == null) {
      _labelController.text = localized(context, 'Home');
      _localizedDefaultLabel = true;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _recipientController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _streetController.dispose();
    _buildingController.dispose();
    _apartmentController.dispose();
    _floorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(localized(
            context, widget.address == null ? 'Add address' : 'Edit address')),
        actions: const [LanguageSwitch(compact: true)],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loadingCities) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(localizedError(context, _error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              TextButton(
                  onPressed: _loadCities,
                  child: Text(localized(context, 'Retry'))),
            ],
            TextFormField(
              controller: _labelController,
              decoration:
                  InputDecoration(labelText: localized(context, 'Label')),
              validator: (value) => value == null || value.trim().isEmpty
                  ? localized(context, 'Enter a label')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _recipientController,
              decoration: InputDecoration(
                  labelText: localized(context, 'Recipient name')),
              validator: (value) => value == null || value.trim().isEmpty
                  ? localized(context, 'Enter a recipient name')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration:
                  InputDecoration(labelText: localized(context, 'Phone')),
              validator: (value) => value == null ||
                      !RegExp(r'^[+0-9\s-]{7,20}$').hasMatch(value.trim())
                  ? localized(context, 'Enter a valid phone number')
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _cities.contains(_cityController.text)
                  ? _cityController.text
                  : null,
              decoration:
                  InputDecoration(labelText: localized(context, 'City')),
              items: _cities
                  .map((city) =>
                      DropdownMenuItem(value: city, child: Text(city)))
                  .toList(),
              onChanged: (city) => _cityController.text = city ?? '',
              validator: (value) => value == null
                  ? localized(context, 'Select a configured city')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _districtController,
              decoration:
                  InputDecoration(labelText: localized(context, 'District')),
              validator: (value) => value == null || value.trim().isEmpty
                  ? localized(context, 'Enter a district')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _streetController,
              decoration:
                  InputDecoration(labelText: localized(context, 'Street')),
              validator: (value) => value == null || value.trim().isEmpty
                  ? localized(context, 'Enter a street')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _buildingController,
              decoration:
                  InputDecoration(labelText: localized(context, 'Building')),
              validator: (value) => value == null || value.trim().isEmpty
                  ? localized(context, 'Enter a building')
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: TextFormField(
                        controller: _apartmentController,
                        decoration: InputDecoration(
                            labelText: localized(context, 'Apartment')))),
                const SizedBox(width: 12),
                Expanded(
                    child: TextFormField(
                        controller: _floorController,
                        decoration: InputDecoration(
                            labelText: localized(context, 'Floor')))),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
                controller: _notesController,
                decoration:
                    InputDecoration(labelText: localized(context, 'Notes'))),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isDefault,
              onChanged: (value) => setState(() => _isDefault = value ?? false),
              title: Text(localized(context, 'Set as default address')),
            ),
            if (_error != null)
              Text(localizedError(context, _error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving || _loadingCities
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      setState(() {
                        _saving = true;
                        _error = null;
                      });
                      final payload = {
                        'label': _labelController.text.trim(),
                        'recipientName': _recipientController.text.trim(),
                        'phone': _phoneController.text.trim(),
                        'city': _cityController.text,
                        'district': _districtController.text.trim(),
                        'street': _streetController.text.trim(),
                        'building': _buildingController.text.trim(),
                        'apartment': _apartmentController.text.trim(),
                        'floor': _floorController.text.trim(),
                        'notes': _notesController.text.trim(),
                        'isDefault': _isDefault,
                      };
                      try {
                        if (widget.address == null) {
                          await ref
                              .read(addressProvider.notifier)
                              .create(payload);
                        } else {
                          await ref
                              .read(addressProvider.notifier)
                              .update(payload, widget.address!.id);
                        }
                        if (context.mounted) context.pop();
                      } catch (error) {
                        if (mounted) {
                          setState(() {
                            _saving = false;
                            _error = error.toString();
                          });
                        }
                      }
                    },
              child: _saving
                  ? const CircularProgressIndicator()
                  : Text(localized(context, 'Save address')),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String deliveryOption = 'standard';
  String paymentMethod = 'card';
  String promotionCode = '';
  bool loading = true;
  bool loadingZones = false;
  int _zoneRequestId = 0;
  CheckoutSummary? summary;
  List<DeliveryZone> zones = [];
  String? selectedAddressId;
  String? selectedZoneId;
  String? error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCheckoutData);
  }

  Future<void> _loadCheckoutData() async {
    setState(() {
      loading = true;
      error = null;
    });
    await ref.read(addressProvider.notifier).load();
    final addressState = ref.read(addressProvider);
    if (addressState.error != null) {
      if (mounted) {
        setState(() {
          loading = false;
          error = localizedError(context, addressState.error!);
        });
      }
      return;
    }
    final addresses = addressState.items;
    if (addresses.isEmpty) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
      return;
    }
    final selected = addresses.firstWhere(
      (address) => address.isDefault,
      orElse: () => addresses.first,
    );
    selectedAddressId = selected.id;
    await _loadZones(selected.city);
    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _loadZones(String city) async {
    final requestId = ++_zoneRequestId;
    setState(() {
      loadingZones = true;
      zones = [];
      selectedZoneId = null;
      summary = null;
      error = null;
    });
    try {
      final result = await ApiClient.fetchDeliveryZones(city);
      if (!mounted || requestId != _zoneRequestId) return;
      setState(() {
        zones = result;
        selectedZoneId = result.isEmpty ? null : result.first.id;
        loadingZones = false;
        error = result.isEmpty
            ? localized(context, 'No delivery zones are configured for {city}.',
                {'city': city})
            : null;
      });
    } catch (exception) {
      if (mounted && requestId == _zoneRequestId) {
        setState(() {
          zones = [];
          selectedZoneId = null;
          loadingZones = false;
          error = localizedError(context, exception);
        });
      }
    }
  }

  Future<void> prepareCheckout() async {
    final addresses = ref.read(addressProvider).items;
    final selectedAddress = _findAddress(addresses, selectedAddressId);
    if (selectedAddress == null || selectedZoneId == null) {
      setState(() {
        error = localized(
            context, 'Select a delivery address and zone before continuing.');
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await ApiClient.prepareCheckout(
        addressId: selectedAddress.id,
        deliveryZoneId: selectedZoneId!,
        deliveryOption: deliveryOption,
        paymentMethod: paymentMethod,
        promotionCode: promotionCode,
      );
      if (mounted) {
        setState(() {
          summary = response;
          loading = false;
        });
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          summary = null;
          loading = false;
          error = localizedError(context, exception);
        });
      }
    }
  }

  Future<void> placeOrder() async {
    if (loading) return;
    final checkoutId = summary?.checkoutId;
    if (checkoutId == null || checkoutId.isEmpty) {
      setState(() {
        error = localized(
            context, 'Review your checkout before placing the order.');
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final order = await ApiClient.placeOrder(checkoutId);
      if (mounted) {
        context.go('/order-confirmation', extra: order);
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          loading = false;
          error = localizedError(context, exception);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressProvider).items;

    return Scaffold(
      appBar: AppBar(
        title: Text(localized(context, 'Checkout')),
        actions: const [LanguageSwitch(compact: true)],
      ),
      body: loading && addresses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(localized(context, 'Delivery address'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (addresses.isEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(localized(context, 'No saved addresses.')),
                      TextButton.icon(
                        onPressed: () async {
                          await context.push('/addresses/new');
                          await _loadCheckoutData();
                        },
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: Text(localized(context, 'Add address')),
                      ),
                    ],
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: selectedAddressId,
                    decoration: InputDecoration(
                        labelText: localized(context, 'Choose an address')),
                    items: addresses
                        .map((address) => DropdownMenuItem(
                              value: address.id,
                              child: Text(
                                  '${address.label} · ${address.city}, ${address.street}',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (id) {
                      final address = _findAddress(addresses, id);
                      setState(() {
                        selectedAddressId = id;
                        selectedZoneId = null;
                        zones = [];
                        summary = null;
                      });
                      if (address != null) _loadZones(address.city);
                    },
                  ),
                if (loadingZones)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 20),
                Text(localized(context, 'Delivery zone'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: zones.any((zone) => zone.id == selectedZoneId)
                      ? selectedZoneId
                      : null,
                  decoration: InputDecoration(
                      labelText: localized(context, 'Choose a delivery zone')),
                  items: zones
                      .map((zone) => DropdownMenuItem(
                            value: zone.id,
                            child: Text(
                                '${zone.name} · ${localized(context, '{minutes} minutes', {
                                  'minutes': zone.estimatedMinutes
                                })}'),
                          ))
                      .toList(),
                  onChanged: loadingZones
                      ? null
                      : (id) => setState(() {
                            selectedZoneId = id;
                            summary = null;
                          }),
                ),
                const SizedBox(height: 20),
                Text(localized(context, 'Delivery option'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'standard',
                        label: Text(localized(context, 'Standard'))),
                    ButtonSegment(
                        value: 'express',
                        label: Text(localized(context, 'Express'))),
                  ],
                  selected: {deliveryOption},
                  onSelectionChanged: (value) => setState(() {
                    deliveryOption = value.first;
                    summary = null;
                  }),
                ),
                const SizedBox(height: 20),
                Text(localized(context, 'Payment method'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'card', label: Text(localized(context, 'Card'))),
                    ButtonSegment(
                        value: 'cash', label: Text(localized(context, 'Cash'))),
                  ],
                  selected: {paymentMethod},
                  onSelectionChanged: (value) => setState(() {
                    paymentMethod = value.first;
                    summary = null;
                  }),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: promotionCode,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: localized(context, 'Promotion code (optional)'),
                  ),
                  onChanged: (value) {
                    promotionCode = value;
                    if (summary != null) setState(() => summary = null);
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  TextButton.icon(
                      onPressed: _loadCheckoutData,
                      icon: const Icon(Icons.refresh),
                      label: Text(localized(context, 'Retry'))),
                ],
                if (summary != null) ...[
                  if (paymentMethod == 'card') ...[
                    const SizedBox(height: 12),
                    Text(
                      localized(context,
                          'Card payment processing is not available yet. The order will remain payment pending.'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(localized(context, 'Subtotal')),
                                Text(
                                    '${summary!.currency} ${summary!.subtotal.toStringAsFixed(2)}')
                              ]),
                          if (summary!.discount > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      '${localized(context, 'Promotion')}${summary!.promotionCode == null ? '' : ' (${summary!.promotionCode})'}'),
                                  Text(
                                      '-${summary!.currency} ${summary!.discount.toStringAsFixed(2)}')
                                ]),
                          ],
                          const SizedBox(height: 8),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(localized(context, 'Delivery')),
                                Text(
                                    '${summary!.currency} ${summary!.deliveryFee.toStringAsFixed(2)}')
                              ]),
                          const SizedBox(height: 8),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(localized(context, 'Service fee')),
                                Text(
                                    '${summary!.currency} ${summary!.serviceFee.toStringAsFixed(2)}')
                              ]),
                          const Divider(),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(localized(context, 'Total'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    '${summary!.currency} ${summary!.total.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))
                              ]),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading ||
                            loadingZones ||
                            addresses.isEmpty ||
                            zones.isEmpty
                        ? null
                        : summary == null
                            ? prepareCheckout
                            : placeOrder,
                    child: loading
                        ? const CircularProgressIndicator()
                        : Text(localized(context,
                            summary == null ? 'Review order' : 'Place order')),
                  ),
                ),
              ],
            ),
    );
  }
}

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({required this.order, super.key});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) => PopScope<void>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go('/orders');
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(localized(context, 'Order received')),
            actions: const [LanguageSwitch(compact: true)],
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 72,
                color: Color(0xFF0E9F6E),
              ),
              const SizedBox(height: 16),
              Text(
                localized(context, 'Your order was received.'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${localized(context, 'Order number')}: ${order.id}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${localized(context, 'Order status')}: '
                        '${localizedStatus(context, order.status)}',
                      ),
                      if (order.deliveryStatus != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${localized(context, 'Delivery status')}: '
                          '${localizedStatus(context, order.deliveryStatus!)}',
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${localized(context, 'Order total')}: '
                        '${order.currency} ${order.total.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/orders'),
                child: Text(localized(context, 'View my orders')),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.go('/'),
                child: Text(localized(context, 'Go to home')),
              ),
            ],
          ),
        ),
      );
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<OrderRecord> orders = [];
  final Set<String> _startingPayments = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await ApiClient.fetchOrders();
      if (mounted) {
        setState(() {
          orders = result;
          loading = false;
        });
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          loading = false;
          error = exception.toString();
        });
      }
    }
  }

  Future<void> _cancelOrder(OrderRecord order) async {
    try {
      await ApiClient.cancelOrder(order.id);
      await _loadOrders();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedError(context, exception))),
        );
      }
    }
  }

  Future<void> _reorder(OrderRecord order) async {
    try {
      await ApiClient.reorder(order.id);
      if (mounted) context.go('/cart');
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedError(context, exception))),
        );
      }
    }
  }

  Future<void> _startPayment(OrderRecord order) async {
    if (_startingPayments.contains(order.id)) return;
    setState(() => _startingPayments.add(order.id));
    try {
      final intent = await ApiClient.createPaymentIntent(
        orderId: order.id,
        idempotencyKey: '${order.id}-mobile-attempt-1',
      );
      await _loadOrders();
      if (!mounted) return;
      final message = intent.checkoutUrl == null
          ? localized(
              context,
              'Payment intent created by {provider}; no payment was taken and no provider checkout is configured.',
              {
                  'provider': intent.provider
                })
          : localized(context,
              'Payment intent created. Continue through the provider checkout.');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(localized(
                  context,
                  'Payment could not be started: {error}',
                  {'error': exception}))),
        );
      }
    } finally {
      if (mounted) setState(() => _startingPayments.remove(order.id));
    }
  }

  Future<void> _showDelivery(OrderRecord order) async {
    try {
      final delivery = await ApiClient.fetchDelivery(order.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    localized(context, 'Delivery {status}',
                        {'status': localizedStatus(context, delivery.status)}),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(localized(context, 'Tracking code: {code}',
                    {'code': delivery.trackingCode})),
                Text(localized(context, 'Estimated time: {minutes} minutes',
                    {'minutes': delivery.estimatedMinutes})),
                const SizedBox(height: 12),
                if (!delivery.trackingAvailable)
                  Text(localized(
                      context, 'Live driver tracking is not available yet.')),
                ...delivery.events.map((event) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(localized(context, event)),
                    )),
              ],
            ),
          ),
        ),
      );
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(localized(
                  context,
                  'Delivery information is unavailable: {error}',
                  {'error': exception}))),
        );
      }
    }
  }

  Future<void> _reviewOrder(OrderRecord order) async {
    if (order.items.isEmpty) return;
    final commentController = TextEditingController();
    var productId = order.items.first.productId;
    var rating = 5;
    try {
      final review = await showDialog<Map<String, Object>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(localized(context, 'Review a delivered product')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: productId,
                  items: order.items
                      .map((item) => DropdownMenuItem(
                            value: item.productId,
                            child: Text(item.name,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => productId = value ?? productId),
                ),
                Text(localized(
                    context, 'Rating: {rating} / 5', {'rating': rating})),
                Slider(
                  value: rating.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$rating',
                  onChanged: (value) =>
                      setDialogState(() => rating = value.round()),
                ),
                TextField(
                  controller: commentController,
                  maxLength: 1000,
                  decoration: InputDecoration(
                      labelText: localized(context, 'Comment (optional)')),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(localized(context, 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, {
                  'productId': productId,
                  'rating': rating,
                  'comment': commentController.text,
                }),
                child: Text(localized(context, 'Submit')),
              ),
            ],
          ),
        ),
      );
      if (review == null) return;
      await ApiClient.submitProductReview(
        productId: review['productId']! as String,
        orderId: order.id,
        rating: review['rating']! as int,
        comment: review['comment']! as String,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(localized(context, 'Review submitted for moderation.'))),
        );
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(localized(
                  context,
                  'Review could not be submitted: {error}',
                  {'error': exception}))),
        );
      }
    } finally {
      commentController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(localized(context, 'Orders')),
        actions: [
          IconButton(
            tooltip: localized(context, 'Go to home'),
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_outlined),
          ),
          const LanguageSwitch(compact: true),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(localizedError(context, error!)),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _loadOrders,
                          child: Text(localized(context, 'Retry'))),
                    ],
                  ),
                )
              : orders.isEmpty
                  ? Center(
                      child:
                          Text(localized(context, 'You have no orders yet.')))
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final canCancel = order.status == 'placed' ||
                              order.status == 'payment_pending';
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(localized(context, 'Order {id}',
                                          {'id': order.id.substring(0, 8)})),
                                      Chip(
                                          label: Text(localizedStatus(
                                              context,
                                              customerOrderDisplayStatus(
                                                  order)))),
                                    ],
                                  ),
                                  Text(
                                      '${order.address.label} · ${order.address.city}'),
                                  const SizedBox(height: 8),
                                  ...order.items.map((item) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: Text(
                                          '${item.quantity} × ${Localizations.localeOf(context).languageCode == 'ar' && item.nameAr?.isNotEmpty == true ? item.nameAr : item.name}',
                                        ),
                                      )),
                                  const Divider(),
                                  Text(
                                    '${order.currency} ${order.total.toStringAsFixed(2)}',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  if (order.status == 'payment_pending')
                                    Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(localized(context,
                                          'Payment has not been processed.')),
                                    ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _reorder(order),
                                        icon: const Icon(Icons.replay),
                                        label:
                                            Text(localized(context, 'Reorder')),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => _showDelivery(order),
                                        icon: const Icon(
                                            Icons.local_shipping_outlined),
                                        label: Text(
                                            localized(context, 'Delivery')),
                                      ),
                                      if (order.deliveryStatus == 'delivered')
                                        OutlinedButton.icon(
                                          onPressed: () => _reviewOrder(order),
                                          icon: const Icon(Icons.star_outline),
                                          label: Text(localized(
                                              context, 'Review product')),
                                        ),
                                      if (canCancel &&
                                          order.paymentStatus != 'pending')
                                        TextButton.icon(
                                          onPressed: () => _cancelOrder(order),
                                          icon:
                                              const Icon(Icons.cancel_outlined),
                                          label: Text(
                                              localized(context, 'Cancel')),
                                        ),
                                      if (order.status == 'payment_pending' &&
                                          order.paymentMethod == 'card') ...[
                                        if (order.paymentStatus == 'pending')
                                          Chip(
                                              label: Text(localized(context,
                                                  'Payment in progress')))
                                        else
                                          FilledButton.tonal(
                                            onPressed: _startingPayments
                                                    .contains(order.id)
                                                ? null
                                                : () => _startPayment(order),
                                            child: Text(_startingPayments
                                                    .contains(order.id)
                                                ? localized(
                                                    context, 'Starting...')
                                                : localized(
                                                    context, 'Start payment')),
                                          ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<CustomerNotification> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await ApiClient.fetchNotifications();
      if (mounted) {
        setState(() {
          items = result;
          loading = false;
        });
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = exception.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> _markRead(CustomerNotification notification) async {
    try {
      await ApiClient.markNotificationRead(notification.id);
      await _load();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(localized(
                  context,
                  'Could not update notification: {error}',
                  {'error': exception}))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(localized(context, 'Notifications')),
        actions: const [LanguageSwitch(compact: true)],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(localizedError(context, error!)),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _load,
                          child: Text(localized(context, 'Retry'))),
                    ],
                  ),
                )
              : items.isEmpty
                  ? Center(
                      child: Text(localized(context, 'No notifications yet.')))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            leading: Icon(item.isRead
                                ? Icons.notifications_none
                                : Icons.notifications_active_outlined),
                            title: Text(localized(context, item.title)),
                            subtitle: Text(localized(context, item.body)),
                            trailing: item.isRead
                                ? null
                                : IconButton(
                                    tooltip: localized(context, 'Mark as read'),
                                    onPressed: () => _markRead(item),
                                    icon: const Icon(Icons.done),
                                  ),
                          );
                        },
                      ),
                    ),
    );
  }
}
