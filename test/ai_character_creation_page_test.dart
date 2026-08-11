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

    await tester.tap(find.byKey(const ValueKey('omit-roleplay-switch')));
    await tester.pumpAndSettle();

    expect(find.text('年龄'), findsNothing);
    expect(find.text('人物塑造'), findsOneWidget);
  });

  testWidgets('建卡要求默认显示四项确定选项和玩法偏好', (tester) async {
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

    final modeSwitch = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('generate-from-description-switch')),
    );
    expect(modeSwitch.value, isFalse);
    expect(find.text('角色描述 *'), findsNothing);
    expect(find.text('职业 *'), findsOneWidget);
    expect(find.text('种族 *'), findsOneWidget);
    expect(find.text('背景 *'), findsOneWidget);
    expect(find.text('阵营 *'), findsOneWidget);
    expect(find.text('玩法偏好 *'), findsOneWidget);
    final classDecorator = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const ValueKey('classAndSubclass-choice-field')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(classDecorator.decoration.helperText, isNull);
  });

  testWidgets('从想法生成会切换必填字段并保留两种模式的输入', (tester) async {
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

    await tester.enterText(
      find.byKey(const ValueKey('classAndSubclass-choice-field')),
      '战士（奥法骑士）',
    );
    tester.state<FormState>(find.byType(Form)).validate();
    await tester.pump();
    expect(find.text('此项为必填项'), findsNWidgets(4));

    final modeSwitch = find.byKey(
      const ValueKey('generate-from-description-switch'),
    );
    await tester.ensureVisible(modeSwitch);
    await tester.pumpAndSettle();
    await tester.tap(modeSwitch);
    await tester.pumpAndSettle();
    expect(find.text('职业 *'), findsNothing);
    expect(find.text('角色描述 *'), findsOneWidget);
    expect(find.text('描述你想要扮演的角色'), findsOneWidget);
    expect(find.text('玩法偏好 *'), findsOneWidget);

    tester.state<FormState>(find.byType(Form)).validate();
    await tester.pump();
    expect(find.text('此项为必填项'), findsNWidgets(2));
    await tester.enterText(
      find.byKey(const ValueKey('character-description-field')),
      '想扮演能使用魔法保护队友的前排战士',
    );

    await tester.tap(modeSwitch);
    await tester.pumpAndSettle();
    final restoredClassField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('classAndSubclass-choice-field')),
    );
    expect(restoredClassField.controller?.text, '战士（奥法骑士）');
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

    final modeSwitch = find.byKey(
      const ValueKey('generate-from-description-switch'),
    );
    await tester.ensureVisible(modeSwitch);
    await tester.tap(modeSwitch);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('character-description-field')),
      '想扮演保护同伴的自然施法者',
    );
    await tester.enterText(
      find.byKey(const ValueKey('gameplay-preference-field')),
      '保持距离，优先支援和控制敌人',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final submit = find.text('生成角色草稿');
    await tester.ensureVisible(submit);
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
