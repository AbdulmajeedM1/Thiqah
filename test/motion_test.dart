import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_app/main.dart';
import 'package:trust_app/src/motion.dart';
import 'package:trust_app/src/store.dart';

void main() {
  testWidgets('launch reveal keeps the underlying screen mounted', (
    tester,
  ) async {
    var mounts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LaunchIntro(
          onComplete: () {},
          child: _MountProbe(onMount: () => mounts++),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(mounts, 1);
    expect(find.byKey(const ValueKey('launch-intro')), findsNothing);
  });
  testWidgets(
    'launch animation finishes once and does not replay on preferences',
    (tester) async {
      final store = TrustStore(memoryOnly: true)..entered = true;
      await tester.pumpWidget(TrustApp(store: store));
      expect(find.byKey(const ValueKey('launch-intro')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('launch-intro')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('launch-intro')), findsNothing);
      store.darkMode = true;
      await store.save();
      await tester.pump();
      expect(find.byKey(const ValueKey('launch-intro')), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion skips startup and entrance animations', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final store = TrustStore(memoryOnly: true)..entered = true;
    await tester.pumpWidget(TrustApp(store: store));
    expect(find.byKey(const ValueKey('launch-intro')), findsNothing);
    await tester.pumpAndSettle();
    final entry = find.byType(Entrance).first;
    expect(
      find.descendant(
        of: entry,
        matching: find.byType(TweenAnimationBuilder<double>),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing during startup leaves no active animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      TrustApp(store: TrustStore(memoryOnly: true)..entered = true),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _MountProbe extends StatefulWidget {
  const _MountProbe({required this.onMount});
  final VoidCallback onMount;
  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
