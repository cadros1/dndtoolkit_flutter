import 'package:flutter/material.dart';

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

const _coreFields = <_FieldDefinition>[
  _FieldDefinition('characterName', '角色姓名', '填写确切姓名，或描述你期望的名字'),
  _FieldDefinition('class', '职业', '填写职业及子职，或描述你期望的冒险和战斗风格'),
  _FieldDefinition('race', '种族', '填写种族及亚种，或描述你期望的种族特性'),
  _FieldDefinition('background', '背景', '填写背景，或描述你期望的背景风格'),
  _FieldDefinition('alignment', '阵营', '填写阵营，或描述你期望的行为与道德倾向'),
];

const _referenceFields = <_FieldDefinition>[
  _FieldDefinition('combatRole', '战斗定位', '填写你的想法；留空则由AI自由发挥'),
  _FieldDefinition('magicAndFeatures', '法术/能力倾向', '填写你的想法；留空则由AI自由发挥'),
  _FieldDefinition('equipment', '装备倾向', '填写你的想法；留空则由AI自由发挥'),
  _FieldDefinition('other', '其它想法', '填写你的想法；留空则由AI自由发挥'),
];

const _appearanceFields = <_FieldDefinition>[
  _FieldDefinition('age', '年龄', '角色的年龄'),
  _FieldDefinition('height', '身高', '角色的身高'),
  _FieldDefinition('weight', '体重', '角色的体重'),
  _FieldDefinition('eyes', '眼睛', '眼睛颜色或特征'),
  _FieldDefinition('skin', '皮肤', '皮肤颜色或特征'),
  _FieldDefinition('hair', '头发', '头发颜色、长度或样式'),
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
  _FieldDefinition('additionalFeaturesAndTraits', '附加特征', '角色外观上的附加特征'),
  _FieldDefinition(
    'characterExperience',
    '角色经历',
    '角色在本次冒险前的经历，以及与本次冒险的关联',
  ),
  _FieldDefinition('characterBackstory', '背景故事', '角色一生中影响其人格塑造的重大事件'),
];

class _AiCharacterCreationPageState extends State<AiCharacterCreationPage> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _coreControllers;
  late final Map<String, TextEditingController> _roleplayControllers;
  late final Map<String, bool> _coreAiDecides;
  final _appearanceTendencyController = TextEditingController();
  final _narrativeTendencyController = TextEditingController();
  final _levelController = TextEditingController(text: '1');
  final _budgetController = TextEditingController(text: '27');
  final _rollCountController = TextEditingController(text: '1');
  late final List<TextEditingController> _providedControllers;

  List<AiServiceConfig> _configs = const [];
  String? _selectedConfigId;
  AiAbilityMethod _abilityMethod = AiAbilityMethod.pointBuy;
  bool _omitRoleplay = false;
  bool _appearanceAiDecides = false;
  bool _narrativeAiDecides = false;
  bool _loadingConfigs = true;
  bool _generating = false;
  String? _formError;
  List<AbilityRollGroup>? _rollGroups;
  int? _selectedRollIndex;

  @override
  void initState() {
    super.initState();
    _coreControllers = {
      for (final field in [..._coreFields, ..._referenceFields])
        field.id: TextEditingController(),
    };
    _roleplayControllers = {
      for (final field in [
        ..._appearanceFields,
        ..._personalityFields,
        ..._backgroundFields,
      ])
        field.id: TextEditingController(),
    };
    _coreAiDecides = {for (final field in _coreFields) field.id: false};
    _providedControllers = List.generate(6, (_) => TextEditingController());
    _loadConfigs();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showDisclosureIfNeeded(),
    );
  }

  @override
  void dispose() {
    for (final controller in [
      ..._coreControllers.values,
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
    _appearanceTendencyController.dispose();
    _narrativeTendencyController.dispose();
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
      Navigator.pop(context);
    }
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
      guidance: {
        for (final field in _coreFields)
          field.id: AiGuidanceField(
            text: _coreControllers[field.id]!.text,
            aiDecides: _coreAiDecides[field.id]!,
          ),
        for (final field in _referenceFields)
          field.id: AiGuidanceField(
            text: _coreControllers[field.id]!.text,
            aiDecides: true,
          ),
      },
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
    if (!_formKey.currentState!.validate()) {
      setState(() => _formError = '请修正标出的建卡信息');
      return;
    }
    AiCharacterBuildRequest request;
    try {
      request = _buildRequest();
      final errors = request.validate();
      if (errors.isNotEmpty) throw FormatException(errors.join('；'));
    } on FormatException catch (error) {
      setState(() => _formError = error.message.toString());
      return;
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
    try {
      final result = await widget.service.generate(config, apiKey, request);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('确认六维加点策略'),
            content: SelectableText(formatAbilityStrategy(result.abilities)),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确认并进入编辑器'),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CharacterEditPage(character: result.character),
        ),
      );
      if (saved == true && mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (mounted) setState(() => _formError = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
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
    return Column(
      children: [
        const AppSectionTitle(
          title: '建卡要求',
          subtitle: '如果没有想好某一项如何填写，可以勾选“由 AI 决定”',
          icon: Icons.tune_outlined,
        ),
        AppPanel(
          child: Column(
            children: [
              TextFormField(
                controller: _levelController,
                enabled: !_generating,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '角色总等级 *',
                ),
                validator: (value) {
                  final level = int.tryParse(value?.trim() ?? '');
                  return level == null || level < 1 || level > 20
                      ? '请输入 1–20 的整数'
                      : null;
                },
              ),
              for (final field in _coreFields) ...[
                const SizedBox(height: 16),
                _GuidanceFieldEditor(
                  definition: field,
                  controller: _coreControllers[field.id]!,
                  aiDecides: _coreAiDecides[field.id]!,
                  enabled: !_generating,
                  onAiDecidesChanged: (value) {
                    setState(() => _coreAiDecides[field.id] = value);
                  },
                ),
              ],
              for (final field in _referenceFields) ...[
                const SizedBox(height: 16),
                _ReferenceFieldEditor(
                  definition: field,
                  controller: _coreControllers[field.id]!,
                  enabled: !_generating,
                ),
              ],
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
                        title: '外貌特征',
                        subtitle: '年龄、身高、体重、眼睛、皮肤、头发',
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
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const Text('结构校验失败时会自动追加一次修复请求，可能增加调用费用。AI 结果不会自动保存。'),
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
                _configs.isEmpty ? Icons.settings_outlined : Icons.auto_awesome,
              ),
              label: Text(_configs.isEmpty ? '先配置AI服务' : '生成角色草稿'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_generating,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _generating) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('请先取消正在进行的生成请求')));
        }
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
                          subtitle: '描述角色方向，由AI生成 5E 2014 新卡草稿，再进入编辑器检查。',
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

class _GuidanceFieldEditor extends StatelessWidget {
  const _GuidanceFieldEditor({
    required this.definition,
    required this.controller,
    required this.aiDecides,
    required this.enabled,
    required this.onAiDecidesChanged,
  });

  final _FieldDefinition definition;
  final TextEditingController controller;
  final bool aiDecides;
  final bool enabled;
  final ValueChanged<bool> onAiDecidesChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: ValueKey('${definition.id}-$aiDecides'),
          controller: controller,
          enabled: enabled,
          minLines: 1,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: '${definition.label}${aiDecides ? '' : ' *'}',
            helperText: definition.hint,
          ),
          validator: (value) {
            if (!aiDecides && (value == null || value.trim().isEmpty)) {
              return '请填写${definition.label}，或勾选“由AI决定”';
            }
            return null;
          },
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('由AI决定'),
          subtitle: Text(aiDecides ? '填写你的想法，若留空则完全由AI决定' : 'AI将严格遵循你填写的内容'),
          value: aiDecides,
          onChanged: enabled
              ? (value) => onAiDecidesChanged(value ?? false)
              : null,
        ),
      ],
    );
  }
}

class _ReferenceFieldEditor extends StatelessWidget {
  const _ReferenceFieldEditor({
    required this.definition,
    required this.controller,
    required this.enabled,
  });

  final _FieldDefinition definition;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      minLines: 1,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: definition.label,
        helperText: definition.hint,
      ),
    );
  }
}

class _RoleplayGroupEditor extends StatelessWidget {
  const _RoleplayGroupEditor({
    required this.title,
    required this.subtitle,
    required this.aiDecides,
    required this.tendencyController,
    required this.fields,
    required this.controllers,
    required this.enabled,
    required this.onAiDecidesChanged,
  });

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
          contentPadding: EdgeInsets.zero,
          title: const Text('由AI决定'),
          subtitle: Text(aiDecides ? '填写你的想法，若留空则完全由AI决定' : 'AI将严格遵循你填写的内容'),
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
                  decoration: const InputDecoration(
                    labelText: '你的倾向',
                    helperText: 'AI 将根据填写的内容编写这一整组；留空则自由发挥',
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
