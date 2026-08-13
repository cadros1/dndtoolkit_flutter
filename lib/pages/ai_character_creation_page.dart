import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ai_character_models.dart';
import '../models/ai_service_config.dart';
import '../services/ai_character_service.dart';
import '../services/ai_config_repository.dart';
import '../widgets/app_ui.dart';
import 'ai_service_configs_page.dart';
import 'character_edit_page.dart';

class AiCharacterCreationPage extends StatefulWidget {
  AiCharacterCreationPage({
    super.key,
    AiConfigRepository? repository,
    AiCharacterService? service,
    AbilityRoller? roller,
  }) : repository = repository ?? AiConfigRepository(),
       service = service ?? AiCharacterService(),
       roller = roller ?? AbilityRoller();

  final AiConfigRepository repository;
  final AiCharacterService service;
  final AbilityRoller roller;

  @override
  State<AiCharacterCreationPage> createState() =>
      _AiCharacterCreationPageState();
}

class _FieldDefinition {
  const _FieldDefinition(this.id, this.label, this.hint);
  final String id;
  final String label;
  final String hint;
}

const _choiceFields = <_FieldDefinition>[
  _FieldDefinition('characterName', '角色姓名', ''),
  _FieldDefinition('classAndSubclass', '职业', ''),
  _FieldDefinition('raceAndSubrace', '种族', ''),
  _FieldDefinition('background', '背景', ''),
  _FieldDefinition('alignment', '阵营', ''),
];

const _appearanceFields = <_FieldDefinition>[
  _FieldDefinition('age', '年龄', '角色的年龄'),
  _FieldDefinition('height', '身高', '角色的身高'),
  _FieldDefinition('weight', '体重', '角色的体重'),
  _FieldDefinition('eyes', '眼睛', '眼睛颜色或特征'),
  _FieldDefinition('skin', '皮肤', '皮肤颜色或特征'),
  _FieldDefinition('hair', '头发', '头发颜色、长度或样式'),
  _FieldDefinition('additionalFeaturesAndTraits', '附加特征', '角色外观上的附加特征'),
];

const _personalityFields = <_FieldDefinition>[
  _FieldDefinition('personalityTraits', '个性', '角色稳定的个性与行为特征'),
  _FieldDefinition('ideals', '理想', '角色最重视的信念'),
  _FieldDefinition('bonds', '纽带', '重要人物、地点、承诺或关系'),
  _FieldDefinition('flaws', '缺陷', '容易带来麻烦的弱点'),
];

const _backgroundFields = <_FieldDefinition>[
  _FieldDefinition('alliesAndOrganizations', '盟友与组织', '与角色有关的盟友、敌人或组织'),
  _FieldDefinition('treasure', '所持物', '与背景故事相关联的事物，不是装备或援助物'),
  _FieldDefinition('characterExperience', '角色经历', '角色在本次冒险前的经历，以及与本次冒险的关联'),
  _FieldDefinition('characterBackstory', '背景故事', '角色一生中影响其人格塑造的重大事件'),
];

class _AiCharacterCreationPageState extends State<AiCharacterCreationPage> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _choiceControllers;
  late final Map<String, TextEditingController> _roleplayControllers;
  final _characterDescriptionController = TextEditingController();
  final _gameplayPreferenceController = TextEditingController();
  final _appearanceTendencyController = TextEditingController();
  final _narrativeTendencyController = TextEditingController();
  final _levelController = TextEditingController(text: '1');
  final _budgetController = TextEditingController(text: '27');
  final _rollCountController = TextEditingController(text: '1');
  late final List<TextEditingController> _providedControllers;

  List<AiServiceConfig> _configs = const [];
  String? _selectedConfigId;
  AiAbilityMethod _abilityMethod = AiAbilityMethod.pointBuy;
  bool _generateFromDescription = false;
  bool _omitRoleplay = false;
  bool _appearanceAiDecides = false;
  bool _narrativeAiDecides = false;
  bool _loadingConfigs = true;
  bool _generating = false;
  bool _allowPop = false;
  bool _showingExitConfirmation = false;
  String? _formError;
  List<AbilityRollGroup>? _rollGroups;
  int? _selectedRollIndex;
  AiCharacterBuildRequest? _activeRequest;
  AiBuildPlan? _confirmedPlan;
  AiMechanicsDraft? _mechanicsDraft;
  AiDerivedDraft? _derivedDraft;
  AiNarrativeDraft? _narrativeDraft;
  AiGenerationStage? _activeStage;
  AiGenerationStage? _failedStage;
  Timer? _generationTicker;
  Duration _generationElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _choiceControllers = {
      for (final field in _choiceFields) field.id: TextEditingController(),
    };
    _roleplayControllers = {
      for (final field in [
        ..._appearanceFields,
        ..._personalityFields,
        ..._backgroundFields,
      ])
        field.id: TextEditingController(),
    };
    _providedControllers = List.generate(6, (_) => TextEditingController());
    _loadConfigs();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showDisclosureIfNeeded(),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      ..._choiceControllers.values,
      ..._roleplayControllers.values,
    ]) {
      controller.dispose();
    }
    for (final controller in _providedControllers) {
      controller.dispose();
    }
    _levelController.dispose();
    _budgetController.dispose();
    _rollCountController.dispose();
    _characterDescriptionController.dispose();
    _gameplayPreferenceController.dispose();
    _appearanceTendencyController.dispose();
    _narrativeTendencyController.dispose();
    _generationTicker?.cancel();
    widget.service.cancelCurrentRequest();
    super.dispose();
  }

  Future<void> _showDisclosureIfNeeded() async {
    try {
      if (await widget.repository.hasAcceptedDisclosure() || !mounted) return;
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
      }
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.info_outline, size: 40),
        title: const Text('使用AI建卡前请确认'),
        content: const Text(
          '你填写的建卡信息将发送到所选的第三方AI服务，并可能产生费用。\n\n'
          '本功能仅支持 D&D 5E 2014 官方常规内容，不使用 5E 2024、第三方或自制内容。'
          '生成结果仍需由你在编辑器中检查并主动保存。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('暂不使用'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('同意并继续'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      try {
        await widget.repository.acceptDisclosure();
      } on Exception catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
        }
      }
    } else if (mounted) {
      _popWithoutConfirmation();
    }
  }

  Future<void> _confirmExit() async {
    if (_showingExitConfirmation) return;
    _showingExitConfirmation = true;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出 AI 建卡？'),
        content: const Text('退出后，本页面的所有草稿都不会被保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    _showingExitConfirmation = false;
    if (shouldExit != true || !mounted) return;
    widget.service.cancelCurrentRequest();
    _popWithoutConfirmation();
  }

  void _popWithoutConfirmation([bool? result]) {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  Future<void> _loadConfigs() async {
    setState(() => _loadingConfigs = true);
    try {
      final configs = await widget.repository.loadConfigs();
      final lastId = await widget.repository.getLastConfigId();
      if (!mounted) return;
      setState(() {
        _configs = configs;
        _selectedConfigId = configs.any((item) => item.id == lastId)
            ? lastId
            : configs.firstOrNull?.id;
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _formError = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loadingConfigs = false);
    }
  }

  Future<void> _openConfigs() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AiServiceConfigsPage(repository: widget.repository),
      ),
    );
    if (!mounted) return;
    await _loadConfigs();
  }

  Future<void> _roll() async {
    final count = int.tryParse(_rollCountController.text.trim());
    if (count == null || count < 1 || count > 10) {
      setState(() => _formError = '掷骰组数必须在 1–10 之间');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认生成点数组'),
        content: Text(
          '将立即在本地产生 $count 组点数组，每个点数使用 4d6 移除最低项。\n\n'
          '本次建卡页面会话中只能生成一次，不能重掷或重置。是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认并掷骰'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _rollGroups = widget.roller.rollGroups(count);
      _selectedRollIndex = null;
      _formError = null;
    });
  }

  AiCharacterBuildRequest _buildRequest() {
    final level = int.tryParse(_levelController.text.trim());
    if (level == null) throw const FormatException('请输入有效的角色总等级');
    final selectedId = _selectedConfigId;
    if (selectedId == null) throw const FormatException('请先选择AI服务配置');

    AiAbilitySpec spec;
    switch (_abilityMethod) {
      case AiAbilityMethod.pointBuy:
        final budget = int.tryParse(_budgetController.text.trim());
        if (budget == null) throw const FormatException('请输入有效的购点预算');
        spec = AiAbilitySpec.pointBuy(budget);
        break;
      case AiAbilityMethod.rolled:
        final groups = _rollGroups;
        final index = _selectedRollIndex;
        if (groups == null) throw const FormatException('请先生成点数组');
        if (index == null) throw const FormatException('请选择一组点数组');
        spec = AiAbilitySpec.rolled(groups[index].values);
        break;
      case AiAbilityMethod.providedArray:
        final values = _providedControllers
            .map((controller) => int.tryParse(controller.text.trim()))
            .toList();
        if (values.any((value) => value == null)) {
          throw const FormatException('请填写完整的 6 个属性点数');
        }
        spec = AiAbilitySpec.provided(values.cast<int>());
        break;
      case AiAbilityMethod.standardArray:
        spec = const AiAbilitySpec.standard();
        break;
    }

    return AiCharacterBuildRequest(
      configId: selectedId,
      totalLevel: level,
      requirements: _generateFromDescription
          ? AiBuildRequirements.fromDescription(
              characterDescription: _characterDescriptionController.text,
              gameplayPreference: _gameplayPreferenceController.text,
            )
          : AiBuildRequirements.exactChoices(
              characterName: _choiceControllers['characterName']!.text,
              classAndSubclass: _choiceControllers['classAndSubclass']!.text,
              raceAndSubrace: _choiceControllers['raceAndSubrace']!.text,
              background: _choiceControllers['background']!.text,
              alignment: _choiceControllers['alignment']!.text,
              gameplayPreference: _gameplayPreferenceController.text,
            ),
      roleplay: AiRoleplayInput(
        omit: _omitRoleplay,
        appearanceAiDecides: _appearanceAiDecides,
        appearanceTendency: _appearanceTendencyController.text,
        appearanceValues: {
          for (final field in _appearanceFields)
            field.id: _roleplayControllers[field.id]!.text,
        },
        narrativeAiDecides: _narrativeAiDecides,
        narrativeTendency: _narrativeTendencyController.text,
        narrativeValues: {
          for (final field in [..._personalityFields, ..._backgroundFields])
            field.id: _roleplayControllers[field.id]!.text,
        },
      ),
      abilitySpec: spec,
    );
  }

  Future<void> _generate() async {
    setState(() => _formError = null);
    AiCharacterBuildRequest request;
    if (_confirmedPlan == null) {
      if (!_formKey.currentState!.validate()) {
        setState(() => _formError = '请修正标出的建卡信息');
        return;
      }
      try {
        request = _buildRequest();
        final errors = request.validate();
        if (errors.isNotEmpty) throw FormatException(errors.join('；'));
      } on FormatException catch (error) {
        setState(() => _formError = error.message.toString());
        return;
      }
      _activeRequest = request;
      _mechanicsDraft = null;
      _derivedDraft = null;
      _narrativeDraft = null;
      _failedStage = null;
    } else {
      request = _activeRequest!;
    }

    final config = _configs
        .where((item) => item.id == request.configId)
        .firstOrNull;
    if (config == null) {
      setState(() => _formError = '所选AI服务配置已不存在，请重新选择');
      return;
    }
    late final String apiKey;
    try {
      final storedApiKey = await widget.repository.readApiKey(config.id);
      if (!mounted) return;
      if (storedApiKey == null || storedApiKey.trim().isEmpty) {
        setState(() => _formError = '该配置缺少 API Key，请前往AI服务配置补充');
        return;
      }
      apiKey = storedApiKey;
      await widget.repository.setLastConfigId(config.id);
      if (!mounted) return;
    } on Exception catch (error) {
      if (mounted) setState(() => _formError = _friendlyError(error));
      return;
    }
    setState(() => _generating = true);
    final hasPendingGeneration =
        _confirmedPlan == null ||
        _mechanicsDraft == null ||
        _derivedDraft == null ||
        _narrativeDraft == null;
    if (hasPendingGeneration) {
      _startGenerationTimer(reset: true);
    } else {
      _resetGenerationTimer();
    }
    try {
      var plan = _confirmedPlan;
      if (plan == null) {
        _setActiveStage(AiGenerationStage.plan);
        final generatedPlan = await widget.service.generateBuildPlan(
          config,
          apiKey,
          request,
        );
        if (!mounted) return;
        _pauseGenerationTimer();
        plan = await showDialog<AiBuildPlan>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _BuildPlanDialog(
            plan: generatedPlan,
            totalLevel: request.totalLevel,
            editsGeneratedIdentity:
                request.requirements.mode ==
                AiBuildRequirementMode.fromDescription,
          ),
        );
        if (plan == null || !mounted) {
          setState(() => _activeStage = null);
          return;
        }
        setState(() {
          _confirmedPlan = plan;
          _failedStage = null;
        });
        _startGenerationTimer();
      }
      await _continueGeneration(config, apiKey, request, plan);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _failedStage = _activeStage;
          _formError = _friendlyError(error);
        });
      }
    } finally {
      if (mounted) {
        _stopGenerationTimer();
        setState(() {
          _generating = false;
          _activeStage = null;
        });
      }
    }
  }

  void _startGenerationTimer({bool reset = false}) {
    if (reset) {
      _generationTicker?.cancel();
      _generationTicker = null;
      _generationElapsed = Duration.zero;
    }
    if (_generationTicker != null) return;
    _generationTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _generationElapsed += const Duration(seconds: 1));
    });
  }

  void _pauseGenerationTimer() {
    _generationTicker?.cancel();
    _generationTicker = null;
  }

  void _stopGenerationTimer() => _pauseGenerationTimer();

  void _resetGenerationTimer() {
    _generationTicker?.cancel();
    _generationTicker = null;
    if (mounted) setState(() => _generationElapsed = Duration.zero);
  }

  void _adjustTotalLevel(int delta) {
    final current = int.tryParse(_levelController.text.trim());
    final next = current == null
        ? aiCharacterMinLevel
        : (current + delta).clamp(aiCharacterMinLevel, aiCharacterMaxLevel);
    final text = '$next';
    _levelController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  void _setActiveStage(AiGenerationStage stage) {
    if (mounted) {
      setState(() {
        _activeStage = stage;
        _failedStage = null;
        _formError = null;
      });
    }
  }

  Future<void> _continueGeneration(
    AiServiceConfig config,
    String apiKey,
    AiCharacterBuildRequest request,
    AiBuildPlan plan,
  ) async {
    var mechanics = _mechanicsDraft;
    if (mechanics == null) {
      _setActiveStage(AiGenerationStage.mechanics);
      mechanics = await widget.service.generateMechanics(
        config,
        apiKey,
        request,
        plan,
      );
      if (!mounted) return;
      setState(() => _mechanicsDraft = mechanics);
    }

    var derived = _derivedDraft;
    if (derived == null) {
      _setActiveStage(AiGenerationStage.derived);
      derived = await widget.service.generateDerived(
        config,
        apiKey,
        request,
        plan,
        mechanics,
      );
      if (!mounted) return;
      setState(() => _derivedDraft = derived);
    }

    var narrative = _narrativeDraft;
    if (narrative == null) {
      if (needsNarrativeStage(request)) {
        _setActiveStage(AiGenerationStage.narrative);
        narrative = await widget.service.generateNarrative(
          config,
          apiKey,
          request,
          plan,
          mechanics,
        );
      } else {
        narrative = AiNarrativeDraft.empty;
      }
      if (!mounted) return;
      setState(() => _narrativeDraft = narrative);
    }

    final character = AiCharacterAssembly.toCharacter(
      request: request,
      plan: plan,
      mechanics: mechanics,
      derived: derived,
      narrative: narrative,
    );
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('使用前请确认'),
          content: const Text('AI生成的角色卡可能包含错误，在使用之前请务必进行人工检查，并与你的DM沟通。'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('我已知晓'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterEditPage(character: character),
      ),
    );
    if (saved == true && mounted) _popWithoutConfirmation(true);
  }

  Widget _configSection() {
    return Column(
      children: [
        const AppSectionTitle(title: 'AI 服务', icon: Icons.smart_toy_outlined),
        AppPanel(
          child: _loadingConfigs
              ? const LinearProgressIndicator()
              : _configs.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('还没有可用配置。API Key 需要先保存在AI服务配置中。'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _openConfigs,
                      icon: const Icon(Icons.add),
                      label: const Text('新建AI服务配置'),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedConfigId,
                        decoration: const InputDecoration(labelText: '建卡配置 *'),
                        items: _configs.map((config) {
                          return DropdownMenuItem(
                            value: config.id,
                            child: Text(
                              '${config.name} · ${config.model}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _generating
                            ? null
                            : (value) =>
                                  setState(() => _selectedConfigId = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      tooltip: '管理AI服务配置',
                      onPressed: _generating ? null : _openConfigs,
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _basicSection() {
    final currentLevel = int.tryParse(_levelController.text.trim());
    final canDecreaseLevel =
        !_generating &&
        (currentLevel == null || currentLevel > aiCharacterMinLevel);
    final canIncreaseLevel =
        !_generating &&
        (currentLevel == null || currentLevel < aiCharacterMaxLevel);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const AppSectionTitle(title: '建卡要求', icon: Icons.tune_outlined),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('角色总等级 *', style: textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                '最高可创建5级角色',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('total-level-field'),
                controller: _levelController,
                enabled: !_generating,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixIcon: IconButton(
                    key: const ValueKey('decrease-total-level-button'),
                    tooltip: '降低角色总等级',
                    onPressed: canDecreaseLevel
                        ? () => _adjustTotalLevel(-1)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  suffixIcon: IconButton(
                    key: const ValueKey('increase-total-level-button'),
                    tooltip: '提高角色总等级',
                    onPressed: canIncreaseLevel
                        ? () => _adjustTotalLevel(1)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final level = int.tryParse(value?.trim() ?? '');
                  return level == null ||
                          level < aiCharacterMinLevel ||
                          level > aiCharacterMaxLevel
                      ? '请输入 1–5 的整数'
                      : null;
                },
              ),
              SwitchListTile(
                key: const ValueKey('generate-from-description-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('从你的想法生成'),
                value: _generateFromDescription,
                onChanged: _generating
                    ? null
                    : (value) {
                        setState(() => _generateFromDescription = value);
                      },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: _generateFromDescription
                    ? TextFormField(
                        key: const ValueKey('character-description-field'),
                        controller: _characterDescriptionController,
                        enabled: !_generating,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: '角色描述 *',
                          helperText: '描述你想要扮演一个什么样的角色',
                        ),
                        validator: _requiredField,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (
                            var index = 0;
                            index < _choiceFields.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(height: 16),
                            TextFormField(
                              key: ValueKey(
                                '${_choiceFields[index].id}-choice-field',
                              ),
                              controller:
                                  _choiceControllers[_choiceFields[index].id],
                              enabled: !_generating,
                              decoration: InputDecoration(
                                labelText: '${_choiceFields[index].label} *',
                              ),
                              validator: _requiredField,
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('gameplay-preference-field'),
                controller: _gameplayPreferenceController,
                enabled: !_generating,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '玩法偏好 *',
                  helperText: '描述你在战斗中和冒险中的行为风格',
                ),
                validator: _requiredField,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roleplaySection() {
    return Column(
      children: [
        AppSectionTitle(
          title: '人物塑造',
          subtitle: '外貌与人物设定',
          icon: Icons.menu_book_outlined,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('无需添加'),
              Switch(
                key: const ValueKey('omit-roleplay-switch'),
                value: _omitRoleplay,
                onChanged: _generating
                    ? null
                    : (value) {
                        setState(() => _omitRoleplay = value);
                      },
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _omitRoleplay
              ? const SizedBox.shrink()
              : AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RoleplayGroupEditor(
                        switchKey: const ValueKey(
                          'generate-appearance-from-description-switch',
                        ),
                        title: '外貌特征',
                        subtitle: '年龄、身高、体重、眼睛、皮肤、头发和附加特征',
                        aiDecides: _appearanceAiDecides,
                        tendencyController: _appearanceTendencyController,
                        fields: _appearanceFields,
                        controllers: _roleplayControllers,
                        enabled: !_generating,
                        onAiDecidesChanged: (value) {
                          setState(() => _appearanceAiDecides = value);
                        },
                      ),
                      const SizedBox(height: 24),
                      _RoleplayGroupEditor(
                        switchKey: const ValueKey(
                          'generate-narrative-from-description-switch',
                        ),
                        title: '个性特征与背景设定',
                        subtitle: '个性、理想、纽带、缺陷，以及角色的关系和经历',
                        aiDecides: _narrativeAiDecides,
                        tendencyController: _narrativeTendencyController,
                        fields: const [
                          ..._personalityFields,
                          ..._backgroundFields,
                        ],
                        controllers: _roleplayControllers,
                        enabled: !_generating,
                        onAiDecidesChanged: (value) {
                          setState(() => _narrativeAiDecides = value);
                        },
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _abilitySection() {
    return Column(
      children: [
        const AppSectionTitle(
          title: '六维属性',
          subtitle: 'AI 将分配基础点数，并分别给出种族与等级提升。',
          icon: Icons.casino_outlined,
        ),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<AiAbilityMethod>(
                initialValue: _abilityMethod,
                decoration: const InputDecoration(labelText: '生成方式 *'),
                items: AiAbilityMethod.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: _generating || _rollGroups != null
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _abilityMethod = value);
                        }
                      },
              ),
              const SizedBox(height: 16),
              switch (_abilityMethod) {
                AiAbilityMethod.pointBuy => _pointBuyEditor(),
                AiAbilityMethod.rolled => _rolledEditor(),
                AiAbilityMethod.providedArray => _providedEditor(),
                AiAbilityMethod.standardArray => const Text(
                  'AI 会将[15、14、13、12、10、8]分配至六维属性。',
                ),
              },
            ],
          ),
        ),
      ],
    );
  }

  Widget _pointBuyEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextFormField(
        controller: _budgetController,
        enabled: !_generating,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: '可用购点点数 *'),
        validator: (value) {
          final budget = int.tryParse(value?.trim() ?? '');
          if (budget == null || budget < 0 || budget > 54) {
            return '请输入 0–54 的整数';
          }
          if (!PointBuyRules.canSpendExactly(budget)) {
            return '该预算无法由 6 项标准费用恰好组成';
          }
          return null;
        },
      ),
      const SizedBox(height: 12),
      const Text('购点法首先假设六维属性均为8，然后使用一定的点数来购买属性。5E 2014规则下通常使用27点购点法。'),
    ],
  );

  Widget _rolledEditor() {
    final groups = _rollGroups;
    if (groups == null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextFormField(
              controller: _rollCountController,
              enabled: !_generating,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '生成组数 *'),
              validator: (value) {
                final count = int.tryParse(value?.trim() ?? '');
                return count == null || count < 1 || count > 10
                    ? '请输入 1–10 的整数'
                    : null;
              },
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _generating ? null : _roll,
            icon: const Icon(Icons.casino),
            label: const Text('确认并生成'),
          ),
        ],
      );
    }
    return RadioGroup<int>(
      groupValue: _selectedRollIndex,
      onChanged: _generating
          ? (_) {}
          : (value) => setState(() => _selectedRollIndex = value),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('本会话已生成 ${groups.length} 组；请选择一组。退出页面前不能重掷。'),
          const SizedBox(height: 8),
          for (var index = 0; index < groups.length; index++)
            RadioListTile<int>(
              value: index,
              enabled: !_generating,
              title: Text('第 ${index + 1} 组：${groups[index].values.join('、')}'),
              subtitle: Text(
                '总和：${groups[index].values.fold<int>(0, (sum, value) => sum + value)}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _providedEditor() => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth >= 560
          ? (constraints.maxWidth - 40) / 6
          : (constraints.maxWidth - 16) / 3;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('输入顺序不影响属性，由 AI 自行分配。'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(6, (index) {
              return SizedBox(
                width: width,
                child: TextFormField(
                  controller: _providedControllers[index],
                  enabled: !_generating,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: '点数 ${index + 1}'),
                  validator: (value) {
                    if (_abilityMethod != AiAbilityMethod.providedArray) {
                      return null;
                    }
                    final score = int.tryParse(value?.trim() ?? '');
                    return score == null || score < 3 || score > 18
                        ? '3–18'
                        : null;
                  },
                ),
              );
            }),
          ),
        ],
      );
    },
  );

  Widget _submitSection() {
    final cs = Theme.of(context).colorScheme;
    final plan = _confirmedPlan;
    final currentStage = _activeStage ?? _failedStage;
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (plan != null) ...[
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已确认构筑方案',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${plan.classAndLevel} · ${plan.raceAndSubrace} · ${plan.background}',
            ),
            Text('战斗：${plan.combatRole}'),
            Text('冒险：${plan.adventureRole}'),
            const SizedBox(height: 16),
          ],
          if (currentStage != null) ...[
            Semantics(
              label:
                  'AI 建卡第 ${currentStage.number} 阶段，共 4 阶段：${currentStage.label}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _generating
                        ? '正在进行第 ${currentStage.number}/4 阶段：${currentStage.label}'
                        : '第 ${currentStage.number}/4 阶段失败：${currentStage.label}',
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: currentStage.number / 4),
                  const SizedBox(height: 8),
                  _GenerationElapsedTime(elapsed: _generationElapsed),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_formError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formError!,
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            '一次建卡通常产生 3–4 次请求；每个阶段校验失败时会自动追加一次修复请求，可能增加调用费用。AI 结果不会自动保存。',
          ),
          const SizedBox(height: 16),
          if (_generating) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.service.cancelCurrentRequest,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('取消生成'),
            ),
          ] else
            FilledButton.icon(
              onPressed: _configs.isEmpty ? _openConfigs : _generate,
              icon: Icon(
                _configs.isEmpty
                    ? Icons.settings_outlined
                    : _failedStage != null
                    ? Icons.refresh
                    : Icons.auto_awesome,
              ),
              label: Text(
                _configs.isEmpty
                    ? '先配置AI服务'
                    : _failedStage != null
                    ? '从${_failedStage!.label}重试'
                    : _confirmedPlan != null && _narrativeDraft != null
                    ? '重新进入角色草稿'
                    : '生成角色草稿',
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('AI 建卡')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 840),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppPageHeader(
                          icon: Icons.auto_awesome,
                          title: 'AI 建卡',
                          subtitle: '生成结果可能与规则冲突，请务必对照规则复核并与你的 DM 沟通',
                        ),
                        const SizedBox(height: 16),
                        _configSection(),
                        const SizedBox(height: 16),
                        _basicSection(),
                        const SizedBox(height: 16),
                        _roleplaySection(),
                        const SizedBox(height: 16),
                        _abilitySection(),
                        const SizedBox(height: 20),
                        _submitSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _friendlyError(Exception error) => switch (error) {
  AiServiceException() => error.message,
  AiConfigException() => error.message,
  FormatException() => error.message.toString(),
  _ => '操作失败，请重试',
};

String? _requiredField(String? value) =>
    value == null || value.trim().isEmpty ? '此项为必填项' : null;

class _GenerationElapsedTime extends StatelessWidget {
  const _GenerationElapsedTime({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final formatted = _formatDuration(elapsed);
    return Semantics(
      label: '本次生成用时 $formatted',
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text('本次生成用时')),
          SizedBox(
            width: 72,
            child: Text(
              key: const ValueKey('generation-elapsed-value'),
              formatted,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}

class _RoleplayGroupEditor extends StatelessWidget {
  const _RoleplayGroupEditor({
    required this.switchKey,
    required this.title,
    required this.subtitle,
    required this.aiDecides,
    required this.tendencyController,
    required this.fields,
    required this.controllers,
    required this.enabled,
    required this.onAiDecidesChanged,
  });

  final Key switchKey;
  final String title;
  final String subtitle;
  final bool aiDecides;
  final TextEditingController tendencyController;
  final List<_FieldDefinition> fields;
  final Map<String, TextEditingController> controllers;
  final bool enabled;
  final ValueChanged<bool> onAiDecidesChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(subtitle, style: textTheme.bodySmall),
        SwitchListTile(
          key: switchKey,
          contentPadding: EdgeInsets.zero,
          title: const Text('从你的想法生成'),
          value: aiDecides,
          onChanged: enabled ? onAiDecidesChanged : null,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: aiDecides
              ? TextFormField(
                  controller: tendencyController,
                  enabled: enabled,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: title,
                    helperText: '描述你对角色$title的想法或偏好',
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < fields.length; index++) ...[
                      if (fields[index].id == 'personalityTraits') ...[
                        Text('个性特征', style: textTheme.titleSmall),
                        const SizedBox(height: 8),
                      ],
                      if (fields[index].id == 'alliesAndOrganizations') ...[
                        const SizedBox(height: 8),
                        Text('背景设定', style: textTheme.titleSmall),
                        const SizedBox(height: 8),
                      ],
                      if (index > 0 &&
                          fields[index].id != 'alliesAndOrganizations')
                        const SizedBox(height: 12),
                      TextFormField(
                        key: ValueKey('${fields[index].id}-exact'),
                        controller: controllers[fields[index].id],
                        enabled: enabled,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: fields[index].label,
                          helperText: fields[index].hint,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _BuildPlanDialog extends StatefulWidget {
  const _BuildPlanDialog({
    required this.plan,
    required this.totalLevel,
    required this.editsGeneratedIdentity,
  });

  final AiBuildPlan plan;
  final int totalLevel;
  final bool editsGeneratedIdentity;

  @override
  State<_BuildPlanDialog> createState() => _BuildPlanDialogState();
}

class _BuildPlanDialogState extends State<_BuildPlanDialog> {
  late final List<_BuildPlanClassControllers> _classes;
  late final TextEditingController _characterName;
  late final TextEditingController _alignment;
  late final TextEditingController _race;
  late final TextEditingController _background;
  late final TextEditingController _combatRole;
  late final TextEditingController _adventureRole;
  late final TextEditingController _synergy;
  late final TextEditingController _warnings;
  String? _error;

  @override
  void initState() {
    super.initState();
    _classes = widget.plan.classes
        .map(_BuildPlanClassControllers.fromPlan)
        .toList(growable: true);
    _characterName = TextEditingController(text: widget.plan.characterName);
    _alignment = TextEditingController(text: widget.plan.alignment);
    _race = TextEditingController(text: widget.plan.raceAndSubrace);
    _background = TextEditingController(text: widget.plan.background);
    _combatRole = TextEditingController(text: widget.plan.combatRole);
    _adventureRole = TextEditingController(text: widget.plan.adventureRole);
    _synergy = TextEditingController(text: widget.plan.synergy);
    _warnings = TextEditingController(text: widget.plan.warnings);
  }

  @override
  void dispose() {
    for (final item in _classes) {
      item.dispose();
    }
    _characterName.dispose();
    _alignment.dispose();
    _race.dispose();
    _background.dispose();
    _combatRole.dispose();
    _adventureRole.dispose();
    _synergy.dispose();
    _warnings.dispose();
    super.dispose();
  }

  void _addClass() {
    if (_classes.length >= 4) return;
    setState(() {
      _classes.add(_BuildPlanClassControllers.empty());
      _error = null;
    });
  }

  void _removeClass(int index) {
    if (_classes.length <= 1) return;
    setState(() {
      _classes.removeAt(index).dispose();
      _error = null;
    });
  }

  void _confirm() {
    final classes = <AiBuildPlanClass>[];
    for (final item in _classes) {
      final level = int.tryParse(item.level.text.trim());
      if (item.name.text.trim().isEmpty || level == null) {
        setState(() => _error = '请填写完整、有效的职业名称和等级');
        return;
      }
      classes.add(
        AiBuildPlanClass(
          name: item.name.text.trim(),
          level: level,
          subclass: item.subclass.text.trim(),
        ),
      );
    }
    final plan = AiBuildPlan(
      characterName: _characterName.text.trim(),
      alignment: _alignment.text.trim(),
      classes: classes,
      raceAndSubrace: _race.text.trim(),
      background: _background.text.trim(),
      combatRole: _combatRole.text.trim(),
      adventureRole: _adventureRole.text.trim(),
      synergy: _synergy.text.trim(),
      warnings: _warnings.text.trim(),
    );
    final errors = plan.validate(
      widget.totalLevel,
      requireIdentity: widget.editsGeneratedIdentity,
    );
    if (errors.isNotEmpty) {
      setState(() => _error = errors.join('；'));
      return;
    }
    Navigator.pop(context, plan);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('确认并修改构筑方案'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('请检查以下内容。你在这里的修改会完全覆盖 AI 的原方案，并作为后续三个阶段的硬约束。'),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: '${widget.totalLevel}',
                readOnly: true,
                enabled: false,
                decoration: const InputDecoration(labelText: '角色总等级'),
              ),
              const SizedBox(height: 16),
              if (widget.editsGeneratedIdentity) ...[
                _planField(
                  _characterName,
                  '角色姓名 *',
                  fieldKey: const ValueKey('confirmed-character-name-field'),
                ),
                const SizedBox(height: 12),
                _planField(
                  _alignment,
                  '阵营 *',
                  fieldKey: const ValueKey('confirmed-alignment-field'),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '职业组成',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _classes.length < 4 ? _addClass : null,
                    icon: const Icon(Icons.add),
                    label: const Text('添加兼职'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < _classes.length; index++) ...[
                _BuildPlanClassEditor(
                  index: index,
                  controllers: _classes[index],
                  canRemove: _classes.length > 1,
                  onRemove: () => _removeClass(index),
                ),
                if (index < _classes.length - 1) const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              _planField(
                _race,
                '种族与亚种 *',
                fieldKey: const ValueKey('confirmed-race-field'),
              ),
              const SizedBox(height: 12),
              _planField(_background, '背景 *'),
              const SizedBox(height: 12),
              _planField(_combatRole, '战斗定位 *', lines: 2),
              const SizedBox(height: 12),
              _planField(_adventureRole, '冒险定位 *', lines: 2),
              const SizedBox(height: 12),
              _planField(_synergy, '构筑思路', lines: 2),
              const SizedBox(height: 12),
              _planField(_warnings, '需要重点复核的事项', lines: 2),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(_error!, style: TextStyle(color: cs.error)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('返回修改要求'),
        ),
        FilledButton(onPressed: _confirm, child: const Text('确认并继续生成')),
      ],
    );
  }

  Widget _planField(
    TextEditingController controller,
    String label, {
    int lines = 1,
    Key? fieldKey,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      minLines: lines,
      maxLines: lines == 1 ? 1 : 4,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _BuildPlanClassControllers {
  _BuildPlanClassControllers({
    required this.name,
    required this.level,
    required this.subclass,
  });

  factory _BuildPlanClassControllers.fromPlan(AiBuildPlanClass value) {
    return _BuildPlanClassControllers(
      name: TextEditingController(text: value.name),
      level: TextEditingController(text: '${value.level}'),
      subclass: TextEditingController(text: value.subclass),
    );
  }

  factory _BuildPlanClassControllers.empty() {
    return _BuildPlanClassControllers(
      name: TextEditingController(),
      level: TextEditingController(text: '1'),
      subclass: TextEditingController(),
    );
  }

  final TextEditingController name;
  final TextEditingController level;
  final TextEditingController subclass;

  void dispose() {
    name.dispose();
    level.dispose();
    subclass.dispose();
  }
}

class _BuildPlanClassEditor extends StatelessWidget {
  const _BuildPlanClassEditor({
    required this.index,
    required this.controllers,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final _BuildPlanClassControllers controllers;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fields = [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: controllers.name,
              decoration: InputDecoration(labelText: '职业 ${index + 1} *'),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controllers.level,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '等级 *'),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: controllers.subclass,
              decoration: const InputDecoration(labelText: '子职（如已获得）'),
            ),
          ),
        ];
        final remove = IconButton(
          onPressed: canRemove ? onRemove : null,
          tooltip: '移除此职业',
          icon: const Icon(Icons.remove_circle_outline),
        );
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  fields[0],
                  const SizedBox(width: 8),
                  fields[1],
                  remove,
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [fields[2]]),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            fields[0],
            const SizedBox(width: 8),
            fields[1],
            const SizedBox(width: 8),
            fields[2],
            remove,
          ],
        );
      },
    );
  }
}
