enum AiProviderKind { deepSeek, kimi, mimo, openAiCompatible }

extension AiProviderKindDisplay on AiProviderKind {
  String get label => switch (this) {
    AiProviderKind.deepSeek => 'DeepSeek',
    AiProviderKind.openAiCompatible => 'OpenAI 协议',
    AiProviderKind.kimi => 'Kimi',
    AiProviderKind.mimo => 'MiMo',
  };

  String? get fixedBaseUrl => switch (this) {
    AiProviderKind.deepSeek => AiServiceConfig.deepSeekBaseUrl,
    AiProviderKind.kimi => AiServiceConfig.kimiBaseUrl,
    AiProviderKind.mimo => AiServiceConfig.mimoBaseUrl,
    AiProviderKind.openAiCompatible => null,
  };

  String get defaultModel => switch (this) {
    AiProviderKind.deepSeek => 'deepseek-v4-flash',
    AiProviderKind.kimi => 'kimi-k3',
    AiProviderKind.mimo => 'mimo-v2.5-pro',
    AiProviderKind.openAiCompatible => '',
  };
}

class AiServiceConfig {
  const AiServiceConfig({
    required this.id,
    required this.name,
    required this.provider,
    required this.baseUrl,
    required this.model,
    required this.thinkingEnabled,
    required this.reasoningEffort,
  });

  static const deepSeekBaseUrl = 'https://api.deepseek.com';
  static const kimiBaseUrl = 'https://api.moonshot.cn/v1';
  static const mimoBaseUrl = 'https://api.xiaomimimo.com/v1';

  final String id;
  final String name;
  final AiProviderKind provider;
  final String baseUrl;
  final String model;
  final bool thinkingEnabled;
  final String reasoningEffort;

  String get effectiveBaseUrl => provider.fixedBaseUrl ?? baseUrl;

  bool get _isKimiK3 =>
      provider == AiProviderKind.kimi &&
      model.trim().toLowerCase().startsWith('kimi-k3');

  bool get _isKimiK27 =>
      provider == AiProviderKind.kimi &&
      model.trim().toLowerCase().startsWith('kimi-k2.7-code');

  bool get _isKimiToggleModel {
    if (provider != AiProviderKind.kimi) return false;
    final normalized = model.trim().toLowerCase();
    return normalized.startsWith('kimi-k2.6') ||
        normalized.startsWith('kimi-k2.5');
  }

  bool get thinkingAlwaysEnabled => _isKimiK3 || _isKimiK27;

  bool get supportsThinkingToggle => switch (provider) {
    AiProviderKind.deepSeek ||
    AiProviderKind.openAiCompatible ||
    AiProviderKind.mimo => true,
    AiProviderKind.kimi => _isKimiToggleModel,
  };

  bool get supportsReasoningEffort => switch (provider) {
    AiProviderKind.deepSeek || AiProviderKind.openAiCompatible => true,
    AiProviderKind.kimi => _isKimiK3,
    AiProviderKind.mimo => false,
  };

  bool get effectiveThinkingEnabled =>
      thinkingAlwaysEnabled || (supportsThinkingToggle && thinkingEnabled);

  List<String> get allowedReasoningEfforts => switch (provider) {
    AiProviderKind.deepSeek => const ['low', 'high', 'max'],
    AiProviderKind.kimi when _isKimiK3 => const ['low', 'high', 'max'],
    AiProviderKind.openAiCompatible => const [
      'low',
      'medium',
      'high',
      'xhigh',
      'max',
    ],
    AiProviderKind.kimi || AiProviderKind.mimo => const ['high'],
  };

  String get normalizedReasoningEffort =>
      allowedReasoningEfforts.contains(reasoningEffort)
      ? reasoningEffort
      : allowedReasoningEfforts.first;

  String get thinkingSummary {
    if (thinkingAlwaysEnabled) {
      return supportsReasoningEffort ? normalizedReasoningEffort : '开启（模型固定）';
    }
    if (!supportsThinkingToggle) return '模型不支持配置';
    if (!thinkingEnabled) return '关闭';
    return supportsReasoningEffort ? normalizedReasoningEffort : '开启';
  }

  AiServiceConfig copyWith({
    String? name,
    AiProviderKind? provider,
    String? baseUrl,
    String? model,
    bool? thinkingEnabled,
    String? reasoningEffort,
  }) {
    return AiServiceConfig(
      id: id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      thinkingEnabled: thinkingEnabled ?? this.thinkingEnabled,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'provider': provider.name,
    'baseUrl': effectiveBaseUrl,
    'model': model,
    'thinkingEnabled': thinkingEnabled,
    'reasoningEffort': reasoningEffort,
  };

  factory AiServiceConfig.fromJson(Map<String, dynamic> json) {
    final providerName = json['provider'];
    final provider = AiProviderKind.values.where((value) {
      return value.name == providerName;
    }).firstOrNull;
    if (provider == null) {
      throw const FormatException('未知的 AI 服务类型');
    }
    final storedBaseUrl = _requiredString(json, 'baseUrl');

    final config = AiServiceConfig(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      provider: provider,
      baseUrl: provider.fixedBaseUrl ?? storedBaseUrl,
      model: _requiredString(json, 'model'),
      thinkingEnabled: json['thinkingEnabled'] == true,
      reasoningEffort: _requiredString(json, 'reasoningEffort'),
    );
    if (!config.allowedReasoningEfforts.contains(config.reasoningEffort)) {
      throw const FormatException('AI 服务思考强度无效');
    }
    return config;
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('AI 服务配置缺少 $key');
    }
    return value.trim();
  }
}
