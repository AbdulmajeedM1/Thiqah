import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth.dart';

/// Password derivation runs away from the UI isolate, preserving keyboard input.
Future<String> deriveLocalPassword(Map<String, dynamic> input) async {
  final algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: input['iterations'] as int,
    bits: 256,
  );
  final key = await algorithm.deriveKey(
    secretKey: SecretKey(utf8.encode(input['password'] as String)),
    nonce: base64Url.decode(input['salt'] as String),
  );
  return base64UrlEncode(await key.extractBytes());
}

class SecureAccountVault implements TokenVault {
  const SecureAccountVault();
  static const _storage = FlutterSecureStorage();
  static const _key = 'thiqah.local.accounts.v1';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// Device-only accounts for the university project. All mutations are serialized
/// and committed before success is returned; nothing is sent to a server.
class LocalAuthApi extends AuthApi {
  LocalAuthApi({
    TokenVault? database,
    this.bootstrapAdmin,
    this.passwordIterations = 600000,
    DateTime Function()? now,
  }) : database = database ?? const SecureAccountVault(),
       now = now ?? DateTime.now;
  final TokenVault database;
  final Map<String, dynamic>? bootstrapAdmin;
  final int passwordIterations;
  final DateTime Function() now;
  final _random = Random.secure();
  Future<void> _queue = Future.value();
  Map<String, dynamic>? _state;
  List<dynamic> get _users => _state!['users'] as List;
  List<dynamic> get _sessions => _state!['sessions'] as List;
  Map<String, dynamic> get _attempts =>
      _state!['attempts'] as Map<String, dynamic>;

  String _randomId([int length = 24]) =>
      base64UrlEncode(List<int>.generate(length, (_) => _random.nextInt(256)))
          .replaceAll('=', '');
  Future<String> _tokenHash(String token) async =>
      base64UrlEncode((await Sha256().hash(utf8.encode(token))).bytes);

  Future<void> _load() async {
    if (_state != null) return;
    try {
      final raw = await database.read();
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['version'] != 1 ||
            data['users'] is! List ||
            data['sessions'] is! List ||
            data['attempts'] is! Map) {
          throw const FormatException('Invalid account data');
        }
        for (final rawUser in data['users'] as List) {
          final user = rawUser as Map<String, dynamic>;
          if (user['id'] is! String ||
              user['passwordHash'] is! String ||
              user['salt'] is! String ||
              user['iterations'] is! int ||
              !['admin', 'customer', 'provider'].contains(user['role'])) {
            throw const FormatException('Invalid account record');
          }
        }
        _state = data;
      } else {
        final admin =
            bootstrapAdmin ??
            Map<String, dynamic>.from(
              jsonDecode(await rootBundle.loadString('assets/demo_admin.json')),
            );
        _state = {
          'version': 1,
          'users': [Map<String, dynamic>.from(admin)],
          'sessions': <dynamic>[],
          'attempts': <String, dynamic>{},
        };
        await database.write(jsonEncode(_state));
      }
    } catch (_) {
      _state = null;
      throw const AuthFailure('local_data_unavailable');
    }
  }

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) {
    final result = Completer<Map<String, dynamic>>();
    _queue = _queue.then((_) async {
      try {
        await _load();
        final previous = jsonEncode(_state);
        Map<String, dynamic>? value;
        AuthFailure? failure;
        try {
          value = await _dispatch(method, path, body ?? {}, token);
        } on AuthFailure catch (e) {
          failure = e;
        } catch (_) {
          _state = jsonDecode(previous) as Map<String, dynamic>;
          rethrow;
        }
        try {
          await database.write(jsonEncode(_state));
        } catch (_) {
          _state = jsonDecode(previous) as Map<String, dynamic>;
          throw const AuthFailure('local_data_unavailable');
        }
        if (failure != null) throw failure;
        result.complete(value!);
      } catch (error, stack) {
        result.completeError(
          error is AuthFailure
              ? error
              : const AuthFailure('local_data_unavailable'),
          stack,
        );
      }
    });
    return result.future;
  }

  Map<String, dynamic> _public(Map<String, dynamic> user) => {
    for (final field in [
      'id',
      'fullName',
      'username',
      'email',
      'phone',
      'city',
      'role',
      'status',
      'createdAt',
    ])
      field: user[field],
  };
  String _text(dynamic value, int max) {
    if (value is! String || value.length > max) {
      throw const AuthFailure('invalid_input');
    }
    return value.trim();
  }

  String _password(dynamic value) {
    if (value is! String ||
        value.length < 10 ||
        value.length > 128 ||
        value.trim().isEmpty) {
      throw const AuthFailure('invalid_password');
    }
    return value;
  }

  String _phone(dynamic value) {
    var digits = _text(value, 30)
        .replaceAllMapped(RegExp('[٠-٩۰-۹]'), (match) {
          final code = match[0]!.codeUnitAt(0);
          return '${code >= 0x6f0 ? code - 0x6f0 : code - 0x660}';
        })
        .replaceAll(RegExp(r'[\s()\-]'), '');
    if (digits.startsWith('00966')) digits = '+966${digits.substring(5)}';
    if (RegExp(r'^05[0-9]{8}$').hasMatch(digits)) {
      digits = '+966${digits.substring(1)}';
    }
    if (RegExp(r'^9665[0-9]{8}$').hasMatch(digits)) digits = '+$digits';
    if (!RegExp(r'^\+9665[0-9]{8}$').hasMatch(digits)) {
      throw const AuthFailure('invalid_input');
    }
    return digits;
  }

  Future<Map<String, dynamic>> _hash(String password) async {
    final salt = base64UrlEncode(
      List<int>.generate(16, (_) => _random.nextInt(256)),
    );
    final derived = await compute(deriveLocalPassword, {
      'password': password,
      'salt': salt,
      'iterations': passwordIterations,
    });
    return {
      'salt': salt,
      'iterations': passwordIterations,
      'passwordHash': derived,
    };
  }

  Future<bool> _verify(String password, Map<String, dynamic> user) async {
    final rounds = user['iterations'] as int;
    if (rounds < 1 || rounds > 2000000) {
      throw const AuthFailure('local_data_unavailable');
    }
    final actual = base64Url.decode(
      await compute(deriveLocalPassword, {
        'password': password,
        'salt': user['salt'],
        'iterations': rounds,
      }),
    );
    final expected = base64Url.decode(user['passwordHash'] as String);
    var difference = actual.length ^ expected.length;
    for (var i = 0; i < min(actual.length, expected.length); i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }

  Future<Map<String, dynamic>> _session(Map<String, dynamic> user) async {
    final token = _randomId(32);
    final time = now().millisecondsSinceEpoch;
    _sessions.removeWhere((s) => (s['expiresAt'] as int) <= time);
    _sessions.add({
      'hash': await _tokenHash(token),
      'userId': user['id'],
      'expiresAt': time + const Duration(days: 7).inMilliseconds,
    });
    return {'user': _public(user), 'token': token};
  }

  Future<Map<String, dynamic>> _authorize(
    String? token, {
    bool admin = false,
  }) async {
    if (token == null || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
      throw const AuthFailure('unauthorized');
    }
    final hash = await _tokenHash(token);
    final session = _sessions
        .where(
          (s) =>
              s['hash'] == hash &&
              (s['expiresAt'] as int) > now().millisecondsSinceEpoch,
        )
        .firstOrNull;
    if (session == null) throw const AuthFailure('unauthorized');
    final user = _users
        .cast<Map<String, dynamic>>()
        .where((u) => u['id'] == session['userId'])
        .firstOrNull;
    if (user == null) throw const AuthFailure('unauthorized');
    if (user['status'] != 'active') {
      throw const AuthFailure('account_suspended');
    }
    if (admin && user['role'] != 'admin') throw const AuthFailure('forbidden');
    return user;
  }

  Future<Map<String, dynamic>> _dispatch(
    String method,
    String path,
    Map<String, dynamic> body,
    String? token,
  ) async {
    if (method == 'POST' && path == '/auth/register') {
      const allowed = {
        'fullName',
        'username',
        'email',
        'phone',
        'city',
        'role',
        'password',
        'termsAccepted',
      };
      if (body.keys.any((key) => !allowed.contains(key))) {
        throw const AuthFailure('invalid_input');
      }
      if (body['termsAccepted'] != true) {
        throw const AuthFailure('terms_required');
      }
      final user = <String, dynamic>{
        'id': _randomId(),
        'fullName': _text(body['fullName'], 100),
        'username': _text(body['username'], 30).toLowerCase(),
        'email': _text(body['email'], 254).toLowerCase(),
        'phone': _phone(body['phone']),
        'city': _text(body['city'], 80),
        'role': body['role'],
        'status': 'active',
        'createdAt': now().toUtc().toIso8601String(),
      };
      if ((user['fullName'] as String).length < 3 ||
          (user['city'] as String).length < 2 ||
          !RegExp(r'^[a-z0-9_.]{3,30}$').hasMatch(user['username']) ||
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(user['email']) ||
          !['customer', 'provider'].contains(user['role'])) {
        throw const AuthFailure('invalid_input');
      }
      for (final field in ['username', 'email', 'phone']) {
        if (_users.any((u) => u[field] == user[field])) {
          throw AuthFailure('${field}_taken');
        }
      }
      user.addAll(await _hash(_password(body['password'])));
      _users.add(user);
      return _session(user);
    }
    if (method == 'POST' && path == '/auth/login') {
      final login = _text(body['login'], 254).toLowerCase();
      if (login.isEmpty ||
          body['password'] is! String ||
          (body['password'] as String).length > 128) {
        throw const AuthFailure('invalid_credentials');
      }
      final failed = _attempts[login] as Map<String, dynamic>?;
      final time = now().millisecondsSinceEpoch;
      if (failed != null && (failed['until'] as int) > time) {
        throw const AuthFailure('rate_limited');
      }
      final user = _users
          .cast<Map<String, dynamic>>()
          .where((u) => u['username'] == login || u['email'] == login)
          .firstOrNull;
      if (user == null || !await _verify(body['password'], user)) {
        if (_attempts.length > 200) _attempts.clear();
        final count = failed == null || (failed['until'] as int) > 0
            ? 1
            : (failed['count'] as int) + 1;
        _attempts[login] = {
          'count': count,
          'until': count >= 5
              ? time + const Duration(seconds: 30).inMilliseconds
              : 0,
        };
        throw const AuthFailure('invalid_credentials');
      }
      if (user['status'] != 'active') {
        throw const AuthFailure('account_suspended');
      }
      _attempts.remove(login);
      return _session(user);
    }
    if (method == 'GET' && path == '/auth/me') {
      return {'user': _public(await _authorize(token))};
    }
    if (method == 'POST' && path == '/auth/logout') {
      if (token != null) {
        final hash = await _tokenHash(token);
        _sessions.removeWhere((s) => s['hash'] == hash);
      }
      return {'ok': true};
    }
    if (method == 'POST' && path == '/auth/password') {
      final user = await _authorize(token);
      final current = body['currentPassword'];
      if (current is! String ||
          current.length > 128 ||
          !await _verify(current, user)) {
        throw const AuthFailure('invalid_credentials');
      }
      final next = _password(body['newPassword']);
      if (next == current) throw const AuthFailure('password_unchanged');
      user.addAll(await _hash(next));
      _sessions.removeWhere((s) => s['userId'] == user['id']);
      return _session(user);
    }
    if (method == 'GET' && path == '/admin/users') {
      await _authorize(token, admin: true);
      return {
        'users': _users
            .cast<Map<String, dynamic>>()
            .map(_public)
            .toList()
            .reversed
            .toList(),
      };
    }
    if (method == 'PATCH' && path.startsWith('/admin/users/')) {
      final admin = await _authorize(token, admin: true);
      if (body.keys.any((key) => key != 'status') ||
          !['active', 'suspended'].contains(body['status'])) {
        throw const AuthFailure('invalid_input');
      }
      final id = Uri.decodeComponent(path.substring('/admin/users/'.length));
      final target = _users
          .cast<Map<String, dynamic>>()
          .where((u) => u['id'] == id)
          .firstOrNull;
      if (target == null) throw const AuthFailure('not_found');
      if (target['role'] == 'admin' || target['id'] == admin['id']) {
        throw const AuthFailure('protected_account');
      }
      target['status'] = body['status'];
      if (body['status'] == 'suspended') {
        _sessions.removeWhere((s) => s['userId'] == id);
      }
      return {'user': _public(target)};
    }
    throw const AuthFailure('not_found');
  }
}
