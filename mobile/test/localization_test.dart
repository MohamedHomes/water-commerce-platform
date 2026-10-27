import 'dart:io';

import 'package:aquaflow_mobile/localization.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile localization catalog has unique keys and covers every call site',
      () {
    final catalog = File('lib/localization.dart').readAsStringSync();
    final appSource = [
      File('lib/main.dart').readAsStringSync(),
      File('lib/cart_screen.dart').readAsStringSync(),
      File('lib/catalog_screen.dart').readAsStringSync(),
    ].join('\n');
    final catalogBlock = RegExp(
      r'const _translations = <String, String>\{([\s\S]*?)\n\};',
    ).firstMatch(catalog)!.group(1)!;
    final keyPattern = RegExp(r"^\s*'((?:\\.|[^'])*)'\s*:", multiLine: true);
    final keys = keyPattern
        .allMatches(catalogBlock)
        .map((match) => match.group(1)!)
        .toList();
    final callPattern = RegExp(r"localized\(context,\s*'((?:\\.|[^'])*)'");
    final usedKeys = callPattern
        .allMatches(appSource)
        .map((match) => match.group(1)!)
        .toSet();

    expect(keys.toSet().length, keys.length,
        reason: 'Duplicate Arabic catalog keys');
    expect(usedKeys.difference(keys.toSet()), isEmpty,
        reason: 'Every literal localized(...) key needs an Arabic translation');
  });

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
    expect(
        tester
            .widget<Directionality>(find.byType(Directionality).first)
            .textDirection,
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
    expect(
        tester
            .widget<Directionality>(find.byType(Directionality).first)
            .textDirection,
        TextDirection.ltr);
  });

  testWidgets('language switch label names the alternate language',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: LanguageSwitch()),
      ),
    ));

    expect(find.text('التبديل إلى الإنجليزية'), findsOneWidget);
  });

  testWidgets('known rate limit errors are localized', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: [Locale('en'), Locale('ar')],
        localizationsDelegates: [
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: _RateLimitErrorProbe(),
      ),
    );

    expect(
        find.text('طلبات كثيرة جداً. يرجى المحاولة لاحقاً.'), findsOneWidget);
  });

  testWidgets(
      'registration backend validation arrays show specific Arabic errors',
      (tester) async {
    final request = RequestOptions(path: '/auth/register');
    final error = DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: 400,
        data: {
          'message': [
            'email must be an email',
            'Password must include a letter, number, and symbol',
          ],
        },
      ),
    );

    await tester.pumpWidget(_errorApp(error));

    expect(
        find.text('أدخل بريداً إلكترونياً صحيحاً\n'
            'يجب أن تحتوي كلمة المرور على حرف ورقم ورمز'),
        findsOneWidget);
  });

  testWidgets('duplicate registration receives a specific Arabic message',
      (tester) async {
    final request = RequestOptions(path: '/auth/register');
    final error = DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: 400,
        data: {'message': 'Customer with this email already exists'},
      ),
    );

    await tester.pumpWidget(_errorApp(error));

    expect(find.text('يوجد حساب مسجل بهذا البريد الإلكتروني'), findsOneWidget);
  });

  testWidgets('network and server failures do not expose internal details',
      (tester) async {
    final request = RequestOptions(path: '/auth/register');
    final networkError = DioException(
      requestOptions: request,
      type: DioExceptionType.connectionTimeout,
    );
    await tester.pumpWidget(_errorApp(networkError));
    expect(
        find.text('تعذر الاتصال بخادم أكوافلو. تحقق من رابط الخادم '
            'والاتصال بالشبكة.'),
        findsOneWidget);

    final serverError = DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: 500,
        data: {'message': 'sensitive internal exception'},
      ),
    );
    await tester.pumpWidget(_errorApp(serverError));
    expect(find.text('الخادم غير متاح مؤقتاً. يرجى المحاولة لاحقاً.'),
        findsOneWidget);
    expect(find.text('sensitive internal exception'), findsNothing);
  });
}

Widget _errorApp(Object error) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: Text(localizedError(context, error)),
        ),
      ),
    );

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

class _RateLimitErrorProbe extends StatelessWidget {
  const _RateLimitErrorProbe();

  @override
  Widget build(BuildContext context) {
    return Text(localizedError(context, Exception('Too many requests')));
  }
}
