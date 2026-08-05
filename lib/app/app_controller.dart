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
  bool loading = true;
  String? error;

  bool get authenticated => bootstrap != null;

  Future<void> initialize() async {
    loading = true;
    notifyListeners();
    final token = await sessions.readToken();
    if (token != null) {
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
      await sessions.saveToken('${data['token']}');
      await loadBootstrap();
    } catch (exception) {
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
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {}
    await sessions.clear();
    bootstrap = null;
    notifyListeners();
  }
}
