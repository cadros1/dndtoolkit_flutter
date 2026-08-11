enum AiProviderKind { deepSeek, openAiCompatible }

extension AiProviderKindDisplay on AiProviderKind {
  String get label => switch (this) {
    AiProviderKind.deepSeek => 'DeepSeek',
    AiProviderKind.openAiCompatible => 'OpenAI 协议',
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

  final String id;
  final String name;
  final AiProviderKind provider;
  final String baseUrl;
  final String model;
  final bool thinkingEnabled;
  final String reasoningEffort;

  List<String> get allowedReasoningEfforts =>
      provider == AiProviderKind.deepSeek
      ? const ['high', 'max']
      : const ['low', 'medium', 'high', 'xhigh', 'max'];

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
    'baseUrl': baseUrl,
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

    final config = AiServiceConfig(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      provider: provider,
      baseUrl: _requiredString(json, 'baseUrl'),
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
