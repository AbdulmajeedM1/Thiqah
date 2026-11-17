import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'auth.dart';

const apiBaseUrl = String.fromEnvironment(
  'THIQAH_API_URL',
  defaultValue:
      'https://thiqah-abdulmajeed.pipedpassionflower2.chatgpt.site/api',
);

class RemoteApi extends AuthApi {
  RemoteApi({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  String? sessionToken;
  Future<void> Function(String code)? onUnauthorized;
  Map<String, String> get headers => {
    if (sessionToken != null) 'Authorization': 'Bearer $sessionToken',
  };

  Map<String, dynamic> decode(http.Response response) {
    Map<String, dynamic> data;
    try {
      data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const AuthFailure('network_error');
    }
    if (response.statusCode >= 400) {
      throw AuthFailure(data['error'] as String? ?? 'server_error');
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final request = http.Request(method, Uri.parse('$apiBaseUrl$path'));
    request.headers.addAll(headers);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 30)),
      );
      final data = decode(response);
      if (data['token'] is String) sessionToken = data['token'];
      if (path == '/auth/me') sessionToken = token;
      return data;
    } on AuthFailure catch (error) {
      if (sessionToken != null &&
          (error.code == 'unauthorized' || error.code == 'account_suspended')) {
        await onUnauthorized?.call(error.code);
      }
      rethrow;
    } catch (_) {
      throw const AuthFailure('network_error');
    }
  }

  Future<Map<String, dynamic>> upload(String name, Uint8List bytes) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/uploads'))
          ..headers.addAll(headers)
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: name),
          );
    try {
      return decode(
        await http.Response.fromStream(
          await client.send(request).timeout(const Duration(minutes: 2)),
        ),
      );
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('network_error');
    }
  }

  Future<Uint8List> download(String id) async {
    try {
      final response = await client
          .get(Uri.parse('$apiBaseUrl/uploads/$id'), headers: headers)
          .timeout(const Duration(minutes: 2));
      if (response.statusCode != 200) decode(response);
      return response.bodyBytes;
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('network_error');
    }
  }
}
