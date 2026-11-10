import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  const SessionStorage();
  static const _storage = FlutterSecureStorage();
  Future<String?> read() => _storage.read(key: 'pvg_customer_session_v1');
  Future<void> write(String value) =>
      _storage.write(key: 'pvg_customer_session_v1', value: value);
  Future<void> clear() => _storage.delete(key: 'pvg_customer_session_v1');
}
