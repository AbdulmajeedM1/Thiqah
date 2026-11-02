import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_app/src/provider_screen.dart';
import 'package:trust_app/src/request_progress.dart';
import 'package:trust_app/src/request_screens.dart';
import 'package:trust_app/src/store.dart';
import 'package:trust_app/src/theme.dart';

Request job(
  String id,
  Offer offer, {
  Stage stage = Stage.completed,
  int rating = 5,
}) {
  final r = Request(
    id: id,
    title: 'Private request title',
    description: 'Private description',
    category: 1,
    city: 'Riyadh',
    budget: 10000,
    stage: stage,
  );
  r.offers.add(offer);
  r.selectedId = offer.id;
  r.rating = rating;
  r.review = 'Excellent service';
  return r;
}

void main() {
  test('provider stats use identity and completed work, not display names', () {
    final store = TrustStore(memoryOnly: true);
    final a = Offer(
      id: 'a',
      providerId: 'provider-a',
      name: 'Same name',
      amount: 10000,
      days: 2,
    );
    final b = Offer(
      id: 'b',
      providerId: 'provider-b',
      name: 'Same name',
      amount: 10000,
      days: 2,
    );
    final a2 = Offer(
      id: 'a2',
      providerId: 'provider-a',
      name: 'Same name',
      amount: 10000,
      days: 2,
    );
    store.requests.addAll([
      job('1', a),
      job('2', b, rating: 1),
      job('3', a2, rating: 3),
      job('4', a, stage: Stage.active),
    ]);
    final summary = ProviderSummary(store, a);
    expect(summary.completed, 2);
    expect(summary.average, 4);
    expect(summary.reviews.length, 2);
    expect(ProviderSummary(store, b).average, 1);
    final legacy = Offer(id: 'old', name: 'Same name', amount: 1, days: 1);
    expect(ProviderSummary(store, legacy).completed, 0);
  });

  testWidgets(
    'every request state fits in Arabic dark mode on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = TrustStore(memoryOnly: true);
      for (final stage in Stage.values) {
        final r = Request(
          id: '1',
          title: 'طلب',
          description: '',
          category: 0,
          city: '',
          budget: 100,
          stage: stage,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: trustTheme(Brightness.dark),
            home: Scaffold(
              body: Directionality(
                textDirection: TextDirection.rtl,
                child: SingleChildScrollView(
                  child: RequestProgress(store: store, request: r),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('رحلة طلبك'), findsOneWidget);
        if (stage == Stage.disputed) expect(find.text('متوقف'), findsOneWidget);
        if (stage == Stage.cancelled || stage == Stage.refunded) {
          expect(find.text('اكتمل الطلب'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('offer opens public profile without exposing request details', (
    tester,
  ) async {
    final store = TrustStore(memoryOnly: true)..seed();
    store.english = true;
    final request = store.requests.first;
    await tester.pumpWidget(
      MaterialApp(
        theme: trustTheme(Brightness.light),
        home: RequestScreen(store: store, request: request),
      ),
    );
    await tester.pumpAndSettle();
      final button = find.byKey(ValueKey('provider-profile-${request.offers.first.id}'));
    await tester.scrollUntilVisible(button.hitTestable(), 250);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(ProviderScreen), findsOneWidget);
    expect(find.text(request.offers.first.name), findsOneWidget);
    expect(find.text(request.description), findsNothing);
    expect(find.text(request.title), findsNothing);
    expect(find.text('0'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
