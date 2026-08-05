import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  static const _tokenKey = 'nzmb_token';
  static const _biometricKey = 'nzmb_biometric_enabled';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<bool> biometricEnabled() async =>
      (await _storage.read(key: _biometricKey)) == '1';
  Future<void> setBiometricEnabled(bool enabled) =>
      _storage.write(key: _biometricKey, value: enabled ? '1' : '0');
  Future<void> clear() => _storage.deleteAll();
}
