import 'package:dndtoolkit_flutter/models/ai_character_models.dart';
import 'package:dndtoolkit_flutter/models/ai_service_config.dart';
import 'package:dndtoolkit_flutter/models/character.dart';
import 'package:dndtoolkit_flutter/pages/ai_character_creation_page.dart';
import 'package:dndtoolkit_flutter/services/ai_character_service.dart';
import 'package:dndtoolkit_flutter/services/ai_config_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('人物塑造的无需添加开关会收起全部输入', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ai_character_disclosure_accepted_v1': true,
    });
    final repository = AiConfigRepository(secretStore: _MemorySecretStore());
    await repository.saveConfig(
      const AiServiceConfig(
        id: 'config',
        name: '测试配置',
        provider: AiProviderKind.deepSeek,
        baseUrl: AiServiceConfig.deepSeekBaseUrl,
        model: 'deepseek-v4-flash',
        thinkingEnabled: false,
        reasoningEffort: 'high',
      ),
      apiKey: 'fake-key',
    );

    await tester.pumpWidget(
      MaterialApp(home: AiCharacterCreationPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('无需添加'),
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('年龄'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(find.text('年龄'), findsNothing);
    expect(find.text('人物塑造'), findsOneWidget);
  });

  testWidgets('核心引导默认不勾选由 AI 决定', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ai_character_disclosure_accepted_v1': true,
    });
    final repository = AiConfigRepository(secretStore: _MemorySecretStore());
    await repository.saveConfig(
      const AiServiceConfig(
        id: 'config',
        name: '测试配置',
        provider: AiProviderKind.deepSeek,
        baseUrl: AiServiceConfig.deepSeekBaseUrl,
        model: 'deepseek-v4-flash',
        thinkingEnabled: false,
        reasoningEffort: 'high',
      ),
      apiKey: 'fake-key',
    );

    await tester.pumpWidget(
      MaterialApp(home: AiCharacterCreationPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    final firstCheckbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(firstCheckbox.value, isFalse);
    expect(find.text('角色姓名 *'), findsOneWidget);
    expect(find.text('AI将严格遵循你填写的内容'), findsWidgets);
  });

  testWidgets('由 AI 决定重新勾选后会清除旧的必填错误', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ai_character_disclosure_accepted_v1': true,
    });
    final repository = AiConfigRepository(secretStore: _MemorySecretStore());
    await repository.saveConfig(
      const AiServiceConfig(
        id: 'config',
        name: '测试配置',
        provider: AiProviderKind.deepSeek,
        baseUrl: AiServiceConfig.deepSeekBaseUrl,
        model: 'deepseek-v4-flash',
        thinkingEnabled: false,
        reasoningEffort: 'high',
      ),
      apiKey: 'fake-key',
    );
    await tester.pumpWidget(
      MaterialApp(home: AiCharacterCreationPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    final firstCheckbox = find.byType(Checkbox).first;
    final firstAiLabel = find.text('由AI决定').first;
    tester.state<FormState>(find.byType(Form)).validate();
    await tester.pump();
    expect(find.textContaining('请填写角色姓名'), findsOneWidget);

    await tester.ensureVisible(firstAiLabel);
    await tester.pumpAndSettle();
    await tester.tap(firstAiLabel);
    await tester.pumpAndSettle();
    expect(find.textContaining('请填写角色姓名'), findsNothing);
    expect(tester.widget<Checkbox>(firstCheckbox).value, isTrue);
  });

  testWidgets('六维策略弹窗仅提供确认进入编辑器', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ai_character_disclosure_accepted_v1': true,
    });
    final repository = AiConfigRepository(secretStore: _MemorySecretStore());
    await repository.saveConfig(
      const AiServiceConfig(
        id: 'config',
        name: '测试配置',
        provider: AiProviderKind.deepSeek,
        baseUrl: AiServiceConfig.deepSeekBaseUrl,
        model: 'deepseek-v4-flash',
        thinkingEnabled: false,
        reasoningEffort: 'high',
      ),
      apiKey: 'fake-key',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AiCharacterCreationPage(
          repository: repository,
          service: _ImmediateAiService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var index = 0; index < 5; index++) {
      final toggle = find.text('由AI决定').at(index);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
    }
    final submit = find.text('生成角色草稿');
    await tester.dragUntilVisible(
      submit,
      find.byType(ListView),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('确认六维加点策略'), findsOneWidget);
    expect(find.text('返回修改'), findsNothing);
    expect(find.text('确认并进入编辑器'), findsOneWidget);
  });
}

class _ImmediateAiService extends AiCharacterService {
  @override
  Future<({Character character, AiAbilityBreakdown abilities})> generate(
    AiServiceConfig config,
    String apiKey,
    AiCharacterBuildRequest request,
  ) async {
    const scores = AbilityScores(
      strength: 15,
      dexterity: 14,
      constitution: 13,
      intelligence: 12,
      wisdom: 10,
      charisma: 8,
    );
    const zero = AbilityScores(
      strength: 0,
      dexterity: 0,
      constitution: 0,
      intelligence: 0,
      wisdom: 0,
      charisma: 0,
    );
    return (
      character: Character(),
      abilities: const AiAbilityBreakdown(
        base: scores,
        racialBonuses: zero,
        advancementAdjustments: zero,
        finalScores: scores,
      ),
    );
  }
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
