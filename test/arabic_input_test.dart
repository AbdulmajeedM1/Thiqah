import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_app/main.dart';
import 'package:trust_app/src/request_screens.dart';
import 'package:trust_app/src/store.dart';

Future<void> fill(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.scrollUntilVisible(
    field,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(field, value);
}

void main() {
  testWidgets('publishes Arabic request text and Arabic decimal budget', (
    tester,
  ) async {
    final store = TrustStore(memoryOnly: true)..seed();
    store.entered = true;
    await tester.pumpWidget(TrustApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طلب جديد'));
    await tester.pumpAndSettle();

    await fill(tester, 'عنوان الطلب', 'تجديد السجل التجاري');
    await fill(
      tester,
      'وصف المعاملة',
      'أحتاج إلى تجديد السجل التجاري وإرسال الإيصال.',
    );
    await fill(tester, 'المدينة', 'الرياض');
    await fill(tester, 'الميزانية المتوقعة', '١٬٢٣٤٫٥٠');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(CheckboxListTile),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.scrollUntilVisible(
      find.text('نشر الطلب'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نشر الطلب'));
    await tester.pumpAndSettle();

    final request = store.requests.first;
    expect(request.title, 'تجديد السجل التجاري');
    expect(
      request.description,
      'أحتاج إلى تجديد السجل التجاري وإرسال الإيصال.',
    );
    expect(request.city, 'الرياض');
    expect(request.budget, 123450);
    expect(request.stage, Stage.open);
    expect(request.consent, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submits offer with Persian price and Arabic delivery days', (
    tester,
  ) async {
    final store = TrustStore(memoryOnly: true)..seed();
    store.provider = true;
    final request = Request(
      id: 'arabic-input-offer',
      title: 'تجديد السجل التجاري',
      description: 'طلب تجديد السجل التجاري',
      category: 0,
      city: 'الرياض',
      budget: 40000,
      stage: Stage.open,
    );
    store.requests.add(request);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OfferScreen(store: store, request: request),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await fill(tester, 'سعر الخدمة بالريال', '۳۵۰٫۲۵');
    await fill(tester, 'مدة الإنجاز بالأيام', '٧');
    await fill(tester, 'ماذا يشمل عرضك؟', 'يشمل التجديد وإرسال الإيصال');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.scrollUntilVisible(
      find.text('إرسال العرض'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('إرسال العرض'));
    await tester.pumpAndSettle();

    expect(request.offers.single.amount, 35025);
    expect(request.offers.single.days, 7);
    expect(request.offers.single.notes, 'يشمل التجديد وإرسال الإيصال');
    expect(tester.takeException(), isNull);
  });
}
