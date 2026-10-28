import 'package:aquaflow_mobile/main.dart';
import 'package:aquaflow_mobile/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
      'order confirmation offers orders and home without reopening checkout',
      (tester) async {
    final router = _confirmationRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appLocaleProvider.overrideWith(
          (ref) => AppLocaleController(store: _MemoryLocaleStore()),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Your order was received.'), findsOneWidget);
    expect(find.textContaining('Order status: Placed'), findsOneWidget);
    expect(find.textContaining('Delivery status: Pending dispatch'),
        findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Orders destination'), findsOneWidget);
  });

  testWidgets('order confirmation home action opens the customer home',
      (tester) async {
    final router = _confirmationRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appLocaleProvider.overrideWith(
          (ref) => AppLocaleController(store: _MemoryLocaleStore()),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Go to home'));
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
  });

  testWidgets('address editor validates required fields before submitting',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child:
            MaterialApp(home: AddressEditorScreen(initialCities: ['Riyadh'])),
      ),
    );
    await tester.pump();

    expect(find.text('Save address'), findsOneWidget);
    await tester.tap(find.text('Save address'));
    await tester.pump();

    expect(find.text('Enter a recipient name'), findsOneWidget);
    expect(find.text('Enter a valid phone number'), findsOneWidget);
    expect(find.text('Select a configured city'), findsOneWidget);
  });

  testWidgets('checkout does not display fabricated totals without server data',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CheckoutScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Checkout'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('SAR 51.50'), findsNothing);
  });
}

GoRouter _confirmationRouter() => GoRouter(
      initialLocation: '/order-confirmation',
      routes: [
        GoRoute(
          path: '/order-confirmation',
          builder: (_, __) => OrderConfirmationScreen(order: _confirmedOrder()),
        ),
        GoRoute(
          path: '/orders',
          builder: (_, __) => const Scaffold(
            body: Text('Orders destination'),
          ),
        ),
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: Text('Home destination'),
          ),
        ),
      ],
    );

OrderRecord _confirmedOrder() => OrderRecord(
      id: 'order-12345678',
      status: 'placed',
      paymentMethod: 'cash',
      deliveryStatus: 'pending_dispatch',
      deliveryOption: 'standard',
      address: const Address(
        id: 'address-1',
        label: 'Home',
        recipientName: 'Customer',
        phone: '+966500000000',
        city: 'Riyadh',
        district: 'Central',
        street: 'Water street',
        building: '1',
      ),
      items: const [],
      total: 17,
      currency: 'SAR',
      createdAt: DateTime.utc(2026, 10, 28),
    );

class _MemoryLocaleStore implements LocalePreferenceStore {
  @override
  Future<String?> read() async => 'en';

  @override
  Future<void> write(String languageCode) async {}
}
