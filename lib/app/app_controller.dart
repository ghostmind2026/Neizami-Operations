import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../core/api/api_client.dart';
import '../core/models/bootstrap_data.dart';
import '../core/storage/session_store.dart';

class AppController extends ChangeNotifier {
  AppController(this.api, this.sessions);

  final ApiClient api;
  final SessionStore sessions;

  BootstrapData? bootstrap;
  Map<String, dynamic> liveBadges = <String, dynamic>{};
  bool loading = true;
  bool refreshingDashboard = false;
  String? error;

  bool get authenticated => bootstrap != null;

  Map<String, dynamic> get dashboardBadges {
    return <String, dynamic>{
      ...?bootstrap?.badges,
      ...liveBadges,
    };
  }

  Future<void> initialize() async {
    loading = true;
    notifyListeners();
    final token = await sessions.readToken();
    if (token != null && token.isNotEmpty) {
      try {
        await loadBootstrap();
      } catch (_) {
        await sessions.clear();
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    error = null;
    loading = true;
    notifyListeners();
    try {
      final data = await api.post('/auth/login', body: {
        'username': username,
        'password': password,
        'device': {
          'app_id': AppConfig.appId,
          'platform': 'android',
        },
      });

      final tokenPayload = data['token'];
      final accessToken = tokenPayload is Map
          ? '${tokenPayload['access_token'] ?? ''}'.trim()
          : '${data['access_token'] ?? tokenPayload ?? ''}'.trim();

      if (accessToken.isEmpty || accessToken == 'null') {
        throw const ApiException(
          'استجابة تسجيل الدخول لا تحتوي رمز دخول صالحًا.',
        );
      }

      await sessions.saveToken(accessToken);
      await loadBootstrap();
    } catch (exception) {
      await sessions.clear();
      error = '$exception';
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadBootstrap() async {
    bootstrap = BootstrapData.fromJson(await api.get('/bootstrap'));
    notifyListeners();
    await refreshDashboard();
  }

  Future<void> refreshDashboard() async {
    if (refreshingDashboard || bootstrap == null) return;

    refreshingDashboard = true;
    notifyListeners();

    final next = <String, dynamic>{};

    try {
      final notifications = await api.get(
        '/notifications',
        query: const {'scope': 'month'},
      );
      final payload = _payloadOf(notifications);
      final counts = _mapOf(payload['counts']);
      next.addAll({
        'notifications': _intOf(counts['unread']),
        'stars': _intOf(counts['positive']),
        'warning_cards': _intOf(counts['warning']),
        'red_cards': _intOf(counts['red']),
      });
    } catch (_) {
      // Keep Bootstrap counters when Notifier is temporarily unavailable.
    }

    try {
      final approvals = await api.get(
        '/approvals',
        query: const {'scope': 'all'},
      );
      final payload = _payloadOf(approvals);
      final counts = _mapOf(payload['counts']);
      next.addAll({
        'my_approvals': _intOf(counts['my_requests']),
        'manager_approvals': _intOf(counts['my_approvals']),
      });
    } catch (_) {
      // Keep Bootstrap counters when Approvals is temporarily unavailable.
    }

    liveBadges = next;
    refreshingDashboard = false;
    notifyListeners();
  }

  Future<void> refreshAll() async {
    bootstrap = BootstrapData.fromJson(await api.get('/bootstrap'));
    liveBadges = <String, dynamic>{};
    notifyListeners();
    await refreshDashboard();
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {}
    await sessions.clear();
    bootstrap = null;
    liveBadges = <String, dynamic>{};
    notifyListeners();
  }

  Map<String, dynamic> _payloadOf(Map<String, dynamic> response) {
    return _mapOf(response['payload']).isNotEmpty
        ? _mapOf(response['payload'])
        : response;
  }

  Map<String, dynamic> _mapOf(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int _intOf(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
