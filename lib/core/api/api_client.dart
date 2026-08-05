import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../storage/session_store.dart';

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.method,
    this.uri,
    this.serverCode,
  });

  final String message;
  final int? statusCode;
  final String? method;
  final Uri? uri;
  final String? serverCode;

  @override
  String toString() {
    final details = <String>[
      if (serverCode != null && serverCode!.isNotEmpty) 'code=$serverCode',
      if (statusCode != null) 'status=$statusCode',
      if (method != null && uri != null) '$method $uri',
    ];
    return details.isEmpty ? message : '$message\n${details.join(' • ')}';
  }
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
      'X-Neizami-Mobile': '1',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final encodedBody = method == 'GET' ? null : jsonEncode(body ?? {});
    final primaryUri = AppConfig.uri(path, query);

    try {
      var result = await _execute(
        method: method,
        uri: primaryUri,
        headers: headers,
        encodedBody: encodedBody,
      );

      // Some WordPress/server configurations expose registered REST routes
      // reliably only through the official rest_route query parameter.
      if (_isRestRouteMismatch(result)) {
        final fallbackUri = AppConfig.restRouteUri(path, query);
        result = await _execute(
          method: method,
          uri: fallbackUri,
          headers: headers,
          encodedBody: encodedBody,
        );
      }

      return _decode(result.response, method: method, uri: result.finalUri);
    } on SocketException {
      throw const ApiException('تعذر الاتصال بالخادم. تحقق من الإنترنت.');
    } on FormatException {
      throw const ApiException('استجابة الخادم غير صالحة.');
    } on http.ClientException catch (exception) {
      throw ApiException('تعذر الاتصال بالخادم: ${exception.message}');
    }
  }

  Future<_HttpResult> _execute({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required String? encodedBody,
  }) {
    return _requestFollowingRedirects(
      method: method,
      initialUri: uri,
      headers: headers,
      encodedBody: encodedBody,
    );
  }

  Map<String, dynamic> _decode(
    http.Response response, {
    required String method,
    required Uri uri,
  }) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    final envelope = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};

    if (response.statusCode >= 400 || envelope['success'] == false) {
      final error = envelope['error'];
      final serverCode = '${envelope['code'] ?? (error is Map ? error['code'] : '')}';
      final message = error is Map
          ? '${error['message'] ?? envelope['message'] ?? 'تعذر تنفيذ الطلب.'}'
          : '${envelope['message'] ?? 'تعذر تنفيذ الطلب.'}';
      throw ApiException(
        message,
        statusCode: response.statusCode,
        method: method,
        uri: uri,
        serverCode: serverCode,
      );
    }

    final data = envelope['data'];
    return data is Map<String, dynamic> ? data : envelope;
  }

  bool _isRestRouteMismatch(_HttpResult result) {
    if (result.response.statusCode != 404) return false;
    try {
      final value = jsonDecode(result.response.body);
      if (value is! Map) return false;
      final code = '${value['code'] ?? ''}';
      final message = '${value['message'] ?? ''}'.toLowerCase();
      return code == 'rest_no_route' ||
          message.contains('no route was found') ||
          message.contains('request method');
    } catch (_) {
      return false;
    }
  }

  Future<_HttpResult> _requestFollowingRedirects({
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

      if (encodedBody != null) request.body = encodedBody;

      final streamed = await request.send().timeout(
            method == 'GET'
                ? const Duration(seconds: 30)
                : const Duration(seconds: 45),
          );
      final response = await http.Response.fromStream(streamed);

      if (!_isRedirect(response.statusCode)) {
        return _HttpResult(response, uri);
      }

      final location = response.headers['location'];
      if (location == null || location.trim().isEmpty) {
        return _HttpResult(response, uri);
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

class _HttpResult {
  const _HttpResult(this.response, this.finalUri);

  final http.Response response;
  final Uri finalUri;
}
