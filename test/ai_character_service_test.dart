import 'dart:convert';

import 'package:dndtoolkit_flutter/models/ai_character_models.dart';
import 'package:dndtoolkit_flutter/models/ai_service_config.dart';
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

  test(
    'generation rejects length-truncated responses after one repair attempt',
    () async {
      var requests = 0;
      final service = AiCharacterService(
        clientFactory: () => MockClient((request) async {
          requests++;
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          final messages = payload['messages'] as List<dynamic>;
          final systemMessage = messages.first as Map<String, dynamic>;
          final userMessage = messages[1] as Map<String, dynamic>;
          expect(
            systemMessage['content'],
            isNot(contains('characterExperience')),
          );
          expect(
            systemMessage['content'],
            contains('generate_from_description'),
          );
          expect(systemMessage['content'], contains('gameplayPreference'));
          expect(userMessage['content'], contains('buildRequirements'));
          expect(userMessage['content'], contains('想扮演保护同伴的自然施法者'));
          expect(userMessage['content'], isNot(contains('"guidance"')));
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
        service.generate(config, 'key', request),
        throwsA(isA<AiServiceException>()),
      );
      expect(requests, 2);
    },
  );

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
