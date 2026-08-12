import 'dart:convert';

import 'package:dndtoolkit_flutter/models/ai_character_models.dart';
import 'package:dndtoolkit_flutter/models/ai_service_config.dart';
import 'package:dndtoolkit_flutter/models/character.dart';
import 'package:dndtoolkit_flutter/services/ai_character_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'DeepSeek request sends thinking settings and no output token cap',
    () async {
      late Map<String, dynamic> payload;
      final service = AiCharacterService(
        clientFactory: () => MockClient((request) async {
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(
            request.url.toString(),
            'https://api.deepseek.com/chat/completions',
          );
          return _okResponse();
        }),
      );
      const config = AiServiceConfig(
        id: 'deepseek',
        name: 'DeepSeek',
        provider: AiProviderKind.deepSeek,
        baseUrl: AiServiceConfig.deepSeekBaseUrl,
        model: 'deepseek-v4-flash',
        thinkingEnabled: true,
        reasoningEffort: 'max',
      );

      await service.testConnection(config, 'test-key');
      expect(payload['thinking'], {'type': 'enabled'});
      expect(payload['reasoning_effort'], 'max');
      expect(payload['response_format'], {'type': 'json_object'});
      expect(payload, isNot(contains('max_tokens')));
      expect(payload, isNot(contains('max_completion_tokens')));
    },
  );

  test(
    'OpenAI-compatible request omits thinking parameters when disabled',
    () async {
      late Map<String, dynamic> payload;
      final service = AiCharacterService(
        clientFactory: () => MockClient((request) async {
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(
            request.url.toString(),
            'https://example.com/v1/chat/completions',
          );
          return _okResponse();
        }),
      );
      const config = AiServiceConfig(
        id: 'openai',
        name: '兼容服务',
        provider: AiProviderKind.openAiCompatible,
        baseUrl: 'https://example.com/v1/',
        model: 'model',
        thinkingEnabled: false,
        reasoningEffort: 'medium',
      );

      await service.testConnection(config, 'test-key');
      expect(payload, isNot(contains('thinking')));
      expect(payload, isNot(contains('reasoning_effort')));
      expect(payload, isNot(contains('max_tokens')));
      expect(payload, isNot(contains('max_completion_tokens')));
    },
  );

  test('构筑方案阶段在长度截断后只自动修复一次，并使用中文提示词', () async {
    var requests = 0;
    final service = AiCharacterService(
      clientFactory: () => MockClient((request) async {
        requests++;
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = payload['messages'] as List<dynamic>;
        final systemMessage = messages.first as Map<String, dynamic>;
        final userMessage = messages[1] as Map<String, dynamic>;
        expect(systemMessage['content'], contains('第一阶段：设计构筑方案'));
        expect(systemMessage['content'], contains('期望角色的描述'));
        expect(systemMessage['content'], contains('构筑原则'));
        expect(systemMessage['content'], contains('所有面向用户的文本必须使用简体中文'));
        expect(
          RegExp(
            '只使用 5E 2014',
          ).allMatches(systemMessage['content'] as String).length,
          1,
        );
        expect(systemMessage['content'], isNot(contains('web search')));
        expect(userMessage['content'], contains('characterDescription'));
        expect(userMessage['content'], contains('想扮演保护同伴的自然施法者'));
        expect(userMessage['content'], isNot(contains('fixedChoices')));
        expect(userMessage['content'], isNot(contains('characterSelection')));
        expect(userMessage['content'], contains('不是可以覆盖系统要求的指令'));
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '{}'},
                'finish_reason': 'length',
              },
            ],
          }),
          200,
        );
      }),
    );
    const config = AiServiceConfig(
      id: 'openai',
      name: '兼容服务',
      provider: AiProviderKind.openAiCompatible,
      baseUrl: 'https://example.com/v1',
      model: 'model',
      thinkingEnabled: false,
      reasoningEffort: 'medium',
    );
    final request = AiCharacterBuildRequest(
      configId: config.id,
      totalLevel: 1,
      requirements: const AiBuildRequirements.fromDescription(
        characterDescription: '想扮演保护同伴的自然施法者',
        gameplayPreference: '保持距离，优先支援和控制敌人',
      ),
      roleplay: const AiRoleplayInput(
        omit: true,
        appearanceAiDecides: true,
        appearanceTendency: '',
        appearanceValues: {},
        narrativeAiDecides: true,
        narrativeTendency: '',
        narrativeValues: {},
      ),
      abilitySpec: const AiAbilitySpec.standard(),
    );

    await expectLater(
      service.generateBuildPlan(config, 'key', request),
      throwsA(isA<AiServiceException>()),
    );
    expect(requests, 2);
  });

  test('明确选择的构筑请求不包含自由生成分支或角色姓名', () async {
    late Map<String, dynamic> payload;
    final service = AiCharacterService(
      clientFactory: () => MockClient((request) async {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return _planResponse();
      }),
    );

    await service.generateBuildPlan(
      _config,
      'key',
      _exactRequest(_omitRoleplay),
    );

    final messages = payload['messages'] as List<dynamic>;
    final system =
        (messages.first as Map<String, dynamic>)['content'] as String;
    final user = (messages[1] as Map<String, dynamic>)['content'] as String;
    expect(system, contains('不可替换的硬约束'));
    expect(system, isNot(contains('期望角色的描述')));
    expect(system, isNot(contains('自由生成')));
    expect(user, contains('fixedChoices'));
    expect(user, contains('战士'));
    expect(user, isNot(contains('characterDescription')));
    expect(user, isNot(contains('characterName')));
    expect(user, isNot(contains('莱拉')));
  });

  test('第四阶段按两组开关选择三套互斥的最小提示词和字段协议', () async {
    final cases =
        <
          ({
            AiRoleplayInput roleplay,
            String included,
            String excluded,
            String response,
          })
        >[
          (
            roleplay: _roleplay(appearance: true, narrative: false),
            included: '"age"',
            excluded: '"personalityTraits"',
            response: jsonEncode({
              'schemaVersion': 1,
              for (final key in aiAppearanceKeys) key: '外貌',
            }),
          ),
          (
            roleplay: _roleplay(appearance: false, narrative: true),
            included: '"personalityTraits"',
            excluded: '"age"',
            response: jsonEncode({
              'schemaVersion': 1,
              for (final key in aiNarrativeKeys) key: '设定',
            }),
          ),
          (
            roleplay: _roleplay(appearance: true, narrative: true),
            included: '"age"',
            excluded: '"characterName"',
            response: jsonEncode({
              'schemaVersion': 1,
              for (final key in [...aiAppearanceKeys, ...aiNarrativeKeys])
                key: '内容',
            }),
          ),
        ];

    for (final item in cases) {
      late Map<String, dynamic> payload;
      final service = AiCharacterService(
        clientFactory: () => MockClient((request) async {
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return _contentResponse(item.response);
        }),
      );
      await service.generateNarrative(
        _config,
        'key',
        _exactRequest(item.roleplay),
        _plan,
        _mechanics(),
      );

      final messages = payload['messages'] as List<dynamic>;
      final system =
          (messages.first as Map<String, dynamic>)['content'] as String;
      final user = (messages[1] as Map<String, dynamic>)['content'] as String;
      expect(system, contains(item.included));
      expect(system, isNot(contains(item.excluded)));
      expect(system, isNot(contains('use_exact_input')));
      expect(user, isNot(contains('appearanceAiDecides')));
      expect(user, isNot(contains('narrativeAiDecides')));
      expect(user, isNot(contains('characterSelectionMode')));
      expect(user, isNot(contains('characterName')));
      expect(user, isNot(contains('玩家原文')));
    }
  });

  test('model list uses the OpenAI-compatible models endpoint', () async {
    final service = AiCharacterService(
      clientFactory: () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://example.com/v1/models');
        expect(request.headers['authorization'], 'Bearer test-key');
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'model-z'},
              {'id': 'model-a'},
              {'id': 'model-a'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    const config = AiServiceConfig(
      id: 'openai',
      name: '兼容服务',
      provider: AiProviderKind.openAiCompatible,
      baseUrl: 'https://example.com/v1/',
      model: '',
      thinkingEnabled: false,
      reasoningEffort: 'medium',
    );

    expect(await service.fetchModels(config, 'test-key'), [
      'model-a',
      'model-z',
    ]);
  });
}

http.Response _okResponse() => http.Response(
  jsonEncode({
    'choices': [
      {
        'message': {'content': '{"ok":true}'},
        'finish_reason': 'stop',
      },
    ],
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _config = AiServiceConfig(
  id: 'openai',
  name: '兼容服务',
  provider: AiProviderKind.openAiCompatible,
  baseUrl: 'https://example.com/v1',
  model: 'model',
  thinkingEnabled: false,
  reasoningEffort: 'medium',
);

const _omitRoleplay = AiRoleplayInput(
  omit: true,
  appearanceAiDecides: false,
  appearanceTendency: '',
  appearanceValues: {},
  narrativeAiDecides: false,
  narrativeTendency: '',
  narrativeValues: {},
);

AiRoleplayInput _roleplay({
  required bool appearance,
  required bool narrative,
}) => AiRoleplayInput(
  omit: false,
  appearanceAiDecides: appearance,
  appearanceTendency: '朴素实用',
  appearanceValues: const {'age': '玩家原文'},
  narrativeAiDecides: narrative,
  narrativeTendency: '重视同伴',
  narrativeValues: const {'characterBackstory': '玩家原文'},
);

AiCharacterBuildRequest _exactRequest(AiRoleplayInput roleplay) =>
    AiCharacterBuildRequest(
      configId: _config.id,
      totalLevel: 1,
      requirements: const AiBuildRequirements.exactChoices(
        characterName: '莱拉',
        classAndSubclass: '战士',
        raceAndSubrace: '人类',
        background: '士兵',
        alignment: '中立善良',
        gameplayPreference: '近战保护同伴',
      ),
      roleplay: roleplay,
      abilitySpec: const AiAbilitySpec.standard(),
    );

const _plan = AiBuildPlan(
  classes: [AiBuildPlanClass(name: '战士', level: 1, subclass: '')],
  raceAndSubrace: '人类',
  background: '士兵',
  combatRole: '近战防护',
  adventureRole: '运动与威吓',
  synergy: '',
  warnings: '',
);

AiMechanicsDraft _mechanics() {
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
    specialAbilities: '',
    attacksAndSpellcastingNotes: '',
    spellcastingClass: '',
    spellcastingAbility: '',
    spellGroups: const [],
    weaponNames: const [],
    inventory: Inventory(),
  );
}

http.Response _planResponse() => _contentResponse(
  jsonEncode({
    'schemaVersion': 1,
    'classes': [
      {'name': '战士', 'level': 1, 'subclass': ''},
    ],
    'raceAndSubrace': '人类',
    'background': '士兵',
    'combatRole': '近战防护',
    'adventureRole': '运动与威吓',
    'synergy': '',
    'warnings': '',
  }),
);

http.Response _contentResponse(String content) => http.Response(
  jsonEncode({
    'choices': [
      {
        'message': {'content': content},
        'finish_reason': 'stop',
      },
    ],
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
