import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/dm_models.dart';
import '../../services/dm_rules.dart';
import '../../widgets/app_ui.dart';

class CurrentEncounterView extends StatefulWidget {
  final DmData data;
  final Future<void> Function() onChanged;
  final Future<void> Function([EncounterGroup? targetGroup]) onAddNpc;

  const CurrentEncounterView({
    super.key,
    required this.data,
    required this.onChanged,
    required this.onAddNpc,
  });

  @override
  State<CurrentEncounterView> createState() => _CurrentEncounterViewState();
}

class _CurrentEncounterViewState extends State<CurrentEncounterView> {
  final _random = Random();
  final List<_DmRollLog> _logs = [];
  String? _selectedInstanceId;

  CurrentEncounter get _encounter => widget.data.encounter;

  Future<void> _commit() async {
    if (mounted) setState(() {});
    await widget.onChanged();
  }

  List<_EncounterUnit> get _units {
    final units = <_EncounterUnit>[
      ..._encounter.instances
          .where((instance) => instance.groupId == null)
          .map(_EncounterUnit.instance),
      ..._encounter.groups.map(_EncounterUnit.group),
    ];
    units.sort((left, right) {
      final leftInitiative = left.initiative;
      final rightInitiative = right.initiative;
      if (leftInitiative == null && rightInitiative != null) return 1;
      if (leftInitiative != null && rightInitiative == null) return -1;
      if (leftInitiative != rightInitiative) {
        return rightInitiative!.compareTo(leftInitiative!);
      }
      return left.sortOrder.compareTo(right.sortOrder);
    });
    return units;
  }

  NpcInstance? get _selectedInstance => _encounter.instances
      .where((instance) => instance.id == _selectedInstanceId)
      .firstOrNull;

  String _displayName(NpcInstance instance) =>
      instance.displayName.trim().isEmpty
      ? '未命名 NPC'
      : instance.displayName.trim();

  Future<void> _moveTie(_EncounterUnit unit, int offset) async {
    final tied = _units
        .where((item) => item.initiative == unit.initiative)
        .toList();
    final index = tied.indexWhere((item) => item.id == unit.id);
    final target = index + offset;
    if (index < 0 || target < 0 || target >= tied.length) return;
    final other = tied[target];
    final order = unit.sortOrder;
    unit.sortOrder = other.sortOrder;
    other.sortOrder = order;
    await _commit();
  }

  Future<void> _editInitiative(NpcInstance instance) async {
    final controller = TextEditingController(
      text: instance.initiative?.toString() ?? '',
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置「${_displayName(instance)}」的先攻'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
          ],
          decoration: const InputDecoration(labelText: '先攻值'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      instance.initiative = int.tryParse(controller.text);
      await _commit();
    }
    controller.dispose();
  }

  Future<void> _editGroupInitiative(EncounterGroup group) async {
    final controller = TextEditingController(
      text: group.initiative?.toString() ?? '',
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '设置「${group.name.trim().isEmpty ? '未命名集群' : group.name}」的先攻',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
          ],
          decoration: const InputDecoration(labelText: '集群先攻'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      group.initiative = int.tryParse(controller.text);
    }
    await Future<void>.delayed(kThemeAnimationDuration);
    controller.dispose();
    if (accepted == true) await _commit();
  }

  Future<void> _editHitPoints(
    NpcInstance instance, {
    required bool temporary,
  }) async {
    final current = temporary
        ? instance.temporaryHitPoints
        : instance.currentHitPoints;
    final controller = TextEditingController(text: current.toString());
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(temporary ? '编辑临时生命值' : '编辑当前生命值'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: temporary ? '临时生命值' : '当前生命值'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      final value = int.tryParse(controller.text) ?? current;
      temporary
          ? instance.setTemporaryHitPoints(value)
          : instance.setCurrentHitPoints(value);
      await _commit();
    }
    controller.dispose();
  }

  Future<void> _duplicateInstance(NpcInstance instance) async {
    final existingNames = _encounter.instances
        .map((item) => item.displayName)
        .toSet();
    var number = 2;
    var name = '${_displayName(instance)} $number';
    while (existingNames.contains(name)) {
      number++;
      name = '${_displayName(instance)} $number';
    }
    _encounter.instances.add(
      instance.duplicate(name: name, order: _encounter.nextSortOrder),
    );
    await _commit();
  }

  Future<void> _removeInstance(NpcInstance instance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移出当前遭遇'),
        content: Text('确定要将「${_displayName(instance)}」移出当前遭遇吗？'),
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
            child: const Text('移出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _encounter.instances.removeWhere((item) => item.id == instance.id);
    if (_selectedInstanceId == instance.id) _selectedInstanceId = null;
    await _commit();
  }

  Future<void> _moveInstance(NpcInstance instance) async {
    final destination = await showDialog<String?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('移动实例'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, '__independent__'),
            child: const ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('转为独立 NPC'),
            ),
          ),
          ..._encounter.groups.map(
            (group) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, group.id),
              child: ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(group.name.trim().isEmpty ? '未命名集群' : group.name),
              ),
            ),
          ),
        ],
      ),
    );
    if (destination == null) return;
    if (destination == '__independent__') {
      widget.data.moveInstanceOutOfGroup(instance.id);
    } else {
      widget.data.assignInstancesToGroup([instance.id], destination);
    }
    await _commit();
  }

  Future<void> _createOrEditGroup([EncounterGroup? group]) async {
    final editing =
        group ?? EncounterGroup(sortOrder: _encounter.nextSortOrder);
    final name = TextEditingController(text: editing.name);
    final initiative = TextEditingController(
      text: editing.initiative?.toString() ?? '',
    );
    final selected = _encounter.instances
        .where((instance) => instance.groupId == editing.id)
        .map((instance) => instance.id)
        .toSet();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(group == null ? '创建集群' : '编辑集群'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: '集群名称'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: initiative,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                    ],
                    decoration: const InputDecoration(labelText: '集群先攻'),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '成员',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_encounter.instances.isEmpty)
                    const ListTile(title: Text('当前遭遇还没有 NPC 实例'))
                  else
                    ..._encounter.instances.map(
                      (instance) => CheckboxListTile(
                        value: selected.contains(instance.id),
                        title: Text(_displayName(instance)),
                        onChanged: (value) => setDialogState(() {
                          value == true
                              ? selected.add(instance.id)
                              : selected.remove(instance.id);
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      editing
        ..name = name.text.trim()
        ..initiative = int.tryParse(initiative.text);
      if (group == null) _encounter.groups.add(editing);
      final previousMembers = _encounter
          .membersOf(editing.id)
          .map((item) => item.id)
          .toSet();
      for (final id in previousMembers.difference(selected)) {
        widget.data.moveInstanceOutOfGroup(id);
      }
      widget.data.assignInstancesToGroup(selected, editing.id);
      await _commit();
    }
    name.dispose();
    initiative.dispose();
  }

  Future<void> _deleteGroup(EncounterGroup group) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除集群'),
        content: const Text('请选择如何处理集群中的 NPC 成员。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'keep'),
            child: const Text('成员转为独立 NPC'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, 'remove'),
            child: const Text('连同成员一起移出'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    widget.data.deleteGroup(group.id, removeMembers: choice == 'remove');
    await _commit();
  }

  Future<void> _endEncounter() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('结束当前遭遇'),
        content: const Text('所有实例、集群、生命值和先攻状态都会被清空，且不会保留遭遇历史。'),
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
            child: const Text('确认结束'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.data.encounter = CurrentEncounter();
    _selectedInstanceId = null;
    await _commit();
  }

  void _roll({
    required int sides,
    required int count,
    required int bonus,
    required DmAdvantageState advantage,
  }) {
    final created = <_DmRollLog>[];
    for (var i = 0; i < count; i++) {
      final first = _random.nextInt(sides) + 1;
      final second = advantage == DmAdvantageState.normal
          ? null
          : _random.nextInt(sides) + 1;
      final result = DmRules.resolveRoll(
        sides: sides,
        firstDie: first,
        secondDie: second,
        bonus: bonus,
        advantage: advantage,
      );
      final dice = second == null
          ? '$first'
          : '${advantage == DmAdvantageState.advantage ? '优势' : '劣势'}[$first, $second] → ${result.selectedDie}';
      created.add(
        _DmRollLog(
          title: 'D$sides',
          result: result.total,
          detail:
              '$dice ${bonus >= 0 ? '+' : '−'} ${bonus.abs()} = ${result.total}',
        ),
      );
    }
    setState(() => _logs.insertAll(0, created));
  }

  Future<void> _showDice() async {
    var sides = 20;
    var count = 1;
    var bonus = 0;
    var advantage = DmAdvantageState.normal;

    Widget content(
      BuildContext context,
      StateSetter setDialogState,
    ) => SizedBox(
      width: 680,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              initialValue: sides,
              decoration: const InputDecoration(labelText: '骰面'),
              items: [4, 6, 8, 10, 12, 20, 100]
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text('D$value')),
                  )
                  .toList(),
              onChanged: (value) => setDialogState(() => sides = value ?? 20),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: count,
              decoration: const InputDecoration(labelText: '次数'),
              items: [1, 2, 3, 4, 5, 10]
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text('$value 次')),
                  )
                  .toList(),
              onChanged: (value) => setDialogState(() => count = value ?? 1),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: '0',
              decoration: const InputDecoration(labelText: '总加值'),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
              ],
              onChanged: (value) => bonus = int.tryParse(value) ?? 0,
            ),
            const SizedBox(height: 12),
            SegmentedButton<DmAdvantageState>(
              segments: const [
                ButtonSegment(
                  value: DmAdvantageState.disadvantage,
                  label: Text('劣势'),
                ),
                ButtonSegment(
                  value: DmAdvantageState.normal,
                  label: Text('正常'),
                ),
                ButtonSegment(
                  value: DmAdvantageState.advantage,
                  label: Text('优势'),
                ),
              ],
              selected: {advantage},
              onSelectionChanged: (value) =>
                  setDialogState(() => advantage = value.first),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                _roll(
                  sides: sides,
                  count: count,
                  bonus: bonus,
                  advantage: advantage,
                );
                setDialogState(() {});
              },
              icon: const Icon(Icons.casino_outlined),
              label: const Text('掷骰'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '本页会话日志',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _logs.isEmpty
                      ? null
                      : () {
                          setState(_logs.clear);
                          setDialogState(() {});
                        },
                  child: const Text('清空'),
                ),
              ],
            ),
            if (_logs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  '还没有掷骰结果。结果不会修改 NPC 或遭遇状态。',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._logs.map(
                (log) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${log.result}')),
                  title: Text('${log.title}\n${log.detail}'),
                ),
              ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (MediaQuery.sizeOf(context).width >= 900) {
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('通用掷骰'),
            content: content(context, setDialogState),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: content(context, setDialogState),
            ),
          ),
        ),
      );
    }
  }

  Widget _toolbar() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: widget.onAddNpc,
          icon: const Icon(Icons.person_add_alt),
          label: const Text('添加 NPC'),
        ),
        OutlinedButton.icon(
          onPressed: _createOrEditGroup,
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('创建集群'),
        ),
        if (!_encounter.isEmpty)
          PopupMenuButton<String>(
            tooltip: '更多操作',
            onSelected: (value) {
              if (value == 'end') _endEncounter();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'end', child: Text('结束遭遇')),
            ],
            child: const SizedBox.square(
              dimension: 48,
              child: Icon(Icons.more_horiz),
            ),
          ),
      ],
    ),
  );

  Widget _hpControls(NpcInstance instance) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _HpControl(
        label: 'HP',
        value: instance.currentHitPoints,
        maxText: '${instance.maximumHitPoints}',
        canDecrease: instance.currentHitPoints > 0,
        canIncrease: instance.currentHitPoints < instance.maximumHitPoints,
        onDecrease: () {
          instance.setCurrentHitPoints(instance.currentHitPoints - 1);
          _commit();
        },
        onIncrease: () {
          instance.setCurrentHitPoints(instance.currentHitPoints + 1);
          _commit();
        },
        onEdit: () => _editHitPoints(instance, temporary: false),
      ),
      if (instance.temporaryHitPoints > 0) ...[
        const SizedBox(height: 6),
        _HpControl(
          label: '临时',
          value: instance.temporaryHitPoints,
          canDecrease: true,
          canIncrease: true,
          onDecrease: () {
            instance.setTemporaryHitPoints(instance.temporaryHitPoints - 1);
            _commit();
          },
          onIncrease: () {
            instance.setTemporaryHitPoints(instance.temporaryHitPoints + 1);
            _commit();
          },
          onEdit: () => _editHitPoints(instance, temporary: true),
        ),
      ],
    ],
  );

  Widget _instanceMenu(NpcInstance instance, {_EncounterUnit? unit}) {
    final tied = unit == null
        ? const <_EncounterUnit>[]
        : _units.where((item) => item.initiative == unit.initiative).toList();
    final tieIndex = unit == null
        ? -1
        : tied.indexWhere((item) => item.id == unit.id);
    return PopupMenuButton<String>(
      tooltip: '实例操作',
      onSelected: (value) {
        switch (value) {
          case 'tie_up':
            _moveTie(unit!, -1);
          case 'tie_down':
            _moveTie(unit!, 1);
          case 'move':
            _moveInstance(instance);
          case 'copy':
            _duplicateInstance(instance);
          case 'temporary_hp':
            _editHitPoints(instance, temporary: true);
          case 'remove':
            _removeInstance(instance);
        }
      },
      itemBuilder: (context) => [
        if (tieIndex > 0)
          const PopupMenuItem(value: 'tie_up', child: Text('同先攻上移')),
        if (tieIndex >= 0 && tieIndex < tied.length - 1)
          const PopupMenuItem(value: 'tie_down', child: Text('同先攻下移')),
        const PopupMenuItem(value: 'move', child: Text('移动到集群/独立')),
        const PopupMenuItem(value: 'copy', child: Text('复制实例')),
        PopupMenuItem(
          value: 'temporary_hp',
          child: Text(instance.temporaryHitPoints > 0 ? '编辑临时 HP' : '设置临时 HP'),
        ),
        const PopupMenuItem(value: 'remove', child: Text('移出遭遇')),
      ],
    );
  }

  Future<void> _openDetails(NpcInstance instance) async {
    _selectedInstanceId = instance.id;
    if (MediaQuery.sizeOf(context).width >= kAppWideBreakpoint) {
      setState(() {});
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(_displayName(instance))),
          body: NpcInstanceDetails(
            instance: instance,
            groups: _encounter.groups,
            onChanged: _commit,
            onMove: () => _moveInstance(instance),
            onDuplicate: () => _duplicateInstance(instance),
            onRemove: () async {
              await _removeInstance(instance);
              if (context.mounted && !_encounter.instances.contains(instance)) {
                Navigator.pop(context);
              }
            },
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _independentCard(_EncounterUnit unit) {
    final instance = unit.instance!;
    return AppPanel(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _editInitiative(instance),
                child: SizedBox(
                  width: 54,
                  height: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('先攻', style: TextStyle(fontSize: 11)),
                      Text(
                        instance.initiative?.toString() ?? '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openDetails(instance),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName(instance),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'AC ${instance.cardSnapshot.armorClass} · ${instance.cardSnapshot.sizeAndType.trim().isEmpty ? '未填写类型' : instance.cardSnapshot.sizeAndType}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _instanceMenu(instance, unit: unit),
            ],
          ),
          const SizedBox(height: 8),
          _hpControls(instance),
        ],
      ),
    );
  }

  Widget _groupCard(_EncounterUnit unit) {
    final group = unit.group!;
    final members = _encounter.membersOf(group.id)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return AppPanel(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _editGroupInitiative(group),
          child: SizedBox(
            width: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('先攻', style: TextStyle(fontSize: 11)),
                Text(
                  group.initiative?.toString() ?? '—',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        title: Text(
          '${group.name.trim().isEmpty ? '未命名集群' : group.name} · ${members.length} 名',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              tooltip: '集群操作',
              onSelected: (value) {
                if (value == 'tie_up') {
                  _moveTie(unit, -1);
                } else if (value == 'tie_down') {
                  _moveTie(unit, 1);
                } else if (value == 'edit') {
                  _createOrEditGroup(group);
                } else if (value == 'initiative') {
                  _editGroupInitiative(group);
                } else if (value == 'add_npc') {
                  widget.onAddNpc(group);
                } else {
                  _deleteGroup(group);
                }
              },
              itemBuilder: (context) {
                final tied = _units
                    .where((item) => item.initiative == unit.initiative)
                    .toList();
                final tieIndex = tied.indexWhere((item) => item.id == unit.id);
                return [
                  const PopupMenuItem(value: 'add_npc', child: Text('添加 NPC')),
                  if (tieIndex > 0)
                    const PopupMenuItem(value: 'tie_up', child: Text('同先攻上移')),
                  if (tieIndex >= 0 && tieIndex < tied.length - 1)
                    const PopupMenuItem(
                      value: 'tie_down',
                      child: Text('同先攻下移'),
                    ),
                  const PopupMenuItem(value: 'edit', child: Text('编辑集群')),
                  const PopupMenuItem(value: 'initiative', child: Text('设置先攻')),
                  const PopupMenuItem(value: 'delete', child: Text('删除集群')),
                ];
              },
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: members.isEmpty
            ? [const ListTile(title: Text('集群为空'))]
            : members
                  .map(
                    (instance) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Material(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        '${_displayName(instance)} · AC ${instance.cardSnapshot.armorClass}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      onTap: () => _openDetails(instance),
                                    ),
                                  ),
                                  _instanceMenu(instance),
                                ],
                              ),
                              _hpControls(instance),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
      ),
    );
  }

  Widget _unitList() {
    final units = _units;
    if (units.isEmpty) {
      return AppEmptyState(
        icon: Icons.sports_martial_arts,
        title: '当前遭遇为空',
        message: '从 NPC 库添加实例，或先创建一个可暂时为空的集群。',
        action: FilledButton.icon(
          onPressed: widget.onAddNpc,
          icon: const Icon(Icons.person_add_alt),
          label: const Text('添加 NPC'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: units.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) => units[index].group != null
          ? _groupCard(units[index])
          : _independentCard(units[index]),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final list = Column(
        children: [
          _toolbar(),
          Expanded(child: _unitList()),
        ],
      );
      final selected = _selectedInstance;
      final content = constraints.maxWidth < kAppWideBreakpoint
          ? list
          : Row(
              children: [
                Expanded(flex: 2, child: list),
                VerticalDivider(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(
                  child: selected == null
                      ? const AppEmptyState(
                          icon: Icons.touch_app_outlined,
                          title: '选择一个 NPC',
                          message: '在左侧选择实例，可查看完整卡片资料和编辑运行时状态。',
                        )
                      : NpcInstanceDetails(
                          key: ValueKey(selected.id),
                          instance: selected,
                          groups: _encounter.groups,
                          onChanged: _commit,
                          onMove: () => _moveInstance(selected),
                          onDuplicate: () => _duplicateInstance(selected),
                          onRemove: () => _removeInstance(selected),
                        ),
                ),
              ],
            );
      final cs = Theme.of(context).colorScheme;
      return Column(
        children: [
          Expanded(child: content),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              child: FilledButton.icon(
                onPressed: _showDice,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('掷骰'),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class NpcInstanceDetails extends StatelessWidget {
  final NpcInstance instance;
  final List<EncounterGroup> groups;
  final Future<void> Function() onChanged;
  final Future<void> Function() onMove;
  final Future<void> Function() onDuplicate;
  final Future<void> Function() onRemove;

  const NpcInstanceDetails({
    super.key,
    required this.instance,
    required this.groups,
    required this.onChanged,
    required this.onMove,
    required this.onDuplicate,
    required this.onRemove,
  });

  Widget _textBlock(BuildContext context, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          SelectableText(value, style: const TextStyle(height: 1.45)),
        ],
      ),
    );
  }

  Widget _entries(
    BuildContext context,
    String title,
    List<NpcFeatureEntry> entries,
  ) {
    final visible = entries
        .where(
          (entry) =>
              entry.name.trim().isNotEmpty ||
              entry.description.trim().isNotEmpty,
        )
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionTitle(title: title),
        ...visible.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppPanel(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.name.trim().isNotEmpty)
                    Text(
                      entry.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  if (entry.name.trim().isNotEmpty &&
                      entry.description.trim().isNotEmpty)
                    const SizedBox(height: 4),
                  if (entry.description.trim().isNotEmpty)
                    SelectableText(
                      entry.description,
                      style: const TextStyle(height: 1.45),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = instance.cardSnapshot;
    final ability = card.abilities;
    final abilitySummary = [
      '力量 ${ability.strength} (${ability.strengthModifier >= 0 ? '+' : ''}${ability.strengthModifier})',
      '敏捷 ${ability.dexterity} (${ability.dexterityModifier >= 0 ? '+' : ''}${ability.dexterityModifier})',
      '体质 ${ability.constitution} (${ability.constitutionModifier >= 0 ? '+' : ''}${ability.constitutionModifier})',
      '智力 ${ability.intelligence} (${ability.intelligenceModifier >= 0 ? '+' : ''}${ability.intelligenceModifier})',
      '感知 ${ability.wisdom} (${ability.wisdomModifier >= 0 ? '+' : ''}${ability.wisdomModifier})',
      '魅力 ${ability.charisma} (${ability.charismaModifier >= 0 ? '+' : ''}${ability.charismaModifier})',
    ].join('\n');
    final contents = ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      children: [
        TextFormField(
          initialValue: instance.displayName,
          decoration: const InputDecoration(labelText: '实例显示名称'),
          onChanged: (value) {
            instance.displayName = value;
            onChanged();
          },
          onFieldSubmitted: (_) => onChanged(),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: instance.notes,
          decoration: const InputDecoration(labelText: '实例备注'),
          minLines: 1,
          maxLines: 8,
          onChanged: (value) {
            instance.notes = value;
            onChanged();
          },
          onFieldSubmitted: (_) => onChanged(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onMove,
              icon: const Icon(Icons.drive_file_move_outline),
              label: const Text('移动'),
            ),
            OutlinedButton.icon(
              onPressed: onDuplicate,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('复制'),
            ),
            TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('移出'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppStatPill(label: 'AC', value: '${card.armorClass}'),
                  AppStatPill(
                    label: '最大 HP',
                    value: '${card.maximumHitPoints}',
                  ),
                  if (card.challengeRating.trim().isNotEmpty)
                    AppStatPill(label: 'CR', value: card.challengeRating),
                ],
              ),
              const SizedBox(height: 14),
              _textBlock(context, '体型与生物类型', card.sizeAndType),
              _textBlock(context, '速度', card.speed),
              _textBlock(context, '属性', abilitySummary),
              _textBlock(context, '豁免', card.saves),
              _textBlock(context, '技能', card.skills),
              _textBlock(context, '伤害易伤', card.damageVulnerabilities),
              _textBlock(context, '伤害抗性', card.damageResistances),
              _textBlock(context, '伤害免疫', card.damageImmunities),
              _textBlock(context, '状态免疫', card.conditionImmunities),
              _textBlock(context, '感官', card.senses),
              _textBlock(context, '语言', card.languages),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _entries(context, '特性', card.traits),
        _entries(context, '动作', card.actions),
        _entries(context, '附赠动作', card.bonusActions),
        _entries(context, '反应', card.reactions),
        _entries(context, '传奇动作', card.legendaryActions),
        if (card.notes.trim().isNotEmpty) ...[
          const AppSectionTitle(title: '模板备注'),
          AppPanel(
            child: SelectableText(
              card.notes,
              style: const TextStyle(height: 1.45),
            ),
          ),
        ],
      ],
    );
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) onChanged();
      },
      child: contents,
    );
  }
}

class _HpControl extends StatelessWidget {
  final String label;
  final int value;
  final String? maxText;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onEdit;

  const _HpControl({
    required this.label,
    required this.value,
    this.maxText,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 42,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      SizedBox.square(
        dimension: 48,
        child: IconButton.filledTonal(
          tooltip: '$label 减 1',
          onPressed: canDecrease ? onDecrease : null,
          icon: const Icon(Icons.remove),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: onEdit,
            child: Text(
              maxText == null ? '$value' : '$value / $maxText',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox.square(
        dimension: 48,
        child: IconButton.filledTonal(
          tooltip: '$label 加 1',
          onPressed: canIncrease ? onIncrease : null,
          icon: const Icon(Icons.add),
        ),
      ),
    ],
  );
}

class _EncounterUnit {
  final NpcInstance? instance;
  final EncounterGroup? group;

  const _EncounterUnit._({this.instance, this.group});
  factory _EncounterUnit.instance(NpcInstance instance) =>
      _EncounterUnit._(instance: instance);
  factory _EncounterUnit.group(EncounterGroup group) =>
      _EncounterUnit._(group: group);

  String get id => instance?.id ?? group!.id;
  int? get initiative => instance?.initiative ?? group?.initiative;
  int get sortOrder => instance?.sortOrder ?? group!.sortOrder;
  set sortOrder(int value) {
    if (instance != null) {
      instance!.sortOrder = value;
    } else {
      group!.sortOrder = value;
    }
  }
}

class _DmRollLog {
  final String title;
  final int result;
  final String detail;

  const _DmRollLog({
    required this.title,
    required this.result,
    required this.detail,
  });
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
