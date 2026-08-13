import 'package:dndtoolkit_flutter/models/ai_service_config.dart';
import 'package:dndtoolkit_flutter/services/ai_config_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native providers are listed before OpenAI-compatible services', () {
    expect(AiProviderKind.values, [
      AiProviderKind.deepSeek,
      AiProviderKind.kimi,
      AiProviderKind.mimo,
      AiProviderKind.openAiCompatible,
    ]);
  });

  test('Kimi configurations always use the mainland China API', () {
    final config = AiServiceConfig.fromJson({
      'id': 'kimi',
      'name': 'Kimi',
      'provider': 'kimi',
      'baseUrl': 'https://unsupported.example/v1',
      'model': 'kimi-k3',
      'thinkingEnabled': true,
      'reasoningEffort': 'high',
    });

    expect(config.baseUrl, AiServiceConfig.kimiBaseUrl);
    expect(config.effectiveBaseUrl, AiServiceConfig.kimiBaseUrl);
    expect(config.toJson()['baseUrl'], AiServiceConfig.kimiBaseUrl);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stores named metadata separately from API keys', () async {
    final secrets = _MemorySecretStore();
    final repository = AiConfigRepository(secretStore: secrets);
    const config = AiServiceConfig(
      id: 'one',
      name: '日常建卡',
      provider: AiProviderKind.deepSeek,
      baseUrl: AiServiceConfig.deepSeekBaseUrl,
      model: 'deepseek-v4-flash',
      thinkingEnabled: true,
      reasoningEffort: 'high',
    );

    await repository.saveConfig(config, apiKey: 'secret-value');
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('ai_service_configs_v1'),
      isNot(contains('secret-value')),
    );
    expect(await repository.readApiKey(config.id), 'secret-value');
    expect((await repository.loadConfigs()).single.name, '日常建卡');

    await repository.saveConfig(config.copyWith(model: 'another-model'));
    expect(await repository.readApiKey(config.id), 'secret-value');

    await repository.deleteConfig(config.id);
    expect(await repository.loadConfigs(), isEmpty);
    expect(await repository.readApiKey(config.id), isNull);
  });

  test('rejects duplicate configuration names', () async {
    final repository = AiConfigRepository(secretStore: _MemorySecretStore());
    const first = AiServiceConfig(
      id: 'one',
      name: '配置 A',
      provider: AiProviderKind.deepSeek,
      baseUrl: AiServiceConfig.deepSeekBaseUrl,
      model: 'model',
      thinkingEnabled: false,
      reasoningEffort: 'high',
    );
    await repository.saveConfig(first, apiKey: 'key');
    await repository.saveConfig(first.copyWith(model: 'updated-model'));
    const duplicate = AiServiceConfig(
      id: 'two',
      name: '配置 A',
      provider: AiProviderKind.openAiCompatible,
      baseUrl: 'https://example.com/v1',
      model: 'model',
      thinkingEnabled: false,
      reasoningEffort: 'medium',
    );
    await expectLater(
      repository.saveConfig(duplicate, apiKey: 'key2'),
      throwsFormatException,
    );
  });

  test(
    'supports native DeepSeek, Kimi, and MiMo configuration metadata',
    () async {
      final repository = AiConfigRepository(secretStore: _MemorySecretStore());
      const configs = [
        AiServiceConfig(
          id: 'deepseek',
          name: 'DeepSeek low',
          provider: AiProviderKind.deepSeek,
          baseUrl: AiServiceConfig.deepSeekBaseUrl,
          model: 'deepseek-v4-flash',
          thinkingEnabled: true,
          reasoningEffort: 'low',
        ),
        AiServiceConfig(
          id: 'kimi',
          name: 'Kimi K3',
          provider: AiProviderKind.kimi,
          baseUrl: AiServiceConfig.kimiBaseUrl,
          model: 'kimi-k3',
          thinkingEnabled: true,
          reasoningEffort: 'max',
        ),
        AiServiceConfig(
          id: 'mimo',
          name: 'MiMo',
          provider: AiProviderKind.mimo,
          baseUrl: AiServiceConfig.mimoBaseUrl,
          model: 'mimo-v2.5-pro',
          thinkingEnabled: true,
          reasoningEffort: 'high',
        ),
      ];

      for (final config in configs) {
        await repository.saveConfig(config, apiKey: 'key-${config.id}');
      }

      final loaded = await repository.loadConfigs();
      expect(loaded.map((config) => config.provider), [
        AiProviderKind.deepSeek,
        AiProviderKind.kimi,
        AiProviderKind.mimo,
      ]);
      expect(loaded.first.allowedReasoningEfforts, ['low', 'high', 'max']);
      expect(loaded[1].thinkingAlwaysEnabled, isTrue);
      expect(loaded[2].supportsReasoningEffort, isFalse);
    },
  );
}

class _MemorySecretStore implements AiSecretStore {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
