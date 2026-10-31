import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_app/src/store.dart';

Request request(String id, {bool draft = false}) => Request(
  id: id,
  title: 'طلب تجديد السجل $id',
  description: 'مراجعة المستندات واستكمال متطلبات تجديد السجل التجاري.',
  category: 1,
  city: 'الرياض',
  budget: 30000,
  consent: !draft,
  stage: draft ? Stage.draft : Stage.open,
);

Future<void> signIn(TrustStore store, String id, {bool provider = false}) =>
    store.activateAccount(
      accountId: id,
      fullName: 'حساب $id',
      accountCity: 'الرياض',
      isProvider: provider,
    );

void main() {
  late Directory directory;
  late TrustStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('trust-marketplace-');
    store = TrustStore(storagePath: '${directory.path}/legacy.json');
  });
  tearDown(() async {
    await store.clearAccount();
    await directory.delete(recursive: true);
  });

  test('published requests reach providers; drafts and customer accounts stay private', () async {
    await signIn(store, 'customer-A');
    store.create(request('published'));
    store.create(request('draft', draft: true));
    final staleRequest = store.visible.first;
    await signIn(store, 'provider-A', provider: true);
    expect(store.visible.map((r) => r.id), ['published']);
    expect(store.canReadPrivateDetails(store.visible.single), isFalse);
    expect(() => store.offer(staleRequest, 10000, 2, ''), throwsStateError);
    final privateDraft = store.requests.firstWhere((r) => r.id == 'draft');
    expect(() => store.offer(privateDraft, 10000, 2, ''), throwsStateError);
    await signIn(store, 'customer-B');
    expect(store.visible, isEmpty);
    expect(() => store.cancel(store.requests.first), throwsStateError);
    await signIn(store, 'customer-A');
    final draft = store.visible.firstWhere((r) => r.id == 'draft');
    draft.consent = true;
    store.publish(draft);
    await signIn(store, 'provider-A', provider: true);
    expect(store.visible.map((r) => r.id), containsAll(['draft', 'published']));
    await signIn(store, 'customer-A');
    store.cancel(store.visible.firstWhere((r) => r.id == 'draft'));
    await signIn(store, 'provider-A', provider: true);
    expect(store.visible.map((r) => r.id), ['published']);
  });

  test('two providers own distinct offers and only the chosen provider completes and earns', () async {
    await signIn(store, 'customer-A');
    store.create(request('shared'));
    await signIn(store, 'provider-A', provider: true);
    store.offer(store.visible.single, 20000, 2, 'عرض أول');
    expect(
      () => store.offer(store.visible.single, 15000, 1, ''),
      throwsStateError,
    );
    await signIn(store, 'provider-B', provider: true);
    expect(store.visible.single.offers.any(store.ownsOffer), isFalse);
    store.offer(store.visible.single, 18000, 3, 'عرض ثان');
    store.withdrawOffer(store.visible.single);
    expect(store.visible.single.offers.single.providerId, 'provider-A');
    store.offer(store.visible.single, 19000, 2, 'عرض معدل');
    await signIn(store, 'customer-A');
    var r = store.visible.single;
    expect(r.offers.map((o) => o.providerId), ['provider-A', 'provider-B']);
    store.select(r, r.offers.first);
    store.pay(r);
    store.send(r, 'رسالة خاصة لمقدم الخدمة المختار');
    await signIn(store, 'provider-B', provider: true);
    r = store.visible.single;
    expect(store.ownsOffer(r.selected), isFalse);
    expect(store.canChat(r), isFalse);
    expect(store.canReadPrivateDetails(r), isFalse);
    expect(() => store.send(r, 'not allowed'), throwsStateError);
    expect(() => store.complete(r, 'not my selected offer'), throwsStateError);
    expect(store.held, 0);
    await signIn(store, 'provider-A', provider: true);
    r = store.visible.single;
    expect(store.canChat(r), isTrue);
    expect(r.messages.single.text, 'رسالة خاصة لمقدم الخدمة المختار');
    store.send(r, 'تم الاطلاع على المستندات');
    store.complete(r, 'تم التجديد بالمرجع TEST-2026');
    await signIn(store, 'customer-A');
    r = store.visible.single;
    expect(r.stage, Stage.confirmation);
    expect(r.messages.last.provider, isTrue);
    store.confirm(r);
    store.review(r, 5, 'ممتاز');
    await signIn(store, 'provider-A', provider: true);
    expect(store.available, 18000);
    store.withdraw(18000);
    await store.save();
    await store.clearAccount();
    store = TrustStore(storagePath: '${directory.path}/legacy.json');
    await signIn(store, 'provider-A', provider: true);
    expect(store.visible.single.stage, Stage.completed);
    expect(store.visible.single.rating, 5);
    expect(store.available, 0);
    expect(store.withdrawn, 18000);
    await signIn(store, 'provider-B', provider: true);
    expect(store.available, 0);
    expect(store.withdrawn, 0);
  });

  test('existing account files migrate once, preserve drafts, and remain as backups', () async {
    final accounts = Directory('${directory.path}/accounts');
    await accounts.create();
    final originals = <String, String>{};
    for (final customer in ['customer-A', 'customer-B']) {
      final path = '${accounts.path}/$customer.json';
      final old = TrustStore(storagePath: path);
      await old.load(seedIfMissing: false);
      old.create(request('same-old-id'));
      old.create(request('draft-$customer', draft: true));
      await old.save();
      originals[path] = await File(path).readAsString();
    }
    // The provider can find old customer requests immediately after updating,
    // without requiring the customer to sign in or publish them again.
    await signIn(store, 'provider-A', provider: true);
    expect(store.visible, hasLength(2));
    expect(store.visible.map((r) => r.id).toSet(), hasLength(2));
    expect(store.visible.map((r) => r.customerId).toSet(), {
      'customer-A',
      'customer-B',
    });
    store.offer(
      store.visible.firstWhere((r) => r.customerId == 'customer-A'),
      15000,
      2,
      'عرض بعد التحديث',
    );
    await signIn(store, 'customer-A');
    expect(store.visible, hasLength(2));
    expect(
      store.visible.where((r) => r.stage == Stage.open).single.offers,
      hasLength(1),
    );
    store.cancel(store.visible.firstWhere((r) => r.stage == Stage.open));
    await store.save();
    await store.clearAccount();
    store = TrustStore(storagePath: '${directory.path}/legacy.json');
    await signIn(store, 'provider-B', provider: true);
    expect(store.visible.single.customerId, 'customer-B');
    expect(store.requests, hasLength(4));
    for (final entry in originals.entries) {
      expect(await File(entry.key).readAsString(), entry.value);
    }
  });

  test('a corrupt marketplace is preserved and cannot be overwritten by a new request', () async {
    final file = File('${directory.path}/thiqah_marketplace_v2.json');
    await file.writeAsString('corrupt original data');
    await signIn(store, 'customer-A');
    expect(store.storageError, isNotNull);
    expect(() => store.create(request('unsafe')), throwsStateError);
    await store.save();
    expect(await file.readAsString(), 'corrupt original data');
  });
}
