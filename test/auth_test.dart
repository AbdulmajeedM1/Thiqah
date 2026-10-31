import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_app/src/auth.dart';
import 'package:trust_app/src/store.dart';

class MemoryVault implements TokenVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async {
    value = token;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class FakeAuthApi extends AuthApi {
  Map<String, dynamic>? lastBody;
  String? fail;
  String role = 'customer';
  final calls = <String>[];
  final tokens = <String?>[];
  Map<String, dynamic> get account => {
    'id': 'account-A',
    'fullName': 'مستخدم الاختبار',
    'username': 'test_user',
    'email': 'test@example.com',
    'phone': '+966500000001',
    'city': 'الرياض',
    'role': role,
    'status': 'active',
    'createdAt': '2026-09-16T00:00:00Z',
  };
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    calls.add('$method $path');
    lastBody = body;
    tokens.add(token);
    if (fail != null) throw AuthFailure(fail!);
    if (path == '/admin/users') {
      return {
        'users': [account],
      };
    }
    return {
      'user': account,
      'token': path == '/auth/password' ? 'rotated-token' : 'test-token',
    };
  }
}

void main() {
  test('login stores only token, activates identity, and logout clears local access', () async {
    final api = FakeAuthApi();
    final vault = MemoryVault();
    String? activeId;
    final auth = AuthController(
      api: api,
      vault: vault,
      onAuthenticated: (user) async {
        activeId = user.id;
      },
      onLogout: () async {
        activeId = null;
      },
    );
    expect(await auth.login('test_user', 'some-password'), isTrue);
    expect(vault.value, 'test-token');
    expect(activeId, 'account-A');
    await auth.logout();
    expect(auth.user, isNull);
    expect(activeId, isNull);
    expect(vault.value, isNull);
    expect(api.tokens.last, 'test-token');
  });
  test(
    'invalid credentials do not create a local authenticated session',
    () async {
      final api = FakeAuthApi()..fail = 'invalid_credentials';
      final vault = MemoryVault();
      final auth = AuthController(api: api, vault: vault);
      expect(await auth.login('test_user', 'wrong'), isFalse);
      expect(auth.errorCode, 'invalid_credentials');
      expect(auth.user, isNull);
      expect(vault.value, isNull);
    },
  );
  test(
    'restoration validates stored token and removes revoked sessions',
    () async {
      final api = FakeAuthApi()..fail = 'unauthorized';
      final vault = MemoryVault()..value = 'revoked-token';
      final auth = AuthController(api: api, vault: vault);
      await auth.restore();
      expect(api.calls, ['GET /auth/me']);
      expect(auth.user, isNull);
      expect(vault.value, isNull);
    },
  );
  test('password change rotates stored session and suspended admin requests sign out', () async {
    final api = FakeAuthApi()..role = 'admin';
    final vault = MemoryVault();
    final auth = AuthController(api: api, vault: vault);
    await auth.login('admin', 'some-password');
    expect(await auth.changePassword('some-password', 'new-password'), isTrue);
    expect(vault.value, 'rotated-token');
    await auth.listUsers();
    expect(api.tokens.last, 'rotated-token');
    api.fail = 'account_suspended';
    await expectLater(auth.listUsers(), throwsA(isA<AuthFailure>()));
    expect(auth.user, isNull);
    expect(vault.value, isNull);
  });
  test(
    'customers only see their own requests and retain separate preferences',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'thiqah-accounts-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = TrustStore(storagePath: '${directory.path}/legacy.json');
      await store.load();
      await store.save();
      final legacy = await File('${directory.path}/legacy.json').readAsString();
      await store.activateAccount(
        accountId: 'account-A',
        fullName: 'عميل أول',
        accountCity: 'الرياض',
        isProvider: false,
      );
      expect(store.visible, isEmpty);
      store.create(
        Request(
          id: 'private-A',
          title: 'طلب خاص بالعميل',
          description: 'هذه تفاصيل خاصة تخص العميل الأول فقط.',
          category: 0,
          city: 'الرياض',
          budget: 30000,
          consent: true,
        ),
      );
      await store.activateAccount(
        accountId: 'account-B',
        fullName: 'عميل ثان',
        accountCity: 'جدة',
        isProvider: false,
      );
      expect(store.visible, isEmpty);
      expect(store.withdrawn, 0);
      expect(store.notifications, isEmpty);
      await store.clearAccount();
      expect(store.entered, isFalse);
      expect(store.name, isEmpty);
      await store.activateAccount(
        accountId: 'account-A',
        fullName: 'عميل أول',
        accountCity: 'الرياض',
        isProvider: false,
      );
      expect(store.requests.single.id, 'private-A');
      expect(
        await File('${directory.path}/legacy.json').readAsString(),
        legacy,
      );
      await expectLater(
        store.activateAccount(
          accountId: '../escape',
          fullName: 'test',
          accountCity: 'test',
          isProvider: false,
        ),
        throwsArgumentError,
      );
    },
  );
}
