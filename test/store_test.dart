import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_app/src/store.dart';

void main() {
  late TrustStore store;
  setUp(() {
    store = TrustStore(memoryOnly: true)..seed();
  });

  test('disk storage restores latest queued changes and preserves corrupt original', () async {
    final directory = await Directory.systemTemp.createTemp('thiqah-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/state.json');
    final disk = TrustStore(storagePath: file.path);
    await disk.load();
    disk.customerName = 'Test Customer';
    final firstWrite = disk.save();
    disk.english = true;
    final secondWrite = disk.save();
    await Future.wait([firstWrite, secondWrite]);
    expect(disk.storageError, isNull);
    final restored = TrustStore(storagePath: file.path);
    await restored.load();
    expect(restored.customerName, 'Test Customer');
    expect(restored.english, isTrue);
    expect(restored.requests.first.toJson(), disk.requests.first.toJson());
    await file.writeAsString('corrupt original');
    final damaged = TrustStore(storagePath: file.path);
    await damaged.load();
    expect(damaged.storageError, isNotNull);
    await damaged.save();
    expect(await file.readAsString(), 'corrupt original');
  });

  test(
    'complete lifecycle, exact demo fees, payout and duplicate protection',
    () {
      final r = store.requests.first;
      store.select(r, r.offers.first);
      expect(r.stage, Stage.payment);
      expect(r.total, 36750);
      store.pay(r);
      expect(r.stage, Stage.active);
      expect(() => store.pay(r), throwsStateError);
      expect(() => store.confirm(r), throwsStateError);
      store.provider = true;
      store.complete(r, 'Completed renewal, reference TEST-1234');
      expect(r.stage, Stage.confirmation);
      expect(() => store.confirm(r), throwsStateError);
      store.provider = false;
      store.confirm(r);
      expect(r.stage, Stage.completed);
      expect(() => store.confirm(r), throwsStateError);
      store.review(r, 5, 'Excellent');
      expect(() => store.review(r, 4, 'Again'), throwsStateError);
      store.provider = true;
      expect(store.available, 31500);
      store.withdraw(31500);
      expect(store.available, 0);
      expect(() => store.withdraw(1), throwsStateError);
    },
  );

  test('dispute freezes completion and cancellation', () {
    final r = store.requests[1];
    store.dispute(r, 'The completed work is not what was requested.');
    expect(r.stage, Stage.disputed);
    expect(store.held, 21000);
    expect(() => store.confirm(r), throwsStateError);
    expect(() => store.cancel(r), throwsStateError);
    store.provider = true;
    expect(() => store.complete(r, 'Some completion proof'), throwsStateError);
  });

  test('request validation, draft publish, offer withdrawal and roles', () {
    final r = Request(
      id: 'test',
      title: 'Test request',
      description: 'A detailed request description.',
      category: 0,
      city: 'Riyadh',
      budget: 10000,
      stage: Stage.draft,
    );
    store.create(r);
    expect(() => store.publish(r), throwsStateError);
    r.consent = true;
    store.publish(r);
    expect(() => store.offer(r, 9000, 2, ''), throwsStateError);
    store.provider = true;
    store.offer(r, 9000, 2, 'Offer details');
    expect(() => store.offer(r, 9500, 2, ''), throwsStateError);
    store.withdrawOffer(r);
    expect(r.offers, isEmpty);
    store.offer(r, 8500, 1, 'Updated');
    store.provider = false;
    store.cancel(r);
    store.provider = true;
    expect(() => store.offer(r, 8000, 1, ''), throwsStateError);
  });

  test('serialization preserves lifecycle, messages, offers and documents', () {
    final r = store.requests.first;
    store.send(r, 'Test message');
    r.documents.add(Document('sample.pdf', '/sample.pdf', 123));
    store.select(r, r.offers.first);
    final restored = Request.fromJson(r.toJson());
    expect(restored.toJson(), r.toJson());
    expect(restored.selected!.amount, 35000);
  });
}
