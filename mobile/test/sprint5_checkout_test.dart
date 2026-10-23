import 'package:aquaflow_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('address editor validates required fields before submitting', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AddressEditorScreen(initialCities: ['Riyadh'])),
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

  testWidgets('checkout does not display fabricated totals without server data', (tester) async {
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