import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_app/main.dart';
import 'package:trust_app/src/store.dart';

void main() {
  testWidgets('customer can publish a validated request with authorization', (
    tester,
  ) async {
    final store = TrustStore(memoryOnly: true)..seed();
    store.entered = true;
    store.english = true;
    await tester.pumpWidget(TrustApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New request'));
    await tester.pumpAndSettle();
    Future<void> fill(String label, String value) async {
      final field = find.widgetWithText(TextFormField, label);
      await tester.scrollUntilVisible(
        field,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(field, value);
    }

    await fill('Request title', 'Renew residency permit');
    await fill(
      'Description',
      'Please renew the residency permit and provide the receipt.',
    );
    await fill('City', 'Riyadh');
    await fill('Expected budget', '300');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(CheckboxListTile),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.scrollUntilVisible(
      find.text('Publish request'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish request'));
    await tester.pumpAndSettle();
    expect(store.requests.first.title, 'Renew residency permit');
    expect(store.requests.first.stage, Stage.open);
    expect(store.requests.first.consent, isTrue);
    expect(store.requests.first.budget, 30000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic welcome, home, navigation and English switching', (
    tester,
  ) async {
    final store = TrustStore(memoryOnly: true)..seed();
    await tester.pumpWidget(TrustApp(store: store));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ابدأ كعميل'), 200);
    expect(find.text('ابدأ كعميل'), findsOneWidget);
    await tester.tap(find.text('ابدأ كعميل'));
    await tester.pumpAndSettle();
    expect(find.text('معاملاتك أسهل مع ثقة.'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('معاملاتك أسهل مع ثقة.'))),
      TextDirection.rtl,
    );
    await tester.tap(find.text('طلباتي').last);
    await tester.pumpAndSettle();
    expect(find.text('تجديد السجل التجاري'), findsOneWidget);
    await tester.tap(find.text('تجديد السجل التجاري'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل الطلب'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    store.english = true;
    await store.save();
    await tester.pumpAndSettle();
    expect(find.text('My requests'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Small phone customer and provider screens do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = TrustStore(memoryOnly: true)..seed();
    store.entered = true;
    await tester.pumpWidget(TrustApp(store: store));
    for (final language in [false, true]) {
      store.english = language;
      await store.save();
      await tester.pumpAndSettle();
      for (final role in [false, true]) {
        store.provider = role;
        await store.save();
        await tester.pumpAndSettle();
        for (final index in [0, 1, 2, 3]) {
          final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
          bar.onDestinationSelected!(index);
          await tester.pumpAndSettle();
          final error = tester.takeException();
          expect(
            error,
            isNull,
            reason: 'language=$language provider=$role tab=$index',
          );
        }
      }
    }
  });
}
