import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trust_app/src/auth.dart';
import 'package:trust_app/src/local_auth.dart';

import 'auth_test.dart' show MemoryVault;

class FailingVault extends MemoryVault {
  bool fail = false;
  @override
  Future<void> write(String token) async {
    if (fail) throw StateError('Storage unavailable');
    await super.write(token);
  }
}

void main() {
  late Map<String, dynamic> admin;
  late MemoryVault vault;
  late LocalAuthApi api;
  final registration = <String, dynamic>{
    'fullName': 'عبدالله محمد',
    'username': 'abdullah',
    'email': 'abdullah@example.com',
    'phone': '٠٥٠١٢٣٤٥٦٧',
    'city': 'الرياض',
    'role': 'customer',
    'password': 'University-test-123',
    'termsAccepted': true,
  };
  Matcher failure(String code) =>
      isA<AuthFailure>().having((e) => e.code, 'code', code);
  setUpAll(() async {
    final salt = base64UrlEncode(List<int>.filled(16, 42));
    admin = {
      'id': 'local-admin',
      'fullName': 'مدير المشروع',
      'username': 'admin',
      'email': 'admin@trust.local',
      'phone': '',
      'city': 'الرياض',
      'role': 'admin',
      'status': 'active',
      'createdAt': '2026-09-17T00:00:00Z',
      'salt': salt,
      'iterations': 1000,
      'passwordHash': await deriveLocalPassword({
        'password': 'Admin-test-123',
        'salt': salt,
        'iterations': 1000,
      }),
    };
  });
  setUp(() {
    vault = MemoryVault();
    api = LocalAuthApi(
      database: vault,
      bootstrapAdmin: admin,
      passwordIterations: 1000,
    );
  });
  Future<Map<String, dynamic>> adminLogin() => api.request(
    'POST',
    '/auth/login',
    body: {'login': 'admin', 'password': 'Admin-test-123'},
  );

  test(
    'register, restore and login work locally and secrets are not exposed',
    () async {
      final created = await api.request(
        'POST',
        '/auth/register',
        body: registration,
      );
      expect(created['user']['phone'], '+966501234567');
      expect(created['user'].containsKey('passwordHash'), isFalse);
      expect(vault.value, isNot(contains(registration['password'])));
      expect(vault.value, isNot(contains(created['token'])));
      final restarted = LocalAuthApi(
        database: vault,
        bootstrapAdmin: admin,
        passwordIterations: 1000,
      );
      final session = await restarted.request(
        'GET',
        '/auth/me',
        token: created['token'],
      );
      expect(session['user']['id'], created['user']['id']);
      final loggedIn = await restarted.request(
        'POST',
        '/auth/login',
        body: {
          'login': 'ABDULLAH@EXAMPLE.COM',
          'password': registration['password'],
        },
      );
      expect(loggedIn['user']['username'], 'abdullah');
      await restarted.request('POST', '/auth/logout', token: created['token']);
      await expectLater(
        restarted.request('GET', '/auth/me', token: created['token']),
        throwsA(failure('unauthorized')),
      );
    },
  );

  test(
    'registration rejects duplicates, omitted fields and privilege escalation',
    () async {
      await expectLater(
        api.request(
          'POST',
          '/auth/register',
          body: {...registration, 'role': 'admin'},
        ),
        throwsA(failure('invalid_input')),
      );
      await expectLater(
        api.request(
          'POST',
          '/auth/register',
          body: {...registration, 'termsAccepted': false},
        ),
        throwsA(failure('terms_required')),
      );
      await expectLater(
        api.request(
          'POST',
          '/auth/register',
          body: {...registration, 'city': ''},
        ),
        throwsA(failure('invalid_input')),
      );
      await expectLater(
        api.request(
          'POST',
          '/auth/register',
          body: {...registration, 'status': 'active'},
        ),
        throwsA(failure('invalid_input')),
      );
      await api.request('POST', '/auth/register', body: registration);
      await expectLater(
        api.request('POST', '/auth/register', body: registration),
        throwsA(failure('username_taken')),
      );
      await expectLater(
        api.request(
          'POST',
          '/auth/register',
          body: {...registration, 'username': 'another'},
        ),
        throwsA(failure('email_taken')),
      );
      await expectLater(
        api.request(
          'POST',
          '/auth/register',
          body: {
            ...registration,
            'username': 'another',
            'email': 'another@example.com',
          },
        ),
        throwsA(failure('phone_taken')),
      );
    },
  );

  test(
    'only administrator can list and suspend; suspended sessions are revoked',
    () async {
      final customer = await api.request(
        'POST',
        '/auth/register',
        body: registration,
      );
      await expectLater(
        api.request('GET', '/admin/users', token: customer['token']),
        throwsA(failure('forbidden')),
      );
      final owner = await adminLogin();
      expect(
        (await api.request(
          'GET',
          '/admin/users',
          token: owner['token'],
        ))['users'],
        hasLength(2),
      );
      await expectLater(
        api.request(
          'PATCH',
          '/admin/users/local-admin',
          token: owner['token'],
          body: {'status': 'suspended'},
        ),
        throwsA(failure('protected_account')),
      );
      final path = '/admin/users/${customer['user']['id']}';
      await api.request(
        'PATCH',
        path,
        token: owner['token'],
        body: {'status': 'suspended'},
      );
      await expectLater(
        api.request('GET', '/auth/me', token: customer['token']),
        throwsA(failure('unauthorized')),
      );
      await expectLater(
        api.request(
          'POST',
          '/auth/login',
          body: {'login': 'abdullah', 'password': registration['password']},
        ),
        throwsA(failure('account_suspended')),
      );
      await api.request(
        'PATCH',
        path,
        token: owner['token'],
        body: {'status': 'active'},
      );
      expect(
        (await api.request(
          'POST',
          '/auth/login',
          body: {'login': 'abdullah', 'password': registration['password']},
        ))['user']['status'],
        'active',
      );
    },
  );

  test('password changes revoke old sessions and survive restart', () async {
    final owner = await adminLogin();
    await expectLater(
      api.request(
        'POST',
        '/auth/password',
        token: owner['token'],
        body: {'currentPassword': 'wrong', 'newPassword': 'Changed-admin-123'},
      ),
      throwsA(failure('invalid_credentials')),
    );
    final updated = await api.request(
      'POST',
      '/auth/password',
      token: owner['token'],
      body: {
        'currentPassword': 'Admin-test-123',
        'newPassword': 'Changed-admin-123',
      },
    );
    await expectLater(
      api.request('GET', '/auth/me', token: owner['token']),
      throwsA(failure('unauthorized')),
    );
    final restarted = LocalAuthApi(
      database: vault,
      bootstrapAdmin: admin,
      passwordIterations: 1000,
    );
    await expectLater(
      restarted.request(
        'POST',
        '/auth/login',
        body: {'login': 'admin', 'password': 'Admin-test-123'},
      ),
      throwsA(failure('invalid_credentials')),
    );
    expect(
      (await restarted.request(
        'GET',
        '/auth/me',
        token: updated['token'],
      ))['user']['role'],
      'admin',
    );
    expect(
      (await restarted.request(
        'POST',
        '/auth/login',
        body: {'login': 'admin', 'password': 'Changed-admin-123'},
      ))['user']['role'],
      'admin',
    );
  });

  test(
    'repeated wrong passwords are throttled and expired tokens are rejected',
    () async {
      var clock = DateTime.utc(2026, 9, 17);
      api = LocalAuthApi(
        database: vault,
        bootstrapAdmin: admin,
        passwordIterations: 1000,
        now: () => clock,
      );
      for (var i = 0; i < 5; i++) {
        await expectLater(
          api.request(
            'POST',
            '/auth/login',
            body: {'login': 'admin', 'password': 'wrong'},
          ),
          throwsA(failure('invalid_credentials')),
        );
      }
      await expectLater(adminLogin(), throwsA(failure('rate_limited')));
      clock = clock.add(const Duration(seconds: 31));
      final owner = await adminLogin();
      clock = clock.add(const Duration(days: 8));
      await expectLater(
        api.request('GET', '/auth/me', token: owner['token']),
        throwsA(failure('unauthorized')),
      );
    },
  );

  test(
    'failed saves roll back account creation and corrupt data is preserved',
    () async {
      final failing = FailingVault();
      api = LocalAuthApi(
        database: failing,
        bootstrapAdmin: admin,
        passwordIterations: 1000,
      );
      await adminLogin();
      failing.fail = true;
      await expectLater(
        api.request('POST', '/auth/register', body: registration),
        throwsA(failure('local_data_unavailable')),
      );
      failing.fail = false;
      expect(
        (await api.request(
          'POST',
          '/auth/register',
          body: registration,
        ))['user']['username'],
        'abdullah',
      );
      final broken = MemoryVault()..value = 'not valid json';
      final badApi = LocalAuthApi(
        database: broken,
        bootstrapAdmin: admin,
        passwordIterations: 1000,
      );
      await expectLater(
        badApi.request(
          'POST',
          '/auth/login',
          body: {'login': 'admin', 'password': 'Admin-test-123'},
        ),
        throwsA(failure('local_data_unavailable')),
      );
      expect(broken.value, 'not valid json');
    },
  );
}
