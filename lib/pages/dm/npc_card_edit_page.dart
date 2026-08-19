import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/dm_models.dart';
import '../../widgets/app_ui.dart';

class NpcCardEditPage extends StatefulWidget {
  final NpcCard card;
  final List<NpcCategory> categories;

  const NpcCardEditPage({
    super.key,
    required this.card,
    required this.categories,
  });

  @override
  State<NpcCardEditPage> createState() => _NpcCardEditPageState();
}

class _NpcCardEditPageState extends State<NpcCardEditPage> {
  static const _sections = [
    _EditSection('基础信息', Icons.badge_outlined),
    _EditSection('属性与信息', Icons.psychology_outlined),
    _EditSection('特性与行动', Icons.menu_book_outlined),
  ];

  late NpcCard _card;
  late String _initialJson;
  bool _forceExit = false;
  int _desktopSection = 0;
  late final Map<String, TextEditingController> _abilityControllers;

  @override
  void initState() {
    super.initState();
    _card = widget.card.deepCopy();
    _initialJson = jsonEncode(_card.toJson());
    final ability = _card.abilities;
    _abilityControllers = {
      '力量': TextEditingController(text: '${ability.strength}'),
      '敏捷': TextEditingController(text: '${ability.dexterity}'),
      '体质': TextEditingController(text: '${ability.constitution}'),
      '智力': TextEditingController(text: '${ability.intelligence}'),
      '感知': TextEditingController(text: '${ability.wisdom}'),
      '魅力': TextEditingController(text: '${ability.charisma}'),
    };
  }

  @override
  void dispose() {
    for (final controller in _abilityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasChanges => _initialJson != jsonEncode(_card.toJson());

  String get _title => _card.name.trim().isEmpty ? '新建 NPC 卡' : _card.name;

  void _finish([NpcCard? result]) {
    setState(() => _forceExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  Future<void> _save() async {
    _card
      ..maximumHitPoints = max(0, _card.maximumHitPoints)
      ..armorClass = max(0, _card.armorClass)
      ..abilities.synchronizeModifiers();
    _finish(_card);
  }

  Future<String?> _showExitDialog() => showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('未保存的更改'),
      content: const Text('NPC 卡还有未保存的修改。直接退出将丢失本次编辑内容。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'cancel'),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'discard'),
          child: Text(
            '直接退出',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'save'),
          child: const Text('保存并退出'),
        ),
      ],
    ),
  );

  InputDecoration _decoration(String label) =>
      InputDecoration(labelText: label);

  Widget _textField(
    String label,
    String initialValue,
    ValueChanged<String> onChanged, {
    int minLines = 1,
    int maxLines = 1,
  }) => TextFormField(
    initialValue: initialValue,
    decoration: _decoration(label),
    minLines: minLines,
    maxLines: maxLines,
    onChanged: onChanged,
  );

  Widget _intField(
    String label,
    int initialValue,
    ValueChanged<int> onChanged, {
    bool signed = false,
    bool enabled = true,
  }) => TextFormField(
    key: ValueKey('$label-$initialValue-$enabled'),
    initialValue: initialValue.toString(),
    decoration: _decoration(label),
    enabled: enabled,
    keyboardType: TextInputType.numberWithOptions(signed: signed),
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        signed ? RegExp(r'^-?\d*') : RegExp(r'^\d*'),
      ),
    ],
    onChanged: (value) => onChanged(int.tryParse(value) ?? 0),
  );

  Widget _responsiveFields(List<Widget> fields) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 640 ? 2 : 1;
      final width = columns == 1
          ? constraints.maxWidth
          : (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: fields
            .map((field) => SizedBox(width: width, child: field))
            .toList(),
      );
    },
  );

  Widget _sectionList(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ],
  );

  Widget _buildBasic() => _sectionList([
    const AppSectionTitle(title: '基础信息', icon: Icons.badge_outlined),
    AppPanel(
      child: Column(
        children: [
          _responsiveFields([
            _textField('姓名', _card.name, (value) => _card.name = value),
            DropdownButtonFormField<String?>(
              initialValue: _card.categoryId,
              decoration: _decoration('分类'),
              items: [
                ...widget.categories.map(
                  (category) => DropdownMenuItem<String?>(
                    value: category.id,
                    child: Text(category.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _card.categoryId = value),
            ),
            _textField(
              '体型与生物类型',
              _card.sizeAndType,
              (value) => _card.sizeAndType = value,
            ),
            _textField('速度', _card.speed, (value) => _card.speed = value),
            _intField(
              '最大生命值',
              _card.maximumHitPoints,
              (value) => _card.maximumHitPoints = max(0, value),
            ),
            _intField(
              '护甲等级',
              _card.armorClass,
              (value) => _card.armorClass = max(0, value),
            ),
            _textField(
              '挑战等级',
              _card.challengeRating,
              (value) => _card.challengeRating = value,
            ),
          ]),
        ],
      ),
    ),
  ]);

  Widget _abilityRow(
    String label,
    int score,
    int modifier,
    ValueChanged<int> scoreChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: _abilityControllers[label],
            decoration: _decoration('属性值').copyWith(
              suffixIconConstraints: const BoxConstraints(minWidth: 92),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '$label减 1',
                    onPressed: () {
                      final value = max(0, score - 1);
                      _abilityControllers[label]!.text = '$value';
                      scoreChanged(value);
                    },
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    tooltip: '$label加 1',
                    onPressed: () {
                      final value = score + 1;
                      _abilityControllers[label]!.text = '$value';
                      scoreChanged(value);
                    },
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => scoreChanged(int.tryParse(value) ?? 0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextFormField(
            key: ValueKey('$label-modifier-$modifier'),
            initialValue: modifier >= 0 ? '+$modifier' : '$modifier',
            decoration: _decoration('调整值'),
            enabled: false,
          ),
        ),
      ],
    ),
  );

  Widget _buildAbilities() {
    final ability = _card.abilities;
    return _sectionList([
      const AppSectionTitle(title: '属性与信息', icon: Icons.psychology_outlined),
      AppPanel(
        child: Column(
          children: [
            _abilityRow(
              '力量',
              ability.strength,
              ability.strengthModifier,
              (v) => setState(() {
                ability.strength = v;
                ability.synchronizeModifiers();
              }),
            ),
            _abilityRow(
              '敏捷',
              ability.dexterity,
              ability.dexterityModifier,
              (v) => setState(() {
                ability.dexterity = v;
                ability.synchronizeModifiers();
              }),
            ),
            _abilityRow(
              '体质',
              ability.constitution,
              ability.constitutionModifier,
              (v) => setState(() {
                ability.constitution = v;
                ability.synchronizeModifiers();
              }),
            ),
            _abilityRow(
              '智力',
              ability.intelligence,
              ability.intelligenceModifier,
              (v) => setState(() {
                ability.intelligence = v;
                ability.synchronizeModifiers();
              }),
            ),
            _abilityRow(
              '感知',
              ability.wisdom,
              ability.wisdomModifier,
              (v) => setState(() {
                ability.wisdom = v;
                ability.synchronizeModifiers();
              }),
            ),
            _abilityRow(
              '魅力',
              ability.charisma,
              ability.charismaModifier,
              (v) => setState(() {
                ability.charisma = v;
                ability.synchronizeModifiers();
              }),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      AppPanel(
        child: Column(
          children: [
            _textField(
              '豁免',
              _card.saves,
              (v) => _card.saves = v,
              minLines: 1,
              maxLines: 5,
            ),
            const SizedBox(height: 10),
            _textField(
              '技能',
              _card.skills,
              (v) => _card.skills = v,
              minLines: 1,
              maxLines: 5,
            ),
            const SizedBox(height: 10),
            _textField(
              '感官',
              _card.senses,
              (v) => _card.senses = v,
              minLines: 1,
              maxLines: 5,
            ),
            const SizedBox(height: 10),
            _textField(
              '语言',
              _card.languages,
              (v) => _card.languages = v,
              minLines: 1,
              maxLines: 5,
            ),
            const SizedBox(height: 10),
            _textField(
              '伤害易伤',
              _card.damageVulnerabilities,
              (v) => _card.damageVulnerabilities = v,
              minLines: 1,
              maxLines: 8,
            ),
            const SizedBox(height: 10),
            _textField(
              '伤害抗性',
              _card.damageResistances,
              (v) => _card.damageResistances = v,
              minLines: 1,
              maxLines: 8,
            ),
            const SizedBox(height: 10),
            _textField(
              '伤害免疫',
              _card.damageImmunities,
              (v) => _card.damageImmunities = v,
              minLines: 1,
              maxLines: 8,
            ),
            const SizedBox(height: 10),
            _textField(
              '状态免疫',
              _card.conditionImmunities,
              (v) => _card.conditionImmunities = v,
              minLines: 1,
              maxLines: 8,
            ),
          ],
        ),
      ),
    ]);
  }

  void _moveEntry(List<NpcFeatureEntry> entries, int index, int offset) {
    final target = index + offset;
    if (target < 0 || target >= entries.length) return;
    setState(() {
      final entry = entries.removeAt(index);
      entries.insert(target, entry);
    });
  }

  Widget _entryEditor(List<NpcFeatureEntry> entries, int index) {
    final entry = entries[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppPanel(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          initiallyExpanded: entry.name.isEmpty,
          title: Text(entry.name.trim().isEmpty ? '未命名条目' : entry.name),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _textField('名称', entry.name, (value) {
              entry.name = value;
              setState(() {});
            }),
            const SizedBox(height: 12),
            _textField(
              '描述',
              entry.description,
              (value) {
                entry.description = value;
                setState(() {});
              },
              minLines: 1,
              maxLines: 12,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: '上移',
                  onPressed: index == 0
                      ? null
                      : () => _moveEntry(entries, index, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '下移',
                  onPressed: index == entries.length - 1
                      ? null
                      : () => _moveEntry(entries, index, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '删除条目',
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () => setState(() => entries.removeAt(index)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _entriesSection(String title, List<NpcFeatureEntry> entries) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppSectionTitle(
        title: title,
        trailing: OutlinedButton.icon(
          onPressed: () => setState(() => entries.add(NpcFeatureEntry())),
          icon: const Icon(Icons.add),
          label: const Text('添加'),
        ),
      ),
      ...List.generate(entries.length, (index) => _entryEditor(entries, index)),
      const SizedBox(height: 8),
    ],
  );

  Widget _buildActions() => _sectionList([
    _entriesSection('特性', _card.traits),
    _entriesSection('动作', _card.actions),
    _entriesSection('附赠动作', _card.bonusActions),
    _entriesSection('反应', _card.reactions),
    _entriesSection('传奇动作', _card.legendaryActions),
    const AppSectionTitle(title: '备注', icon: Icons.notes_outlined),
    AppPanel(
      child: _textField(
        '备注',
        _card.notes,
        (value) => _card.notes = value,
        minLines: 1,
        maxLines: 16,
      ),
    ),
  ]);

  Widget _buildSection(int index) => switch (index) {
    0 => _buildBasic(),
    1 => _buildAbilities(),
    2 => _buildActions(),
    _ => _buildBasic(),
  };

  Widget _buildMobile() {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: _sections.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _sections
                .map(
                  (section) =>
                      Tab(icon: Icon(section.icon), text: section.title),
                )
                .toList(),
          ),
        ),
        body: TabBarView(
          children: List.generate(_sections.length, _buildSection),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存并退出'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktop() {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存并退出'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 236,
            child: Material(
              color: cs.surface,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: List.generate(_sections.length, (index) {
                  final section = _sections[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      selected: index == _desktopSection,
                      selectedTileColor: cs.primaryContainer.withValues(
                        alpha: 0.55,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: Icon(section.icon),
                      title: Text(section.title),
                      onTap: () => setState(() => _desktopSection = index),
                    ),
                  );
                }),
              ),
            ),
          ),
          VerticalDivider(width: 1, color: cs.outlineVariant),
          Expanded(child: _buildSection(_desktopSection)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _forceExit,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      if (!_hasChanges) {
        _finish();
        return;
      }
      final action = await _showExitDialog();
      if (action == 'save') {
        await _save();
      } else if (action == 'discard') {
        _finish();
      }
    },
    child: LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= kAppDesktopBreakpoint
          ? _buildDesktop()
          : _buildMobile(),
    ),
  );
}

class _EditSection {
  final String title;
  final IconData icon;

  const _EditSection(this.title, this.icon);
}
