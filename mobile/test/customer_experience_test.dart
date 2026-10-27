import 'package:aquaflow_mobile/cart_screen.dart';
import 'package:aquaflow_mobile/customer_ui.dart';
import 'package:aquaflow_mobile/catalog_screen.dart';
import 'package:aquaflow_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('customer registration enforces backend password rules locally',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalWidgetsLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const LoginScreen(),
        ),
      ),
    );

    await tester.tap(find.text('إنشاء حساب'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(2), 'customer@example.com');
    await tester.enterText(fields.at(3), 'weakpass');
    await tester.tap(find.widgetWithText(FilledButton, 'إنشاء حساب'));
    await tester.pumpAndSettle();

    expect(
      find.text('يجب أن تحتوي كلمة المرور على حرف ورقم ورمز'),
      findsOneWidget,
    );
  });

  testWidgets('customer registration distinguishes short passwords',
      (tester) async {
    await tester.pumpWidget(_loginApp());

    await tester.tap(find.text('إنشاء حساب'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(2), 'customer@example.com');
    await tester.enterText(fields.at(3), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'إنشاء حساب'));
    await tester.pumpAndSettle();

    expect(find.text('يجب ألا تقل كلمة المرور عن 8 أحرف'), findsOneWidget);
  });

  testWidgets('customer registration rejects invalid email locally',
      (tester) async {
    await tester.pumpWidget(_loginApp());

    await tester.tap(find.text('إنشاء حساب'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(2), 'not-an-email');
    await tester.enterText(fields.at(3), 'StrongPass123!');
    await tester.tap(find.widgetWithText(FilledButton, 'إنشاء حساب'));
    await tester.pumpAndSettle();

    expect(find.text('أدخل بريداً إلكترونياً صحيحاً'), findsOneWidget);
  });

  testWidgets('catalog product card fits a narrow Arabic viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalWidgetsLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AquaFlowCustomerTheme.theme,
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(
                  width: 136,
                  child: CatalogProductCard(
                    product: CatalogProduct(
                      id: 'product-1',
                      name: 'AquaFlow Mineral Water',
                      nameAr: 'مياه أكوافلو المعدنية',
                      price: 4.5,
                      quantity: 8,
                      availability: 'in_stock',
                      imageUrl: null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مياه أكوافلو المعدنية'), findsOneWidget);
    expect(find.text('أضف إلى السلة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cart is readable and does not overflow on a narrow RTL screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_cartApp(
      locale: const Locale('ar'),
      controller: _MemoryCartController(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('السلة'), findsOneWidget);
    expect(find.text('مياه أكوافلو المعدنية'), findsOneWidget);
    expect(find.text('-SAR 1.50'), findsOneWidget);
    expect(find.text('SAR 10.50'), findsNWidgets(2));
    expect(
      Directionality.of(
          tester.element(find.byKey(const Key('cart-quantity-prod-1')))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cart quantity controls update displayed quantity and totals',
      (tester) async {
    final controller = _MemoryCartController();
    await tester.pumpWidget(_cartApp(
      locale: const Locale('en'),
      controller: controller,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cart-increase-prod-1')));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('SAR 15.75'), findsNWidgets(2));
    expect(find.text('SAR 18.00'), findsOneWidget);
    expect(find.text('-SAR 2.25'), findsOneWidget);
    expect(controller.lastUpdatedQuantity, 3);

    await tester.tap(find.byKey(const Key('cart-decrease-prod-1')));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(controller.lastUpdatedQuantity, 2);
  });

  testWidgets('cart checkout action remains reachable with a keyboard inset',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(_cartApp(
      locale: const Locale('en'),
      controller: _MemoryCartController(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Proceed to checkout'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _loginApp() => ProviderScope(
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const LoginScreen(),
      ),
    );

Widget _cartApp({
  required Locale locale,
  required CartController controller,
}) {
  return ProviderScope(
    overrides: [
      cartProvider.overrideWith((ref) => controller),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AquaFlowCustomerTheme.theme,
      home: const CartScreen(autoLoad: false),
    ),
  );
}

class _MemoryCartController extends CartController {
  _MemoryCartController()
      : super(
          initialState: const CartState(
            items: [
              CartItem(
                productId: 'prod-1',
                name: 'AquaFlow Mineral Water',
                nameAr: 'مياه أكوافلو المعدنية',
                quantity: 2,
                unitPrice: 5.25,
                compareAtPrice: 6,
              ),
            ],
            subtotal: 12,
            discount: 1.5,
            total: 10.5,
            loading: false,
            error: null,
          ),
        );

  int? lastUpdatedQuantity;

  @override
  Future<void> updateItemQuantity(String productId, int quantity) async {
    lastUpdatedQuantity = quantity;
    const unitPrice = 5.25;
    const compareAtPrice = 6.0;
    final lineTotal = unitPrice * quantity;
    final discount = (compareAtPrice - unitPrice) * quantity;
    state = CartState(
      items: [
        CartItem(
          productId: productId,
          name: 'AquaFlow Mineral Water',
          nameAr: 'مياه أكوافلو المعدنية',
          quantity: quantity,
          unitPrice: unitPrice,
          compareAtPrice: compareAtPrice,
        ),
      ],
      subtotal: lineTotal + discount,
      discount: discount,
      total: lineTotal,
      loading: false,
      error: null,
    );
  }
}
