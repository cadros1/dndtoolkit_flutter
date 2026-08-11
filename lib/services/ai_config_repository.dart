import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_service_config.dart';

class AiConfigException implements Exception {
  const AiConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AiSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureAiSecretStore implements AiSecretStore {
  const SecureAiSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class AiConfigRepository {
  AiConfigRepository({AiSecretStore? secretStore})
    : _secretStore = secretStore ?? const SecureAiSecretStore();

  static const _configsKey = 'ai_service_configs_v1';
  static const _lastConfigKey = 'ai_last_config_id';
  static const _disclosureKey = 'ai_character_disclosure_accepted_v1';
  static const _secretPrefix = 'ai_service_api_key_';

  final AiSecretStore _secretStore;

  Future<List<AiServiceConfig>> loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException();
      return decoded
          .map((item) {
            if (item is! Map) throw const FormatException();
            return AiServiceConfig.fromJson(Map<String, dynamic>.from(item));
          })
          .toList(growable: false);
    } on FormatException {
      throw const AiConfigException('AI 服务配置已损坏，请重新配置');
    }
  }

  Future<void> saveConfig(AiServiceConfig config, {String? apiKey}) async {
    final configs = [...await loadConfigs()];
    final duplicateName = configs.any(
      (item) =>
          item.id != config.id &&
          item.name.trim().toLowerCase() == config.name.trim().toLowerCase(),
    );
    if (duplicateName) throw const FormatException('配置名不能重复');

    final index = configs.indexWhere((item) => item.id == config.id);
    if (index < 0) {
      configs.add(config);
    } else {
      configs[index] = config;
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _configsKey,
      jsonEncode(configs.map((item) => item.toJson()).toList()),
    );
    if (!saved) throw const AiConfigException('AI 服务配置保存失败');

    final normalizedKey = apiKey?.trim();
    if (normalizedKey != null && normalizedKey.isNotEmpty) {
      await _secretStore.write(_secretKey(config.id), normalizedKey);
    }
  }

  Future<void> deleteConfig(String id) async {
    final configs = [...await loadConfigs()]
      ..removeWhere((item) => item.id == id);
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _configsKey,
      jsonEncode(configs.map((item) => item.toJson()).toList()),
    );
    if (!saved) throw const AiConfigException('AI 服务配置删除失败');
    await _secretStore.delete(_secretKey(id));
    if (prefs.getString(_lastConfigKey) == id) {
      await prefs.remove(_lastConfigKey);
    }
  }

  Future<String?> readApiKey(String configId) =>
      _secretStore.read(_secretKey(configId));

  Future<String?> getLastConfigId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastConfigKey);
  }

  Future<void> setLastConfigId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_lastConfigKey, id)) {
      throw const AiConfigException('默认 AI 服务配置保存失败');
    }
  }

  Future<bool> hasAcceptedDisclosure() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_disclosureKey) ?? false;
  }

  Future<void> acceptDisclosure() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_disclosureKey, true)) {
      throw const AiConfigException('AI 建卡提示状态保存失败');
    }
  }

  static String _secretKey(String configId) => '$_secretPrefix$configId';
}
