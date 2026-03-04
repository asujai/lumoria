import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();

  factory SecureStorageService() {
    return _instance;
  }

  SecureStorageService._internal();

  final _storage = const FlutterSecureStorage();

  static const _apiKeyKey = 'GEMINI_API_KEY';

  final ValueNotifier<bool> hasApiKeyNotifier = ValueNotifier<bool>(false);

  Future<void> init() async {
    final key = await getApiKey();
    hasApiKeyNotifier.value = key != null && key.isNotEmpty;
  }

  Future<void> saveApiKey(String apiKey) async {
    await _storage.write(key: _apiKeyKey, value: apiKey);
    hasApiKeyNotifier.value = true;
  }

  Future<String?> getApiKey() async {
    return await _storage.read(key: _apiKeyKey);
  }

  Future<void> deleteApiKey() async {
    await _storage.delete(key: _apiKeyKey);
    hasApiKeyNotifier.value = false;
  }

  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    final exists = key != null && key.isNotEmpty;
    hasApiKeyNotifier.value = exists;
    return exists;
  }
}
