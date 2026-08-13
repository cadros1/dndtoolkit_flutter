import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/ai_service_config.dart';
import '../services/ai_character_service.dart';
import '../services/ai_config_repository.dart';
import '../widgets/app_ui.dart';

class AiServiceConfigsPage extends StatefulWidget {
  AiServiceConfigsPage({
    super.key,
    AiConfigRepository? repository,
    AiCharacterService? service,
  }) : repository = repository ?? AiConfigRepository(),
       service = service ?? AiCharacterService();

  final AiConfigRepository repository;
  final AiCharacterService service;

  @override
  State<AiServiceConfigsPage> createState() => _AiServiceConfigsPageState();
}

class _AiServiceConfigsPageState extends State<AiServiceConfigsPage> {
  List<AiServiceConfig> _configs = const [];
  String? _selectedId;
  String? _error;
  bool _loading = true;
  String? _testingId;

  @override
  void dispose() {
    widget.service.cancelCurrentRequest();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final configs = await widget.repository.loadConfigs();
      final selectedId = await widget.repository.getLastConfigId();
      if (!mounted) return;
      setState(() {
        _configs = configs;
        _selectedId = configs.any((item) => item.id == selectedId)
            ? selectedId
            : configs.firstOrNull?.id;
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor([AiServiceConfig? config]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AiServiceConfigEditPage(
          repository: widget.repository,
          existing: config,
          service: widget.service,
        ),
      ),
    );
    if (!mounted) return;
    if (changed == true) await _reload();
  }

  Future<void> _select(AiServiceConfig config) async {
    try {
      await widget.repository.setLastConfigId(config.id);
      if (mounted) setState(() => _selectedId = config.id);
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    }
  }

  Future<void> _delete(AiServiceConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除 AI 服务配置'),
        content: Text('确定删除“${config.name}”及其本机 API Key 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      await widget.repository.deleteConfig(config.id);
      if (!mounted) return;
      await _reload();
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    }
  }

  Future<void> _testConfig(AiServiceConfig config) async {
    setState(() => _testingId = config.id);
    try {
      final apiKey = await widget.repository.readApiKey(config.id);
      if (apiKey == null || apiKey.trim().isEmpty) {
        throw const AiConfigException('该配置缺少 API Key，请先编辑配置');
      }
      await widget.service.testConnection(config, apiKey);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('“${config.name}”连接测试成功')));
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _testingId = null);
    }
  }

  Widget _body() {
    if (_loading) return const AppLoadingState(label: '正在读取 AI 服务配置');
    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: '无法读取配置',
        message: _error!,
        action: FilledButton.icon(
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      );
    }
    if (_configs.isEmpty) {
      return AppEmptyState(
        icon: Icons.smart_toy_outlined,
        title: '还没有 AI 服务配置',
        message: '新建一个具名配置并安全保存 API Key，之后即可在 AI 建卡时选择。',
        action: FilledButton.icon(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add),
          label: const Text('新建 AI 服务配置'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: _configs.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: AppPageHeader(
                icon: Icons.smart_toy_outlined,
                title: 'AI 服务配置',
                subtitle: 'API Key 仅保存在本机系统安全存储中。连接测试可能产生少量费用。',
                actions: [
                  FilledButton.icon(
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('新建配置'),
                  ),
                ],
              ),
            ),
          );
        }
        final config = _configs[index - 1];
        final selected = config.id == _selectedId;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: AppPanel(
              padding: EdgeInsets.zero,
              child: ListTile(
                minVerticalPadding: 14,
                contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                leading: Icon(
                  selected ? Icons.check_circle : Icons.smart_toy_outlined,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(
                  config.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${config.provider.label} · ${config.model}\n思考：${config.thinkingSummary}',
                ),
                isThreeLine: true,
                onTap: () => _select(config),
                trailing: _testingId == config.id
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : PopupMenuButton<String>(
                        tooltip: '配置操作',
                        onSelected: (value) {
                          if (value == 'select') _select(config);
                          if (value == 'test') _testConfig(config);
                          if (value == 'edit') _openEditor(config);
                          if (value == 'delete') _delete(config);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'select', child: Text('设为默认配置')),
                          PopupMenuItem(value: 'test', child: Text('连接测试')),
                          PopupMenuItem(value: 'edit', child: Text('编辑')),
                          PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI 服务配置')),
    body: SafeArea(child: _body()),
  );
}

class AiServiceConfigEditPage extends StatefulWidget {
  AiServiceConfigEditPage({
    super.key,
    required this.repository,
    this.existing,
    AiCharacterService? service,
  }) : service = service ?? AiCharacterService();

  final AiConfigRepository repository;
  final AiServiceConfig? existing;
  final AiCharacterService service;

  @override
  State<AiServiceConfigEditPage> createState() =>
      _AiServiceConfigEditPageState();
}

class _AiServiceConfigEditPageState extends State<AiServiceConfigEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;
  late AiProviderKind _provider;
  late bool _thinkingEnabled;
  late String _effort;
  bool _obscureKey = true;
  bool _busy = false;
  bool _loadingModels = false;

  @override
  void initState() {
    super.initState();
    final config = widget.existing;
    _provider = config?.provider ?? AiProviderKind.deepSeek;
    _thinkingEnabled = config?.thinkingEnabled ?? true;
    _effort = config?.reasoningEffort ?? 'high';
    _nameController = TextEditingController(text: config?.name ?? '');
    _baseUrlController = TextEditingController(
      text:
          _provider.fixedBaseUrl ??
          config?.baseUrl ??
          'https://api.openai.com/v1',
    );
    _modelController = TextEditingController(
      text: config?.model ?? _provider.defaultModel,
    );
    _apiKeyController = TextEditingController();
    _normalizeThinkingState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    widget.service.cancelCurrentRequest();
    super.dispose();
  }

  AiServiceConfig get _capabilityConfig => AiServiceConfig(
    id: widget.existing?.id ?? '',
    name: _nameController.text.trim(),
    provider: _provider,
    baseUrl: _baseUrlController.text.trim(),
    model: _modelController.text.trim(),
    thinkingEnabled: _thinkingEnabled,
    reasoningEffort: _effort,
  );

  List<String> get _efforts => _capabilityConfig.allowedReasoningEfforts;

  void _normalizeThinkingState() {
    final config = _capabilityConfig;
    if (config.thinkingAlwaysEnabled) {
      _thinkingEnabled = true;
    } else if (!config.supportsThinkingToggle) {
      _thinkingEnabled = false;
    }
    if (!_efforts.contains(_effort)) _effort = _efforts.first;
  }

  void _changeProvider(AiProviderKind provider) {
    setState(() {
      _provider = provider;
      _baseUrlController.text =
          provider.fixedBaseUrl ?? 'https://api.openai.com/v1';
      _modelController.text = provider.defaultModel;
      _thinkingEnabled = provider != AiProviderKind.openAiCompatible;
      _normalizeThinkingState();
    });
  }

  AiServiceConfig _buildConfig() {
    final capability = _capabilityConfig;
    return AiServiceConfig(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      provider: _provider,
      baseUrl: (_provider.fixedBaseUrl ?? _baseUrlController.text.trim())
          .replaceFirst(RegExp(r'/+$'), ''),
      model: _modelController.text.trim(),
      thinkingEnabled: capability.thinkingAlwaysEnabled
          ? true
          : capability.supportsThinkingToggle && _thinkingEnabled,
      reasoningEffort: capability.normalizedReasoningEffort,
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? '此项不能为空' : null;

  String? _validateBaseUrl(String? value) {
    if (_provider.fixedBaseUrl != null) return null;
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return '请输入有效的 HTTPS Base URL';
    }
    return null;
  }

  Future<String> _resolvedApiKey() async {
    final typed = _apiKeyController.text.trim();
    if (typed.isNotEmpty) return typed;
    final existing = widget.existing;
    if (existing != null) {
      return (await widget.repository.readApiKey(existing.id)) ?? '';
    }
    return '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final key = await _resolvedApiKey();
    if (!mounted) return;
    if (key.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请输入 API Key')));
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final config = _buildConfig();
      await widget.repository.saveConfig(
        config,
        apiKey: _apiKeyController.text.trim().isEmpty ? null : key,
      );
      await widget.repository.setLastConfigId(config.id);
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    if (!_formKey.currentState!.validate()) return;
    final key = await _resolvedApiKey();
    if (!mounted) return;
    if (key.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请输入 API Key')));
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.service.testConnection(_buildConfig(), key);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('连接测试成功')));
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fetchModels() async {
    final baseUrlError = _validateBaseUrl(_baseUrlController.text);
    if (baseUrlError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(baseUrlError)));
      return;
    }
    final key = await _resolvedApiKey();
    if (!mounted) return;
    if (key.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入 API Key')));
      return;
    }
    setState(() => _loadingModels = true);
    try {
      final models = await widget.service.fetchModels(_buildConfig(), key);
      if (!mounted) return;
      setState(() => _loadingModels = false);
      final selected = await _showModelPicker(models);
      if (!mounted || selected == null) return;
      setState(() {
        _modelController.text = selected;
        _normalizeThinkingState();
      });
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<String?> _showModelPicker(List<String> models) {
    var selected = models.contains(_modelController.text.trim())
        ? _modelController.text.trim()
        : models.first;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('选择模型'),
          content: SizedBox(
            width: 480,
            child: DropdownButtonFormField<String>(
              initialValue: selected,
              decoration: const InputDecoration(labelText: '模型列表'),
              isExpanded: true,
              items: models
                  .map(
                    (model) => DropdownMenuItem(
                      value: model,
                      child: Text(model, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setDialogState(() => selected = value);
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('确认选择'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final controlsBusy = _busy || _loadingModels;
    final capability = _capabilityConfig;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '新建 AI 服务配置' : '编辑 AI 服务配置'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: '配置名 *'),
                          validator: _required,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<AiProviderKind>(
                          initialValue: _provider,
                          decoration: const InputDecoration(
                            labelText: '服务类型 *',
                          ),
                          items: AiProviderKind.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.label),
                                ),
                              )
                              .toList(),
                          onChanged: controlsBusy
                              ? null
                              : (value) {
                                  if (value != null) _changeProvider(value);
                                },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _baseUrlController,
                          enabled:
                              _provider.fixedBaseUrl == null && !controlsBusy,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            labelText: 'Base URL *',
                            helperText: _provider.fixedBaseUrl == null
                                ? '填写兼容服务提供的 HTTPS 地址'
                                : '${_provider.label} 官方地址',
                          ),
                          validator: _validateBaseUrl,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _modelController,
                          decoration: const InputDecoration(labelText: '模型名 *'),
                          validator: _required,
                          onChanged: (_) => setState(_normalizeThinkingState),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: controlsBusy ? null : _fetchModels,
                            icon: _loadingModels
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download_outlined),
                            label: const Text('获取模型列表'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _apiKeyController,
                          obscureText: isAndroid ? false : _obscureKey,
                          keyboardType: isAndroid
                              ? TextInputType.text
                              : TextInputType.visiblePassword,
                          // Flutter Android 会在 enableSuggestions=false 时附加
                          // TYPE_TEXT_VARIATION_VISIBLE_PASSWORD，小米系统会据此
                          // 启用安全键盘。Android 保持 suggestions 标志开启，
                          // 同时关闭自动纠错，确保原生 inputType 仍是普通文本。
                          enableSuggestions: isAndroid,
                          autocorrect: false,
                          enableIMEPersonalizedLearning: false,
                          smartDashesType: SmartDashesType.disabled,
                          smartQuotesType: SmartQuotesType.disabled,
                          decoration: InputDecoration(
                            labelText: widget.existing == null
                                ? 'API Key *'
                                : 'API Key',
                            helperText: isAndroid
                                ? widget.existing == null
                                      ? '仅保存在本机系统安全存储中'
                                      : '留空表示保留现有 Key'
                                : widget.existing == null
                                ? '仅保存在本机系统安全存储中'
                                : '留空表示保留现有 Key',
                            suffixIcon: isAndroid
                                ? null
                                : IconButton(
                                    tooltip: _obscureKey
                                        ? '显示 API Key'
                                        : '隐藏 API Key',
                                    onPressed: () => setState(
                                      () => _obscureKey = !_obscureKey,
                                    ),
                                    icon: Icon(
                                      _obscureKey
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('启用思考模式'),
                          subtitle: Text(_thinkingDescription(capability)),
                          value: capability.effectiveThinkingEnabled,
                          onChanged:
                              controlsBusy || !capability.supportsThinkingToggle
                              ? null
                              : (value) =>
                                    setState(() => _thinkingEnabled = value),
                        ),
                        if (capability.effectiveThinkingEnabled &&
                            capability.supportsReasoningEffort) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            key: ValueKey('${_provider.name}-$_effort'),
                            initialValue: _effort,
                            decoration: const InputDecoration(
                              labelText: '思考强度',
                            ),
                            items: _efforts
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                            onChanged: controlsBusy
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => _effort = value);
                                    }
                                  },
                          ),
                        ],
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: controlsBusy ? null : _test,
                              icon: const Icon(Icons.network_check),
                              label: const Text('连接测试'),
                            ),
                            FilledButton.icon(
                              onPressed: controlsBusy ? null : _save,
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('保存配置'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _thinkingDescription(AiServiceConfig config) {
    if (config.thinkingAlwaysEnabled) return '该模型始终启用思考模式';
    if (!config.supportsThinkingToggle) return '该模型不支持配置思考模式';
    if (!config.supportsReasoningEffort) {
      return '官方接口仅支持开启或关闭，不提供强度档位';
    }
    if (_provider == AiProviderKind.deepSeek ||
        _provider == AiProviderKind.kimi) {
      return '支持 low、high、max 三档强度';
    }
    return '目标模型不支持时，连接测试会返回错误';
  }
}

String _friendlyError(Exception error) => switch (error) {
  AiServiceException() => error.message,
  AiConfigException() => error.message,
  FormatException() => error.message.toString(),
  _ => '操作失败，请重试',
};
