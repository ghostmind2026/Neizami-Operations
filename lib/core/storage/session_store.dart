import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  static const _tokenKey = 'nzmb_token';
  static const _biometricKey = 'nzmb_biometric_enabled';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _cachedToken;
  bool _tokenLoaded = false;

  Future<String?> readToken() async {
    if (_tokenLoaded) return _cachedToken;
    _cachedToken = await _storage.read(key: _tokenKey);
    _tokenLoaded = true;
    return _cachedToken;
  }

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    _tokenLoaded = true;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<bool> biometricEnabled() async =>
      (await _storage.read(key: _biometricKey)) == '1';

  Future<void> setBiometricEnabled(bool enabled) =>
      _storage.write(key: _biometricKey, value: enabled ? '1' : '0');

  Future<void> clear() async {
    _cachedToken = null;
    _tokenLoaded = true;
    await _storage.deleteAll();
  }
}
