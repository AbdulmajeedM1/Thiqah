import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_app/main.dart';
import 'package:trust_app/src/help_screen.dart';
import 'package:trust_app/src/store.dart';

void main() {
  for (final english in [false, true]) {
    testWidgets('home help opens and answers FAQs, English=$english', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = TrustStore(memoryOnly: true)..seed();
      store.entered = true;
      store.english = english;
      store.provider = english;
      store.darkMode = english;
      await tester.pumpWidget(TrustApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-help')));
      await tester.pumpAndSettle();
      expect(find.byType(HelpScreen), findsOneWidget);
      expect(
        find.text(english ? 'Provider guide' : 'دليل العميل'),
        findsOneWidget,
      );
      final question = find.text(
        english
            ? 'Are payments and withdrawals real?'
            : 'هل الدفع والسحب حقيقيان؟',
      );
      await tester.scrollUntilVisible(question.hitTestable(), 200);
      await tester.tap(question);
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          english ? 'No money is transferred.' : 'ولا يتم تحويل أي أموال',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-help')), findsOneWidget);
    });
  }
}
