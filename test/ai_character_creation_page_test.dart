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

  testWidgets('角色总等级步进器限制为1至5级', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'ai_character_disclosure_accepted_v1': true,
    });
    final repository = AiConfigRepository(secretStore: _MemorySecretStore());
    await repository.saveConfig(
      const AiServiceConfig(
        id: 'config',
        name: '测试',
        provider: AiProviderKind.deepSeek,
        baseUrl: AiServiceConfig.deepSeekBaseUrl,
        model: '模型',
        thinkingEnabled: false,
        reasoningEffort: 'high',
      ),
      apiKey: 'fake-key',
    );

    await tester.pumpWidget(
      MaterialApp(home: AiCharacterCreationPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('total-level-field'));
    final decrease = find.byKey(const ValueKey('decrease-total-level-button'));
    final increase = find.byKey(const ValueKey('increase-total-level-button'));
    expect(find.text('角色总等级 *'), findsOneWidget);
    expect(find.text('最高可创建5级角色'), findsOneWidget);
    expect(tester.widget<TextFormField>(field).controller!.text, '1');
    expect(tester.widget<IconButton>(decrease).onPressed, isNull);

    for (var index = 0; index < 4; index++) {
      await tester.tap(increase);
      await tester.pump();
    }
    expect(tester.widget<TextFormField>(field).controller!.text, '5');
    expect(tester.widget<IconButton>(increase).onPressed, isNull);

    await tester.enterText(field, '6');
    tester.state<FormState>(find.byType(Form)).validate();
    await tester.pump();
    expect(find.text('请输入 1–5 的整数'), findsOneWidget);
  });

  testWidgets('附加特征属于外貌组且无需添加会收起全部输入', (tester) async {
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
    await tester.dragUntilVisible(
      find.text('附加特征'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('附加特征'), findsOneWidget);

    final appearanceSwitch = find.byKey(
      const ValueKey('generate-appearance-from-description-switch'),
    );
    await tester.ensureVisible(appearanceSwitch);
    await tester.tap(appearanceSwitch);
    await tester.pumpAndSettle();
    expect(find.text('年龄'), findsNothing);
    expect(find.text('附加特征'), findsNothing);
    expect(find.text('个性'), findsOneWidget);

    final omitSwitch = find.byKey(const ValueKey('omit-roleplay-switch'));
    tester.widget<Switch>(omitSwitch).onChanged!(true);
    await tester.pumpAndSettle();

    expect(find.text('年龄'), findsNothing);
    expect(find.text('人物塑造'), findsOneWidget);
  });

  testWidgets('建卡要求默认显示角色姓名、四项确定选项和玩法偏好', (tester) async {
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
    expect(find.text('角色姓名 *'), findsOneWidget);
    expect(find.text('职业 *'), findsOneWidget);
    expect(find.text('种族 *'), findsOneWidget);
    expect(find.text('背景 *'), findsOneWidget);
    expect(find.text('阵营 *'), findsOneWidget);
    expect(find.text('玩法偏好 *'), findsOneWidget);
    final nameDecorator = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const ValueKey('characterName-choice-field')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(nameDecorator.decoration.helperText, isNull);
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
      find.byKey(const ValueKey('characterName-choice-field')),
      '莱拉',
    );
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
    expect(find.text('角色姓名 *'), findsNothing);
    expect(find.text('职业 *'), findsNothing);
    expect(find.text('角色描述 *'), findsOneWidget);
    expect(find.text('描述你想要扮演一个什么样的角色'), findsOneWidget);
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
    final restoredNameField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('characterName-choice-field')),
    );
    expect(restoredNameField.controller?.text, '莱拉');
    final restoredClassField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('classAndSubclass-choice-field')),
    );
    expect(restoredClassField.controller?.text, '战士（奥法骑士）');
  });

  testWidgets('系统返回和标题栏返回都会要求确认未保存草稿', (tester) async {
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
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AiCharacterCreationPage(repository: repository),
                ),
              ),
              child: const Text('打开 AI 建卡'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开 AI 建卡'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('退出 AI 建卡？'), findsOneWidget);
    expect(find.text('退出后，本页面的所有草稿都不会被保存。'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('AI 建卡'), findsWidgets);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('退出 AI 建卡？'), findsOneWidget);
    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();

    expect(find.text('打开 AI 建卡'), findsOneWidget);
    expect(find.text('AI 建卡'), findsNothing);
  });

  testWidgets('构筑方案确认后自动完成其余阶段并显示人工检查提示', (tester) async {
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
    final service = _ImmediateAiService(
      planDelay: const Duration(milliseconds: 2200),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AiCharacterCreationPage(repository: repository, service: service),
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
    await _pumpUntilFound(tester, find.text('确认并修改构筑方案'));
    expect(find.text('本次生成用时'), findsOneWidget);
    final elapsed = tester.widget<Text>(
      find.byKey(const ValueKey('generation-elapsed-value')),
    );
    expect(elapsed.data, isNot('00:00'));

    expect(find.text('确认并修改构筑方案'), findsOneWidget);
    expect(find.text('角色总等级'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('confirmed-character-name-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('confirmed-alignment-field')),
      findsOneWidget,
    );
    expect(find.text('职业 1 *'), findsOneWidget);
    expect(find.text('战斗定位 *'), findsOneWidget);
    expect(find.text('冒险定位 *'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('confirmed-race-field')),
      '高等精灵',
    );
    await tester.tap(find.text('确认并继续生成'));
    await tester.pump();
    await _pumpUntilFound(tester, find.text('使用前请确认'));

    expect(find.text('使用前请确认'), findsOneWidget);
    expect(
      find.text('AI生成的角色卡可能包含错误，在使用之前请务必进行人工检查，并与你的DM沟通。'),
      findsOneWidget,
    );
    expect(find.text('返回修改'), findsNothing);
    expect(find.text('我已知晓'), findsOneWidget);
    expect(service.lastMechanicsPlan?.raceAndSubrace, '高等精灵');
  });

  testWidgets('衍生数值失败后从该阶段重试且不重复机械选择', (tester) async {
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
    final service = _FailOnceDerivedAiService();
    await tester.pumpWidget(
      MaterialApp(
        home: AiCharacterCreationPage(repository: repository, service: service),
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
      '自然施法者',
    );
    await tester.enterText(
      find.byKey(const ValueKey('gameplay-preference-field')),
      '支援和探索',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final submit = find.text('生成角色草稿');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();
    await _pumpUntilFound(tester, find.text('确认并修改构筑方案'));
    await tester.tap(find.text('确认并继续生成'));
    await tester.pump();
    await _pumpUntil(tester, () => service.derivedCalls == 1);
    await tester.pumpAndSettle();

    expect(service.mechanicsCalls, 1);
    expect(service.derivedCalls, 1);

    final retry = find.text('从计算衍生数值重试');
    await _scrollUntilFound(tester, retry);
    expect(retry, findsOneWidget);
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pump();
    await _pumpUntilFound(tester, find.text('使用前请确认'));
    expect(find.text('使用前请确认'), findsOneWidget);
    expect(service.mechanicsCalls, 1);
    expect(service.derivedCalls, 2);
  });
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int attempts = 30,
}) async {
  for (
    var attempt = 0;
    attempt < attempts && finder.evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int attempts = 30,
}) async {
  for (var attempt = 0; attempt < attempts && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _scrollUntilFound(
  WidgetTester tester,
  Finder finder, {
  int attempts = 20,
}) async {
  for (
    var attempt = 0;
    attempt < attempts && finder.evaluate().isEmpty;
    attempt++
  ) {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      await tester.drag(scrollables.last, const Offset(0, -300));
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _ImmediateAiService extends AiCharacterService {
  _ImmediateAiService({this.planDelay = Duration.zero});

  final Duration planDelay;
  AiBuildPlan? lastMechanicsPlan;

  @override
  Future<AiBuildPlan> generateBuildPlan(
    AiServiceConfig config,
    String apiKey,
    AiCharacterBuildRequest request,
  ) async {
    await Future<void>.delayed(planDelay);
    return const AiBuildPlan(
      characterName: '莱拉',
      alignment: '中立善良',
      classes: [AiBuildPlanClass(name: '德鲁伊', level: 1, subclass: '')],
      raceAndSubrace: '木精灵',
      background: '隐士',
      combatRole: '远程支援与控制',
      adventureRole: '察觉与荒野探索',
      synergy: '感知同时服务于施法和探索',
      warnings: '',
    );
  }

  @override
  Future<AiMechanicsDraft> generateMechanics(
    AiServiceConfig config,
    String apiKey,
    AiCharacterBuildRequest request,
    AiBuildPlan plan,
  ) async {
    lastMechanicsPlan = plan;
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
    return AiMechanicsDraft(
      abilities: const AiAbilityBreakdown(
        base: scores,
        racialBonuses: zero,
        advancementAdjustments: zero,
        finalScores: scores,
      ),
      advancementChoices: '',
      proficiencies: Proficiencies(),
      specialAbilities: '德鲁伊语',
      attacksAndSpellcastingNotes: '',
      spellcastingClass: '德鲁伊',
      spellcastingAbility: '感知',
      spellGroups: const [],
      weaponNames: const [],
      inventory: Inventory(),
    );
  }

  @override
  Future<AiDerivedDraft> generateDerived(
    AiServiceConfig config,
    String apiKey,
    AiCharacterBuildRequest request,
    AiBuildPlan plan,
    AiMechanicsDraft mechanics,
  ) async {
    return const AiDerivedDraft(
      experiencePoints: 0,
      passivePerception: 10,
      armorClass: 12,
      initiative: 2,
      speed: '35 尺',
      hitPointsMax: 10,
      hitDiceTotal: '1d8',
      spellSaveDC: 10,
      spellAttackBonus: 2,
      spellSlots: {},
      weapons: [],
      specialAbilityNumericNotes: '',
      calculationChecks: [
        AiDerivedCalculationCheck(
          field: 'passivePerception',
          base: 10,
          adjustments: [],
          finalValue: 10,
        ),
        AiDerivedCalculationCheck(
          field: 'armorClass',
          base: 10,
          adjustments: [2],
          finalValue: 12,
        ),
        AiDerivedCalculationCheck(
          field: 'initiative',
          base: 2,
          adjustments: [],
          finalValue: 2,
        ),
        AiDerivedCalculationCheck(
          field: 'hitPointsMax',
          base: 8,
          adjustments: [2],
          finalValue: 10,
        ),
        AiDerivedCalculationCheck(
          field: 'spellSaveDC',
          base: 8,
          adjustments: [2],
          finalValue: 10,
        ),
        AiDerivedCalculationCheck(
          field: 'spellAttackBonus',
          base: 2,
          adjustments: [],
          finalValue: 2,
        ),
      ],
      valueExplanations: [],
    );
  }

  @override
  Future<AiNarrativeDraft> generateNarrative(
    AiServiceConfig config,
    String apiKey,
    AiCharacterBuildRequest request,
    AiBuildPlan plan,
    AiMechanicsDraft mechanics,
  ) async {
    return const AiNarrativeDraft(values: {});
  }
}

class _FailOnceDerivedAiService extends _ImmediateAiService {
  int mechanicsCalls = 0;
  int derivedCalls = 0;

  @override
  Future<AiMechanicsDraft> generateMechanics(
    AiServiceConfig config,
    String apiKey,
    AiCharacterBuildRequest request,
    AiBuildPlan plan,
  ) {
    mechanicsCalls++;
    return super.generateMechanics(config, apiKey, request, plan);
  }

  @override
  Future<AiDerivedDraft> generateDerived(
    AiServiceConfig config,
    String apiKey,
    AiCharacterBuildRequest request,
    AiBuildPlan plan,
    AiMechanicsDraft mechanics,
  ) {
    derivedCalls++;
    if (derivedCalls == 1) {
      throw const AiServiceException('模拟衍生数值失败');
    }
    return super.generateDerived(config, apiKey, request, plan, mechanics);
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
