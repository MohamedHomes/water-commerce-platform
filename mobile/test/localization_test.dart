import 'package:aquaflow_mobile/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restores and persists language preference', () async {
    final store = _MemoryLocalePreferenceStore('ar');
    final controller = AppLocaleController(store: store);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state, const Locale('ar'));
    await controller.toggle();
    expect(controller.state, const Locale('en'));
    expect(store.savedLanguage, 'en');
    controller.dispose();
  });

  testWidgets('Arabic app locale translates copy and applies RTL direction',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: [Locale('en'), Locale('ar')],
        localizationsDelegates: [
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: _LocalizedProbe(),
      ),
    );

    expect(find.text('السلة'), findsOneWidget);
    expect(find.text('المتابعة لإتمام الطلب'), findsOneWidget);
    expect(tester.widget<Directionality>(find.byType(Directionality).first).textDirection,
        TextDirection.rtl);
  });

  testWidgets('English app locale remains LTR', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: [Locale('en'), Locale('ar')],
        localizationsDelegates: [
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: _LocalizedProbe(),
      ),
    );

    expect(find.text('Cart'), findsOneWidget);
    expect(tester.widget<Directionality>(find.byType(Directionality).first).textDirection,
        TextDirection.ltr);
  });
}

class _LocalizedProbe extends StatelessWidget {
  const _LocalizedProbe();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(localized(context, 'Cart')),
        Text(localized(context, 'Proceed to checkout')),
      ],
    );
  }
}

class _MemoryLocalePreferenceStore implements LocalePreferenceStore {
  _MemoryLocalePreferenceStore(this.savedLanguage);

  String? savedLanguage;

  @override
  Future<String?> read() async => savedLanguage;

  @override
  Future<void> write(String languageCode) async {
    savedLanguage = languageCode;
  }
}
