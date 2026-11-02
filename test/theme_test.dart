import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_app/main.dart';
import 'package:trust_app/src/store.dart';

Future<void> activate(TrustStore store, String id) => store.activateAccount(
  accountId: id,
  fullName: id,
  accountCity: 'Riyadh',
  isProvider: false,
);

void main() {
  test('theme survives restart and remains specific to its account', () async {
    final dir = await Directory.systemTemp.createTemp('thiqah-theme-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/legacy.json';
    final first = TrustStore(storagePath: path);
    await activate(first, 'customer-a');
    first.darkMode = true;
    await first.save();
    await activate(first, 'customer-b');
    expect(first.darkMode, isFalse);
    await first.clearAccount();
    final restored = TrustStore(storagePath: path);
    await activate(restored, 'customer-a');
    expect(restored.darkMode, isTrue);
    restored.darkMode = false;
    await restored.save();
    await restored.clearAccount();
    await activate(restored, 'customer-a');
    expect(restored.darkMode, isFalse);
  });

  for (final provider in [false, true]) {
    testWidgets('account theme switch updates the app for provider=$provider', (
      tester,
    ) async {
      final store = TrustStore(memoryOnly: true)..seed();
      store.entered = true;
      store.english = true;
      store.provider = provider;
      await tester.pumpWidget(TrustApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account').last);
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('dark-mode-switch'));
      await tester.scrollUntilVisible(toggle, 200);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(store.darkMode, isTrue);
      expect(Theme.of(tester.element(toggle)).brightness, Brightness.dark);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(toggle)).brightness, Brightness.light);
      expect(tester.takeException(), isNull);
    });
  }
}
