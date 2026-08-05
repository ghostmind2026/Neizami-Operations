import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../storage/session_store.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this.sessions);
  final SessionStore sessions;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => _send('POST', path, body: body, query: query);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    final token = await sessions.readToken();
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final uri = AppConfig.uri(path, query);
      final response = method == 'GET'
          ? await http.get(uri, headers: headers).timeout(const Duration(seconds: 30))
          : await http
              .post(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 45));

      final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
      final envelope = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};

      if (response.statusCode >= 400 || envelope['success'] == false) {
        final error = envelope['error'];
        final message = error is Map
            ? '${error['message'] ?? 'تعذر تنفيذ الطلب.'}'
            : '${envelope['message'] ?? 'تعذر تنفيذ الطلب.'}';
        throw ApiException(message, statusCode: response.statusCode);
      }

      final data = envelope['data'];
      return data is Map<String, dynamic> ? data : envelope;
    } on SocketException {
      throw const ApiException('تعذر الاتصال بالخادم. تحقق من الإنترنت.');
    } on FormatException {
      throw const ApiException('استجابة الخادم غير صالحة.');
    }
  }
}
