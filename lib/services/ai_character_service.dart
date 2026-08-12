import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_character_models.dart';
import '../models/ai_service_config.dart';
import 'ai_character_prompts.dart';

class AiServiceException implements Exception {
  const AiServiceException(this.message, {this.recoverable = true});

  final String message;
  final bool recoverable;

  @override
  String toString() => message;
}

class AiCharacterService {
  AiCharacterService({
    http.Client Function()? clientFactory,
    this.generationRequestTimeout = defaultGenerationRequestTimeout,
  }) : assert(generationRequestTimeout > Duration.zero),
       _clientFactory = clientFactory ?? http.Client.new;

  static const defaultGenerationRequestTimeout = Duration(minutes: 10);
  static const connectionRequestTimeout = Duration(minutes: 2);

  final http.Client Function() _clientFactory;
  final Duration generationRequestTimeout;
  http.Client? _activeClient;

  Future<void> testConnection(AiServiceConfig config, String apiKey) async {
    final result = await _send(config, apiKey, const [
      {'role': 'system', 'content': aiConnectionTestSystemPrompt},
      {'role': 'user', 'content': aiConnectionTestUserPrompt},
    ], timeout: connectionRequestTimeout);
    try {
      final decoded = jsonDecode(result.content);
      if (decoded is! Map || decoded['ok'] != true) {
        throw const FormatException();
      }
    } on FormatException {
      throw const AiServiceException('服务可以响应，但没有遵循 JSON 输出要求');
    }
  }

  Future<List<String>> fetchModels(
    AiServiceConfig config,
    String apiKey,
  ) async {
    cancelCurrentRequest();
    final client = _clientFactory();
    _activeClient = client;
    try {
      final response = await client
          .get(
            _modelsUri(config.baseUrl),
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiServiceException(_statusMessage(response.statusCode));
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded['data'] is! List) {
        throw const FormatException();
      }
      final models = <String>{};
      for (final item in decoded['data'] as List) {
        if (item is! Map) continue;
        final id = item['id'];
        if (id is String && id.trim().isNotEmpty) models.add(id.trim());
      }
      final result = models.toList()..sort();
      if (result.isEmpty) {
        throw const AiServiceException('服务返回的模型列表为空');
      }
      return result;
    } on TimeoutException {
      throw const AiServiceException('获取模型列表超时，请检查网络或稍后重试');
    } on AiServiceException {
      rethrow;
    } on http.ClientException {
      throw const AiServiceException('请求已取消，或无法连接到 AI 服务');
    } on FormatException {
      throw const AiServiceException('AI 服务返回了无法解析的模型列表');
    } finally {
      if (identical(_activeClient, client)) _activeClient = null;
      client.close();
    }
  }

  Future<AiBuildPlan> generateBuildPlan(
    AiServiceConfig config,
    String apiKey,
    AiCharacterBuildRequest request,
  ) async {
    final requestErrors = request.validate();
    if (requestErrors.isNotEmpty) {
      throw AiServiceException(requestErrors.join('；'), recoverable: false);
    }

    switch (request.requirements.mode) {
      case AiBuildRequirementMode.exactChoices:
        return _requestStage(
          config,
          apiKey,
          stage: AiGenerationStage.plan,
          systemPrompt: aiBuildPlanExactSystemPrompt,
          schemaPrompt: aiBuildPlanExactSchemaPrompt,
          data: {
            'totalLevel': request.totalLevel,
            'fixedChoices': {
              'classAndSubclass': request.requirements.classAndSubclass.trim(),
              'raceAndSubrace': request.requirements.raceAndSubrace.trim(),
              'background': request.requirements.background.trim(),
              'alignment': request.requirements.alignment.trim(),
            },
            'gameplayPreference': request.requirements.gameplayPreference
                .trim(),
          },
          parse: AiBuildPlan.fromJson,
          validate: (plan) => plan.validate(request.totalLevel),
        );
      case AiBuildRequirementMode.fromDescription:
        return _requestStage(
          config,
          apiKey,
          stage: AiGenerationStage.plan,
          systemPrompt: aiBuildPlanFreedomSystemPrompt,
          schemaPrompt: aiBuildPlanFreedomSchemaPrompt,
          data: {
            'totalLevel': request.totalLevel,
            'characterDescription': request.requirements.characterDescription
                .trim(),
            'gameplayPreference': request.requirements.gameplayPreference
                .trim(),
          },
          parse: (json) => AiBuildPlan.fromJson(json, includesIdentity: true),
          validate: (plan) =>
              plan.validate(request.totalLevel, requireIdentity: true),
        );
    }
  }

  Future<AiMechanicsDraft> generateMechanics(
    AiServiceConfig config,
    String apiKey,
    AiCharacterBuildRequest request,
    AiBuildPlan plan,
  ) {
    return _requestStage(
      config,
      apiKey,
      stage: AiGenerationStage.mechanics,
      systemPrompt: aiMechanicsSystemPrompt,
      schemaPrompt: aiMechanicsSchemaPrompt,
      data: {
        'totalLevel': request.totalLevel,
        'confirmedPlan': plan.toJson(),
        'abilityGeneration': request.abilitySpec.toJson(),
      },
      parse: AiMechanicsDraft.fromJson,
      validate: (draft) => draft.validate(request.abilitySpec),
    );
  }

  Future<AiDerivedDraft> generateDerived(
    AiServiceConfig config,
    String apiKey,
    AiCharacterBuildRequest request,
    AiBuildPlan plan,
    AiMechanicsDraft mechanics,
  ) {
    return _requestStage(
      config,
      apiKey,
      stage: AiGenerationStage.derived,
      systemPrompt: aiDerivedSystemPrompt,
      schemaPrompt: aiDerivedSchemaPrompt,
      data: {
        'totalLevel': request.totalLevel,
        'confirmedPlan': plan.toJson(),
        'mechanics': mechanics.toPromptJson(),
        'locallyCalculated': {
          'finalAbilities': _abilityScoresPromptJson(
            mechanics.abilities.finalScores,
          ),
          'proficiencyBonus': 2 + ((request.totalLevel - 1) ~/ 4),
        },
      },
      parse: AiDerivedDraft.fromJson,
      validate: (draft) => draft.validate(mechanics),
    );
  }

  Future<AiNarrativeDraft> generateNarrative(
    AiServiceConfig config,
    String apiKey,
    AiCharacterBuildRequest request,
    AiBuildPlan plan,
    AiMechanicsDraft mechanics,
  ) {
    final scope = narrativeScopeFor(request.roleplay);
    final systemPrompt = switch (scope) {
      AiNarrativeScope.appearance => aiNarrativeAppearanceSystemPrompt,
      AiNarrativeScope.personalityAndBackground =>
        aiNarrativePersonalitySystemPrompt,
      AiNarrativeScope.all => aiNarrativeAllSystemPrompt,
    };
    final schemaPrompt = switch (scope) {
      AiNarrativeScope.appearance => aiNarrativeAppearanceSchemaPrompt,
      AiNarrativeScope.personalityAndBackground =>
        aiNarrativePersonalitySchemaPrompt,
      AiNarrativeScope.all => aiNarrativeAllSchemaPrompt,
    };
    final alignment =
        request.requirements.mode == AiBuildRequirementMode.exactChoices
        ? request.requirements.alignment.trim()
        : plan.alignment.trim();
    return _requestStage(
      config,
      apiKey,
      stage: AiGenerationStage.narrative,
      systemPrompt: systemPrompt,
      schemaPrompt: schemaPrompt,
      data: {
        'confirmedPlan': {...plan.toJson(), 'alignment': alignment},
        'mechanics': mechanics.toPromptJson(),
        ...buildNarrativePromptData(request.roleplay, scope),
      },
      parse: (json) => AiNarrativeDraft.fromJson(json, scope),
      validate: (_) => const [],
    );
  }

  Future<T> _requestStage<T>(
    AiServiceConfig config,
    String apiKey, {
    required AiGenerationStage stage,
    required String systemPrompt,
    required String schemaPrompt,
    required Map<String, dynamic> data,
    required T Function(Map<String, dynamic>) parse,
    required List<String> Function(T) validate,
  }) async {
    List<String> previousErrors = const [];
    for (var attempt = 0; attempt < 2; attempt++) {
      final response = await _send(
        config,
        apiKey,
        buildAiStageMessages(
          systemPrompt: systemPrompt,
          schemaPrompt: schemaPrompt,
          data: data,
          previousErrors: previousErrors,
        ),
        timeout: generationRequestTimeout,
      );
      try {
        if (response.finishReason == 'length') {
          throw const FormatException('响应因长度限制而被截断');
        }
        final decoded = jsonDecode(response.content);
        if (decoded is! Map) throw const FormatException('响应根节点必须是对象');
        final result = parse(Map<String, dynamic>.from(decoded));
        final errors = validate(result);
        if (errors.isNotEmpty) throw AiDraftValidationException(errors);
        return result;
      } on AiDraftValidationException catch (error) {
        previousErrors = error.errors;
      } on FormatException catch (error) {
        previousErrors = [error.message.toString()];
      }
    }
    throw AiServiceException(
      '${stage.label}连续两次返回了无法使用的数据：${previousErrors.join('；')}',
    );
  }

  void cancelCurrentRequest() {
    _activeClient?.close();
    _activeClient = null;
  }

  Future<_ChatResponse> _send(
    AiServiceConfig config,
    String apiKey,
    List<Map<String, String>> messages, {
    required Duration timeout,
  }) async {
    cancelCurrentRequest();
    final client = _clientFactory();
    _activeClient = client;
    final body = <String, dynamic>{
      'model': config.model,
      'messages': messages,
      'response_format': {'type': 'json_object'},
    };
    if (config.provider == AiProviderKind.deepSeek) {
      body['thinking'] = {
        'type': config.thinkingEnabled ? 'enabled' : 'disabled',
      };
      if (config.thinkingEnabled) {
        body['reasoning_effort'] = config.reasoningEffort;
      }
    } else if (config.thinkingEnabled) {
      body['reasoning_effort'] = config.reasoningEffort;
    }

    try {
      final response = await client
          .post(
            _chatCompletionsUri(config.baseUrl),
            headers: {
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiServiceException(_statusMessage(response.statusCode));
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) throw const FormatException();
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        throw const FormatException();
      }
      final choice = Map<String, dynamic>.from(choices.first as Map);
      final message = choice['message'];
      if (message is! Map || message['content'] is! String) {
        throw const FormatException();
      }
      return _ChatResponse(
        content: message['content'] as String,
        finishReason: choice['finish_reason']?.toString(),
      );
    } on TimeoutException {
      throw const AiServiceException('请求超时，请检查网络或稍后重试');
    } on AiServiceException {
      rethrow;
    } on http.ClientException {
      throw const AiServiceException('请求已取消，或无法连接到 AI 服务');
    } on FormatException {
      throw const AiServiceException('AI 服务返回了无法解析的协议数据');
    } finally {
      if (identical(_activeClient, client)) _activeClient = null;
      client.close();
    }
  }

  static Uri _chatCompletionsUri(String baseUrl) {
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse('$normalized/chat/completions');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const AiServiceException(
        'AI 服务地址必须是有效的 HTTPS 地址',
        recoverable: false,
      );
    }
    return uri;
  }

  static Uri _modelsUri(String baseUrl) {
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse('$normalized/models');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const AiServiceException(
        'AI 服务地址必须是有效的 HTTPS 地址',
        recoverable: false,
      );
    }
    return uri;
  }

  static String _statusMessage(int statusCode) => switch (statusCode) {
    400 => '请求参数不被该模型或服务支持，请检查模型和思考设置',
    401 || 403 => 'API Key 无效或没有访问该模型的权限',
    404 => '找不到 API 地址或模型，请检查 Base URL 和模型名',
    408 => 'AI 服务处理超时，请稍后重试',
    429 => 'AI 服务请求过于频繁或额度不足，请稍后重试',
    >= 500 => 'AI 服务暂时不可用（HTTP $statusCode）',
    _ => 'AI 服务请求失败（HTTP $statusCode）',
  };
}

class _ChatResponse {
  const _ChatResponse({required this.content, required this.finishReason});

  final String content;
  final String? finishReason;
}

Map<String, int> _abilityScoresPromptJson(AbilityScores scores) => {
  'strength': scores.strength,
  'dexterity': scores.dexterity,
  'constitution': scores.constitution,
  'intelligence': scores.intelligence,
  'wisdom': scores.wisdom,
  'charisma': scores.charisma,
};
