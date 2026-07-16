import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's Anthropic API key in the platform Keychain/Keystore.
class SecureStorageService {
  SecureStorageService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _apiKeyKey = 'anthropic_api_key';

  Future<String?> getApiKey() => _storage.read(key: _apiKeyKey);

  Future<void> setApiKey(String apiKey) =>
      _storage.write(key: _apiKeyKey, value: apiKey);

  Future<void> deleteApiKey() => _storage.delete(key: _apiKeyKey);
}
