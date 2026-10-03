import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../config/app_config.dart';
import '../core/api/api_client.dart';
import '../core/models/bootstrap_data.dart';
import '../core/storage/session_store.dart';

class AppController extends ChangeNotifier {
  AppController(this.api, this.sessions);

  final ApiClient api;
  final SessionStore sessions;
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool biometricAvailable = false;
  bool biometricEnabled = false;
  bool biometricAuthenticating = false;

  BootstrapData? bootstrap;
  Map<String, dynamic> liveBadges = <String, dynamic>{};
  final Map<String, Map<String, dynamic>> _formSchemaCache = <String, Map<String, dynamic>>{};
  Map<String, dynamic>? _voiceCommandsCache;
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
    biometricAvailable = await _checkBiometricAvailable();
    biometricEnabled = await sessions.biometricEnabled();

    if (token != null && token.isNotEmpty && !biometricEnabled) {
      try {
        await loadBootstrap();
      } catch (_) {
        await sessions.clear();
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<bool> _checkBiometricAvailable() async {
    try {
      return await _localAuth.isDeviceSupported() &&
          await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (biometricAuthenticating) return false;
    final token = await sessions.readToken();
    if (token == null || token.isEmpty) return false;

    biometricAuthenticating = true;
    error = null;
    notifyListeners();
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'استخدم البصمة للدخول إلى Neizami Operations',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (!ok) return false;
      await loadBootstrap();
      return true;
    } catch (exception) {
      error = 'تعذر تسجيل الدخول بالبصمة: $exception';
      return false;
    } finally {
      biometricAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> enableBiometricLogin() async {
    biometricAvailable = await _checkBiometricAvailable();
    if (!biometricAvailable) return;
    await sessions.setBiometricEnabled(true);
    biometricEnabled = true;
    notifyListeners();
  }

  Future<void> disableBiometricLogin() async {
    await sessions.setBiometricEnabled(false);
    biometricEnabled = false;
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
      biometricAvailable = await _checkBiometricAvailable();
      if (biometricAvailable) {
        await sessions.setBiometricEnabled(true);
        biometricEnabled = true;
      }
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

    // Home can render immediately. Dashboard counters refresh in parallel
    // instead of keeping login/splash blocked behind extra endpoints.
    // Let the first home frame render before starting secondary counters.
    Timer(const Duration(milliseconds: 450), () {
      if (bootstrap != null) unawaited(refreshDashboard());
    });
  }

  Future<void> refreshDashboard() async {
    if (refreshingDashboard || bootstrap == null) return;

    refreshingDashboard = true;
    notifyListeners();

    final next = <String, dynamic>{};

    await Future.wait([
      _loadNotificationBadges(next),
      _loadApprovalBadges(next),
    ]);

    if (bootstrap != null) {
      liveBadges = next;
    }
    refreshingDashboard = false;
    notifyListeners();
  }

  Future<void> _loadNotificationBadges(Map<String, dynamic> next) async {
    try {
      final notifications = await api.get(
        '/notifications',
        query: const {'scope': 'month'},
      );
      final payload = _payloadOf(notifications);
      final counts = _mapOf(payload['counts']);
      next.addAll(_notificationBadgeValues(counts));
    } catch (_) {
      // Keep Bootstrap counters when Notifier is temporarily unavailable.
    }
  }

  Future<void> _loadApprovalBadges(Map<String, dynamic> next) async {
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
  }

  void applyNotificationCounts(dynamic rawCounts) {
    final counts = _mapOf(rawCounts);
    if (counts.isEmpty) return;
    liveBadges = <String, dynamic>{
      ...liveBadges,
      ..._notificationBadgeValues(counts),
    };
    notifyListeners();
  }

  Map<String, dynamic> _notificationBadgeValues(
    Map<String, dynamic> counts,
  ) {
    return <String, dynamic>{
      'notifications': _intOf(counts['unread']),
      'stars': _intOf(counts['positive']),
      'warning_cards': _intOf(counts['warning']),
      'red_cards': _intOf(counts['red']),
    };
  }

  Future<Map<String, dynamic>> formSchema(String formKey, {bool refresh = false}) async {
    if (!refresh && _formSchemaCache.containsKey(formKey)) {
      return _formSchemaCache[formKey]!;
    }
    final data = await api.get('/forms/$formKey');
    _formSchemaCache[formKey] = data;
    return data;
  }

  Future<Map<String, dynamic>> voiceCommands({bool refresh = false}) async {
    if (!refresh && _voiceCommandsCache != null) return _voiceCommandsCache!;
    final data = await api.get('/voice/commands');
    _voiceCommandsCache = data;
    return data;
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
    _formSchemaCache.clear();
    _voiceCommandsCache = null;
    liveBadges = <String, dynamic>{};
    refreshingDashboard = false;
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
