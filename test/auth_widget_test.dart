import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trust_app/main.dart';
import 'package:trust_app/src/admin_screen.dart';
import 'package:trust_app/src/auth.dart';
import 'package:trust_app/src/auth_screens.dart';
import 'package:trust_app/src/store.dart';

import 'auth_test.dart' show FakeAuthApi, MemoryVault;

void main() {
  testWidgets('authentication gate blocks a previously entered demo session', (
    tester,
  ) async {
    final store = TrustStore(memoryOnly: true)..entered = true;
    final api = FakeAuthApi()..fail = 'invalid_credentials';
    final auth = AuthController(api: api, vault: MemoryVault());
    await tester.pumpWidget(TrustApp(store: store, auth: auth));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('loginIdentifier')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('loginIdentifier')),
      'admin',
    );
    await tester.enterText(
      find.byKey(const ValueKey('loginPassword')),
      'wrong-password',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('loginSubmit')));
    await tester.tap(find.byKey(const ValueKey('loginSubmit')));
    await tester.pumpAndSettle();
    expect(auth.user, isNull);
    expect(
      find.text(authErrorText('invalid_credentials', false)),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets(
    'Arabic registration validates consent and sends full normalized profile',
    (tester) async {
      final store = TrustStore(memoryOnly: true);
      final api = FakeAuthApi();
      final auth = AuthController(
        api: api,
        vault: MemoryVault(),
        onAuthenticated: (u) => store.activateAccount(
          accountId: u.id,
          fullName: u.fullName,
          accountCity: u.city,
          isProvider: false,
        ),
      );
      await tester.pumpWidget(TrustApp(store: store, auth: auth));
      await tester.pumpAndSettle();
      final toggle = find.text('ليس لديك حساب؟ إنشاء حساب جديد');
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      Future<void> fill(String key, String value) async {
        final field = find.byKey(ValueKey(key));
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, value);
      }

      await fill('registerFullName', 'عبدالله محمد');
      await fill('registerUsername', 'abdullah');
      await fill('registerEmail', 'abdullah@example.com');
      await fill('registerPhone', '٠٥٠١٢٣٤٥٦٧');
      await fill('registerCity', 'الرياض');
      await fill('registerPassword', 'Private-password-123');
      await fill('registerConfirmation', 'Private-password-123');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final submit = find.byKey(const ValueKey('registerSubmit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.lastBody!['fullName'], 'عبدالله محمد');
      expect(api.lastBody!['phone'], '+966501234567');
      expect(api.lastBody!['role'], 'customer');
      expect(api.lastBody!['termsAccepted'], isTrue);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('تجربة حساب مقدم الخدمة'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('admin can change password and logout removes protected routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = TrustStore(memoryOnly: true);
    final api = FakeAuthApi()..role = 'admin';
    final auth = AuthController(api: api, vault: MemoryVault());
    await auth.login('admin', 'original-password');
    await tester.pumpWidget(TrustApp(store: store, auth: auth));
    await tester.pumpAndSettle();
    expect(find.byType(AdminScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const ValueKey('userStatus-account-A')), findsNothing);

    await tester.tap(find.byTooltip('خيارات الحساب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تغيير كلمة المرور'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 3; i++) {
      final field = find.byKey(ValueKey('changePassword$i'));
      await tester.ensureVisible(field);
      await tester.enterText(
        field,
        i == 0 ? 'original-password' : 'new-private-password',
      );
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final submit = find.byKey(const ValueKey('changePasswordSubmit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(api.calls, contains('POST /auth/password'));
    expect(find.byType(ChangePasswordScreen), findsNothing);

    // An expired/logged-out session must also remove an already-open route.
    await tester.tap(find.byTooltip('خيارات الحساب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تغيير كلمة المرور'));
    await tester.pumpAndSettle();
    await auth.logout();
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordScreen), findsNothing);
    expect(find.byType(AdminScreen), findsNothing);
    expect(find.byKey(const ValueKey('loginIdentifier')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Saudi phone normalization accepts Arabic keyboard digits', () {
    expect(normalizeSaudiMobile('٠٥٠١٢٣٤٥٦٧'), '+966501234567');
    expect(normalizeSaudiMobile('00966 50 123 4567'), '+966501234567');
  });
}
