import 'package:dndtoolkit_flutter/models/ai_service_config.dart';
import 'package:dndtoolkit_flutter/services/ai_config_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
