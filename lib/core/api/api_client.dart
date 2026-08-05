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
      'Content-Type': 'application/json; charset=utf-8',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await _requestFollowingRedirects(
        method: method,
        initialUri: AppConfig.uri(path, query),
        headers: headers,
        encodedBody: method == 'GET' ? null : jsonEncode(body ?? {}),
      );

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
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
    } on http.ClientException catch (exception) {
      throw ApiException('تعذر الاتصال بالخادم: ${exception.message}');
    }
  }

  Future<http.Response> _requestFollowingRedirects({
    required String method,
    required Uri initialUri,
    required Map<String, String> headers,
    required String? encodedBody,
  }) async {
    var uri = initialUri;

    for (var redirectCount = 0; redirectCount <= 5; redirectCount++) {
      final request = http.Request(method, uri)
        ..followRedirects = false
        ..headers.addAll(headers);

      if (encodedBody != null) {
        request.body = encodedBody;
      }

      final streamed = await request.send().timeout(
            method == 'GET'
                ? const Duration(seconds: 30)
                : const Duration(seconds: 45),
          );
      final response = await http.Response.fromStream(streamed);

      if (!_isRedirect(response.statusCode)) {
        return response;
      }

      final location = response.headers['location'];
      if (location == null || location.trim().isEmpty) {
        return response;
      }

      uri = uri.resolve(location.trim());
    }

    throw const ApiException('تجاوز الخادم عدد التحويلات المسموح بها.');
  }

  bool _isRedirect(int statusCode) {
    return statusCode == 301 ||
        statusCode == 302 ||
        statusCode == 303 ||
        statusCode == 307 ||
        statusCode == 308;
  }
}
