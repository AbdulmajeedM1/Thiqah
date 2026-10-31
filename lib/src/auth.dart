import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Account {
  const Account({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.phone,
    required this.city,
    required this.role,
    required this.status,
    required this.createdAt,
  });
  final String id,
      fullName,
      username,
      email,
      phone,
      city,
      role,
      status,
      createdAt;
  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    fullName: json['fullName'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String? ?? '',
    city: json['city'] as String? ?? '',
    role: json['role'] as String,
    status: json['status'] as String,
    createdAt: json['createdAt'] as String? ?? '',
  );
}

class AuthFailure implements Exception {
  const AuthFailure(this.code);
  final String code;
}

abstract interface class TokenVault {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureTokenVault implements TokenVault {
  const SecureTokenVault();
  static const _storage = FlutterSecureStorage();
  static const _key = 'thiqah.auth.session.v1';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// Local account repository contract. No network transport is used.
abstract class AuthApi {
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  });
}

class AuthController extends ChangeNotifier {
  AuthController({
    required this.api,
    TokenVault? vault,
    this.onAuthenticated,
    this.onLogout,
  }) : vault = vault ?? const SecureTokenVault();
  final AuthApi api;
  final TokenVault vault;
  final Future<void> Function(Account account)? onAuthenticated;
  final Future<void> Function()? onLogout;
  Account? user;
  bool busy = false, initializing = false;
  String? errorCode;
  String? _token;

  void clearError() {
    errorCode = null;
    notifyListeners();
  }

  Future<void> restore() async {
    initializing = true;
    notifyListeners();
    try {
      final token = await vault.read();
      if (token == null) return;
      final data = await api.request('GET', '/auth/me', token: token);
      final account = Account.fromJson(Map<String, dynamic>.from(data['user']));
      await onAuthenticated?.call(account);
      _token = token;
      user = account;
    } on AuthFailure catch (e) {
      if (e.code == 'unauthorized' || e.code == 'account_suspended') {
        await vault.delete();
      }
      errorCode = e.code;
    } catch (_) {
      errorCode = 'secure_storage_failed';
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<bool> _submit(String path, Map<String, dynamic> body) async {
    if (busy) return false;
    busy = true;
    errorCode = null;
    notifyListeners();
    String? issuedToken;
    try {
      final data = await api.request('POST', path, body: body);
      final account = Account.fromJson(Map<String, dynamic>.from(data['user']));
      issuedToken = data['token'] as String;
      await vault.write(issuedToken);
      await onAuthenticated?.call(account);
      _token = issuedToken;
      user = account;
      return true;
    } on AuthFailure catch (e) {
      errorCode = e.code;
    } catch (_) {
      errorCode = 'secure_storage_failed';
    } finally {
      if (user == null && issuedToken != null) {
        try {
          await api.request('POST', '/auth/logout', token: issuedToken);
        } catch (_) {
          /* Local token still expires. */
        }
        try {
          await vault.delete();
        } catch (_) {
          /* Report the original storage failure. */
        }
      }
      busy = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> login(String login, String password) =>
      _submit('/auth/login', {'login': login.trim(), 'password': password});
  Future<bool> register(Map<String, dynamic> data) =>
      _submit('/auth/register', data);

  Future<Map<String, dynamic>> _authorized(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (_token == null) throw const AuthFailure('unauthorized');
    try {
      return await api.request(method, path, body: body, token: _token);
    } on AuthFailure catch (e) {
      if (e.code == 'unauthorized' || e.code == 'account_suspended') {
        await _clearLocal();
        errorCode = e.code;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> _clearLocal() async {
    _token = null;
    user = null;
    try {
      await vault.delete();
    } finally {
      await onLogout?.call();
    }
  }

  Future<void> logout() async {
    if (busy) return;
    busy = true;
    errorCode = null;
    notifyListeners();
    try {
      if (_token != null) {
        try {
          await api.request('POST', '/auth/logout', token: _token);
        } on AuthFailure {
          /* Offline logout still removes local access. */
        }
      }
      await _clearLocal();
    } catch (_) {
      errorCode = 'secure_storage_failed';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(String current, String next) async {
    if (busy) return false;
    busy = true;
    errorCode = null;
    notifyListeners();
    try {
      final data = await _authorized(
        'POST',
        '/auth/password',
        body: {'currentPassword': current, 'newPassword': next},
      );
      final token = data['token'] as String;
      await vault.write(token);
      _token = token;
      user = Account.fromJson(Map<String, dynamic>.from(data['user']));
      return true;
    } on AuthFailure catch (e) {
      errorCode = e.code;
    } catch (_) {
      // Repository rotated the token. Require login if it cannot be stored safely.
      await _clearLocal();
      errorCode = 'secure_storage_failed';
    } finally {
      busy = false;
      notifyListeners();
    }
    return false;
  }

  Future<List<Account>> listUsers() async {
    final data = await _authorized('GET', '/admin/users');
    return (data['users'] as List)
        .map((j) => Account.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  Future<void> setUserStatus(String id, String status) async {
    await _authorized(
      'PATCH',
      '/admin/users/${Uri.encodeComponent(id)}',
      body: {'status': status},
    );
  }
}

String authErrorText(String code, bool english) {
  final messages = <String, (String, String)>{
    'invalid_credentials': (
      'اسم المستخدم أو كلمة المرور غير صحيحة.',
      'Incorrect username or password.',
    ),
    'unauthorized': (
      'انتهت الجلسة، سجّل الدخول مجددًا.',
      'Session expired. Please sign in again.',
    ),
    'account_suspended': (
      'الحساب موقوف. تواصل مع مدير المنصة.',
      'This account is suspended. Contact the administrator.',
    ),
    'email_taken': (
      'البريد الإلكتروني مستخدم مسبقًا.',
      'This email is already registered.',
    ),
    'username_taken': (
      'اسم المستخدم مستخدم مسبقًا.',
      'This username is already taken.',
    ),
    'phone_taken': (
      'رقم الجوال مستخدم مسبقًا.',
      'This phone number is already registered.',
    ),
    'duplicate_account': (
      'هذه البيانات مرتبطة بحساب موجود.',
      'These details belong to an existing account.',
    ),
    'invalid_input': (
      'تحقق من البيانات المدخلة.',
      'Please check the information you entered.',
    ),
    'invalid_password': (
      'كلمة المرور الحالية غير صحيحة أو الجديدة لا تستوفي الشروط.',
      'Check your current password and the new password requirements.',
    ),
    'password_unchanged': (
      'اختر كلمة مرور مختلفة عن الحالية.',
      'Choose a different password.',
    ),
    'terms_required': (
      'الموافقة على شروط الاستخدام مطلوبة.',
      'You must accept the terms.',
    ),
    'rate_limited': (
      'محاولات كثيرة. انتظر قليلًا ثم حاول مجددًا.',
      'Too many attempts. Wait a moment and try again.',
    ),
    'forbidden': (
      'ليست لديك صلاحية لهذه العملية.',
      'You do not have permission for this action.',
    ),
    'protected_account': (
      'لا يمكن إيقاف حساب المدير.',
      'Administrator accounts cannot be suspended.',
    ),
    'local_data_unavailable': (
      'تعذر قراءة أو حفظ الحسابات على الجهاز. أعد المحاولة.',
      'Could not read or save accounts on this device. Please try again.',
    ),
    'secure_storage_failed': (
      'تعذر حفظ الجلسة بأمان. أعد تسجيل الدخول.',
      'Could not securely save the session. Please sign in again.',
    ),
  };
  final message =
      messages[code] ??
      (
        'تعذر إتمام العملية. حاول مرة أخرى.',
        'Unable to complete the operation. Please try again.',
      );
  return english ? message.$2 : message.$1;
}
