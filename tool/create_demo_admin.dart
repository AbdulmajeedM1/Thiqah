import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

// Generates only the initial offline project administrator verifier, never a
// plaintext password in the APK. Does not replace an existing seed or account.
Future<void> main() async {
  final file = File('assets/demo_admin.json');
  if (await file.exists()) {
    stderr.writeln('Admin seed already exists; leaving it unchanged.');
    exitCode = 1;
    return;
  }
  final random = Random.secure();
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  final password =
      'Trust-${List.generate(12, (_) => alphabet[random.nextInt(alphabet.length)]).join()}!9';
  final salt = List<int>.generate(16, (_) => random.nextInt(256));
  final key = await Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 600000,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'id': 'local-admin',
      'fullName': 'مدير ثقة',
      'username': 'admin',
      'email': 'admin@trust.local',
      'phone': '',
      'city': 'الرياض',
      'role': 'admin',
      'status': 'active',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'salt': base64UrlEncode(salt),
      'iterations': 600000,
      'passwordHash': base64UrlEncode(await key.extractBytes()),
    }),
  );
  stdout.writeln('Username: admin');
  stdout.writeln('Password: $password');
}
