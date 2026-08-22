import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/dm_models.dart';
import '../../widgets/app_ui.dart';

class EncounterPresetEditPage extends StatefulWidget {
  final EncounterPreset preset;
  final List<NpcCard> cards;

  const EncounterPresetEditPage({
    super.key,
    required this.preset,
    required this.cards,
  });

  @override
  State<EncounterPresetEditPage> createState() =>
      _EncounterPresetEditPageState();
}

class _EncounterPresetEditPageState extends State<EncounterPresetEditPage> {
  static const _independent = '__independent__';
  late EncounterPreset _preset;
  late String _initialJson;
  late final TextEditingController _nameController;
  bool _forceExit = false;

  @override
  void initState() {
    super.initState();
    _preset = widget.preset.deepCopy()..normalize();
    _initialJson = jsonEncode(_preset.toJson());
    _nameController = TextEditingController(text: _preset.name)
      ..addListener(() => _preset.name = _nameController.text);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _hasChanges => _initialJson != jsonEncode(_preset.toJson());

  List<_PresetUnit> get _topLevelUnits {
    final units = <_PresetUnit>[
      ..._preset.groups.map(_PresetUnit.group),
      ..._preset.entries
          .where((entry) => entry.groupId == null)
          .map(_PresetUnit.entry),
    ];
    units.sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    return units;
  }

  List<EncounterPresetEntry> _membersOf(EncounterPresetGroup group) {
    final members = _preset.entries
        .where((entry) => entry.groupId == group.id)
        .toList();
    members.sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    return members;
  }

  int get _nextTopLevelOrder {
    final units = _topLevelUnits;
    return units.isEmpty ? 0 : units.last.sortOrder + 1;
  }

  int _nextMemberOrder(EncounterPresetGroup group) {
    final members = _membersOf(group);
    return members.isEmpty ? 0 : members.last.sortOrder + 1;
  }

  void _finish([EncounterPreset? result]) {
    setState(() => _forceExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  Future<String?> _showExitDialog() => showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('未保存的更改'),
      content: const Text('遭遇预设还有未保存的修改。直接退出将丢失本次编辑内容。'),
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

  Future<void> _save() async {
    _preset
      ..name = _nameController.text.trim()
      ..normalize();
    if (_preset.name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写预设名称')));
      return;
    }
    if (_preset.entries.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少添加一种 NPC')));
      return;
    }
    _finish(_preset);
  }

  Future<String?> _promptGroupName(String title, String initialValue) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '集群名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _addGroup() async {
    final name = await _promptGroupName('创建集群', '');
    if (name == null || name.isEmpty) return;
    setState(() {
      _preset.groups.add(
        EncounterPresetGroup(name: name, sortOrder: _nextTopLevelOrder),
      );
      _preset.normalize();
    });
  }

  Future<void> _renameGroup(EncounterPresetGroup group) async {
    final name = await _promptGroupName('重命名集群', group.name);
    if (name == null || name.isEmpty) return;
    setState(() => group.name = name);
  }

  Future<void> _deleteGroup(EncounterPresetGroup group) async {
    final members = _membersOf(group);
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除集群'),
        content: Text(
          members.isEmpty
              ? '确定要删除「${_groupName(group)}」吗？'
              : '「${_groupName(group)}」中有 ${members.fold(0, (sum, entry) => sum + entry.count)} 名 NPC。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          if (members.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, 'keep'),
              child: const Text('成员转为独立 NPC'),
            ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, 'remove'),
            child: Text(members.isEmpty ? '删除' : '连同成员删除'),
          ),
        ],
      ),
    );
    if (action == null) return;
    setState(() {
      final units = _topLevelUnits;
      final groupIndex = units.indexWhere((unit) => unit.group?.id == group.id);
      _preset.groups.removeWhere((item) => item.id == group.id);
      if (action == 'remove') {
        _preset.entries.removeWhere((entry) => entry.groupId == group.id);
      } else {
        for (final entry in members) {
          entry.groupId = null;
        }
        final remaining = units
            .where((unit) => unit.group?.id != group.id)
            .toList();
        remaining.insertAll(
          groupIndex.clamp(0, remaining.length).toInt(),
          members.map(_PresetUnit.entry),
        );
        for (var index = 0; index < remaining.length; index++) {
          remaining[index].sortOrder = index;
        }
      }
      _preset.normalize();
    });
  }

  List<String> _automaticNames(NpcCard card, int count) {
    final base = card.name.trim().isEmpty ? '未命名 NPC' : card.name.trim();
    if (count == 1) return [base];
    return List.generate(count, (index) => '$base ${index + 1}');
  }

  Future<void> _addNpc([EncounterPresetGroup? targetGroup]) async {
    if (widget.cards.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('NPC 库中没有可用卡片')));
      return;
    }
    var selectedCard = widget.cards.first;
    var count = 1;
    var controllers = _automaticNames(
      selectedCard,
      count,
    ).map((name) => TextEditingController(text: name)).toList();
    final retiredControllers = <TextEditingController>[];

    void replaceNames(NpcCard card, int nextCount) {
      final generated = _automaticNames(card, nextCount);
      for (var index = 0; index < generated.length; index++) {
        if (index < controllers.length) {
          controllers[index].text = generated[index];
        } else {
          controllers.add(TextEditingController(text: generated[index]));
        }
      }
      if (controllers.length > generated.length) {
        retiredControllers.addAll(controllers.sublist(generated.length));
        controllers = controllers.sublist(0, generated.length);
      }
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            targetGroup == null
                ? '添加 NPC 到预设'
                : '添加 NPC 到「${_groupName(targetGroup)}」',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCard.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'NPC 卡'),
                    items: widget.cards
                        .map(
                          (card) => DropdownMenuItem(
                            value: card.id,
                            child: Text(
                              card.name.trim().isEmpty ? '未命名 NPC' : card.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) => setDialogState(() {
                      selectedCard = widget.cards.firstWhere(
                        (card) => card.id == id,
                      );
                      replaceNames(selectedCard, count);
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: count,
                    decoration: const InputDecoration(labelText: '实例数量'),
                    items: List.generate(
                      20,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                    onChanged: (value) => setDialogState(() {
                      count = value ?? 1;
                      replaceNames(selectedCard, count);
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '实例名称',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(
                    controllers.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: controllers[index],
                        decoration: InputDecoration(
                          labelText: '实例 ${index + 1}',
                        ),
                      ),
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
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.playlist_add),
              label: const Text('添加'),
            ),
          ],
        ),
      ),
    );

    if (accepted == true) {
      setState(() {
        final entry = EncounterPresetEntry.fromCard(
          selectedCard,
          count: count,
          groupId: targetGroup?.id,
          sortOrder: targetGroup == null
              ? _nextTopLevelOrder
              : _nextMemberOrder(targetGroup),
        )..instanceNames = controllers.map((item) => item.text).toList();
        entry.synchronizeNames();
        _preset.entries.add(entry);
        _preset.normalize();
      });
    }
    for (final controller in controllers) {
      controller.dispose();
    }
    for (final controller in retiredControllers) {
      controller.dispose();
    }
  }

  void _removeEntry(EncounterPresetEntry entry) {
    setState(() {
      _preset.entries.removeWhere((item) => item.id == entry.id);
      _preset.normalize();
    });
  }

  void _moveTopLevel(_PresetUnit unit, int offset) {
    final units = _topLevelUnits;
    final index = units.indexWhere((item) => item.id == unit.id);
    final target = index + offset;
    if (index < 0 || target < 0 || target >= units.length) return;
    setState(() {
      final other = units[target];
      final order = unit.sortOrder;
      unit.sortOrder = other.sortOrder;
      other.sortOrder = order;
      _preset.normalize();
    });
  }

  void _moveEntryWithinGroup(
    EncounterPresetGroup group,
    EncounterPresetEntry entry,
    int offset,
  ) {
    final members = _membersOf(group);
    final index = members.indexWhere((item) => item.id == entry.id);
    final target = index + offset;
    if (index < 0 || target < 0 || target >= members.length) return;
    setState(() {
      final other = members[target];
      final order = entry.sortOrder;
      entry.sortOrder = other.sortOrder;
      other.sortOrder = order;
      _preset.normalize();
    });
  }

  Future<void> _moveEntry(EncounterPresetEntry entry) async {
    final destination = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('移动 NPC'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _independent),
            child: const ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('转为独立 NPC'),
            ),
          ),
          ..._preset.groups.map(
            (group) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, group.id),
              child: ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(_groupName(group)),
              ),
            ),
          ),
        ],
      ),
    );
    if (destination == null) return;
    final nextGroupId = destination == _independent ? null : destination;
    if (nextGroupId == entry.groupId) return;
    setState(() {
      if (nextGroupId == null) {
        final nextOrder = _nextTopLevelOrder;
        entry
          ..groupId = null
          ..sortOrder = nextOrder;
      } else {
        final group = _preset.groups.firstWhere(
          (item) => item.id == nextGroupId,
        );
        final nextOrder = _nextMemberOrder(group);
        entry
          ..groupId = nextGroupId
          ..sortOrder = nextOrder;
      }
      _preset.normalize();
    });
  }

  String _groupName(EncounterPresetGroup group) =>
      group.name.trim().isEmpty ? '未命名集群' : group.name.trim();

  String _cardChoice(EncounterPresetEntry entry) {
    final sourceId = entry.sourceCardId;
    if (sourceId != null && widget.cards.any((card) => card.id == sourceId)) {
      return sourceId;
    }
    return '__snapshot__:${entry.id}';
  }

  Widget _entryMenu(
    EncounterPresetEntry entry, {
    required int index,
    required int length,
    EncounterPresetGroup? group,
  }) => PopupMenuButton<String>(
    tooltip: 'NPC 操作',
    onSelected: (value) {
      if (value == 'up') {
        if (group == null) {
          _moveTopLevel(_PresetUnit.entry(entry), -1);
        } else {
          _moveEntryWithinGroup(group, entry, -1);
        }
      } else if (value == 'down') {
        if (group == null) {
          _moveTopLevel(_PresetUnit.entry(entry), 1);
        } else {
          _moveEntryWithinGroup(group, entry, 1);
        }
      } else if (value == 'move') {
        _moveEntry(entry);
      } else if (value == 'delete') {
        _removeEntry(entry);
      }
    },
    itemBuilder: (context) => [
      if (index > 0) const PopupMenuItem(value: 'up', child: Text('上移')),
      if (index < length - 1)
        const PopupMenuItem(value: 'down', child: Text('下移')),
      const PopupMenuItem(value: 'move', child: Text('移动到集群/独立')),
      const PopupMenuItem(value: 'delete', child: Text('移除')),
    ],
  );

  Widget _entryCard(
    EncounterPresetEntry entry, {
    required int index,
    required int length,
    EncounterPresetGroup? group,
  }) {
    final cardChoice = _cardChoice(entry);
    final countChoices = <int>{
      ...List.generate(20, (item) => item + 1),
      entry.count,
    }.toList()..sort();
    return AppPanel(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        key: ValueKey('preset-entry-${entry.id}'),
        leading: const Icon(Icons.person_outline),
        title: Text(
          '${entry.displayCardName} · ${entry.count} 名',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        trailing: _entryMenu(entry, index: index, length: length, group: group),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final fieldWidth = constraints.maxWidth >= 560
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('card-${entry.id}-$cardChoice'),
                      initialValue: cardChoice,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'NPC 卡'),
                      items: [
                        if (cardChoice.startsWith('__snapshot__:'))
                          DropdownMenuItem(
                            value: cardChoice,
                            child: Text(
                              '${entry.displayCardName}（预设快照）',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ...widget.cards.map(
                          (card) => DropdownMenuItem(
                            value: card.id,
                            child: Text(
                              card.name.trim().isEmpty ? '未命名 NPC' : card.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        final card = widget.cards
                            .where((item) => item.id == value)
                            .firstOrNull;
                        if (card == null) return;
                        setState(() {
                          entry
                            ..sourceCardId = card.id
                            ..cardSnapshot = card.deepCopy()
                            ..instanceNames = [];
                          entry.synchronizeNames();
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('count-${entry.id}-${entry.count}'),
                      initialValue: entry.count,
                      decoration: const InputDecoration(labelText: '数量'),
                      items: countChoices
                          .map(
                            (count) => DropdownMenuItem(
                              value: count,
                              child: Text('$count'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          entry.count = value;
                          entry.synchronizeNames();
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '实例名称',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            entry.count,
            (nameIndex) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextFormField(
                key: ValueKey('name-${entry.id}-$nameIndex-${entry.count}'),
                initialValue: entry.instanceNames[nameIndex],
                decoration: InputDecoration(labelText: '实例 ${nameIndex + 1}'),
                onChanged: (value) => entry.instanceNames[nameIndex] = value,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupMenu(
    EncounterPresetGroup group, {
    required int index,
    required int length,
  }) => PopupMenuButton<String>(
    tooltip: '集群操作',
    onSelected: (value) {
      if (value == 'add') {
        _addNpc(group);
      } else if (value == 'up') {
        _moveTopLevel(_PresetUnit.group(group), -1);
      } else if (value == 'down') {
        _moveTopLevel(_PresetUnit.group(group), 1);
      } else if (value == 'rename') {
        _renameGroup(group);
      } else if (value == 'delete') {
        _deleteGroup(group);
      }
    },
    itemBuilder: (context) => [
      const PopupMenuItem(value: 'add', child: Text('添加 NPC')),
      if (index > 0) const PopupMenuItem(value: 'up', child: Text('上移')),
      if (index < length - 1)
        const PopupMenuItem(value: 'down', child: Text('下移')),
      const PopupMenuItem(value: 'rename', child: Text('重命名')),
      const PopupMenuItem(value: 'delete', child: Text('删除集群')),
    ],
  );

  Widget _groupCard(
    EncounterPresetGroup group, {
    required int index,
    required int length,
  }) {
    final members = _membersOf(group);
    final instanceCount = members.fold(0, (sum, entry) => sum + entry.count);
    return AppPanel(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        key: ValueKey('preset-group-${group.id}'),
        initiallyExpanded: true,
        leading: const Icon(Icons.groups_outlined),
        title: Text(
          '${_groupName(group)} · $instanceCount 名',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        trailing: _groupMenu(group, index: index, length: length),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        children: members.isEmpty
            ? [
                Row(
                  children: [
                    const Expanded(child: Text('集群为空')),
                    TextButton.icon(
                      onPressed: () => _addNpc(group),
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('添加 NPC'),
                    ),
                  ],
                ),
              ]
            : List.generate(
                members.length,
                (memberIndex) => Padding(
                  padding: EdgeInsets.only(top: memberIndex == 0 ? 0 : 8),
                  child: _entryCard(
                    members[memberIndex],
                    index: memberIndex,
                    length: members.length,
                    group: group,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _lineup() {
    final units = _topLevelUnits;
    if (units.isEmpty) {
      return AppPanel(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              const Icon(Icons.person_search_outlined, size: 36),
              const SizedBox(height: 8),
              const Text('还没有 NPC 或集群'),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _addNpc,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('添加 NPC'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: List.generate(
        units.length,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == units.length - 1 ? 0 : 8),
          child: units[index].group != null
              ? _groupCard(
                  units[index].group!,
                  index: index,
                  length: units.length,
                )
              : _entryCard(
                  units[index].entry!,
                  index: index,
                  length: units.length,
                ),
        ),
      ),
    );
  }

  Widget _body() => ListView(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSectionTitle(
                title: '预设信息',
                icon: Icons.bookmarks_outlined,
              ),
              AppPanel(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '预设名称'),
                ),
              ),
              const SizedBox(height: 12),
              const AppSectionTitle(
                title: 'NPC 与集群编排',
                icon: Icons.format_list_numbered,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _addNpc,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('添加 NPC'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _addGroup,
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('创建集群'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _lineup(),
            ],
          ),
        ),
      ),
    ],
  );

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
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          _preset.name.trim().isEmpty ? '新建遭遇预设' : _preset.name.trim(),
        ),
        actions: MediaQuery.sizeOf(context).width >= kAppDesktopBreakpoint
            ? [
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存并退出'),
                ),
                const SizedBox(width: 16),
              ]
            : null,
      ),
      body: _body(),
      bottomNavigationBar:
          MediaQuery.sizeOf(context).width < kAppDesktopBreakpoint
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存并退出'),
                ),
              ),
            )
          : null,
    ),
  );
}

class _PresetUnit {
  final EncounterPresetGroup? group;
  final EncounterPresetEntry? entry;

  _PresetUnit.group(EncounterPresetGroup value) : group = value, entry = null;

  _PresetUnit.entry(EncounterPresetEntry value) : group = null, entry = value;

  String get id => group?.id ?? entry!.id;

  int get sortOrder => group?.sortOrder ?? entry!.sortOrder;

  set sortOrder(int value) {
    if (group != null) {
      group!.sortOrder = value;
    } else {
      entry!.sortOrder = value;
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
