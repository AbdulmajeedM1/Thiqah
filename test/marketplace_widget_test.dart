import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_app/main.dart';
import 'package:trust_app/src/store.dart';

import 'marketplace_test.dart' show request, signIn;

void main() {
  testWidgets(
    'provider discovers a customer request and the submitted offer returns to the customer',
    (tester) async {
      final store = TrustStore(memoryOnly: true);
      await signIn(store, 'customer-A');
      store.create(request('published'));
      store.create(request('private-draft', draft: true));
      await signIn(store, 'provider-A', provider: true);
      await tester.pumpWidget(TrustApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الطلبات').last);
      await tester.pumpAndSettle();
      expect(find.text('طلب تجديد السجل published'), findsOneWidget);
      expect(find.text('طلب تجديد السجل private-draft'), findsNothing);
      await tester.tap(find.text('طلب تجديد السجل published'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('قدّم عرضك'), 180);
      await tester.tap(find.text('قدّم عرضك'));
      await tester.pumpAndSettle();
      for (final entry in {
        'سعر الخدمة بالريال': '٢٠٠',
        'مدة الإنجاز بالأيام': '٣',
        'ماذا يشمل عرضك؟': 'متابعة التجديد وتسليم الإيصال',
      }.entries) {
        final field = find.widgetWithText(TextFormField, entry.key);
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('إرسال العرض'));
      await tester.tap(find.text('إرسال العرض'));
      await tester.pumpAndSettle();
      expect(store.visible.single.offers.single.providerId, 'provider-A');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await store.clearAccount();
      await signIn(store, 'customer-A');
      await tester.pumpWidget(TrustApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('طلباتي').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('طلب تجديد السجل published'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('طلب تجديد السجل published'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('اختيار العرض'), 180);
      expect(find.text('حساب provider-A'), findsOneWidget);
      expect(find.text('متابعة التجديد وتسليم الإيصال'), findsOneWidget);
      expect(
        store.visible
            .firstWhere((r) => r.id == 'published')
            .offers
            .single
            .amount,
        20000,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
