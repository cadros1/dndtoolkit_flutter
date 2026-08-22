import 'package:flutter/material.dart';

import '../../models/dm_models.dart';
import '../../services/dm_storage.dart';
import '../../services/npc_markdown_service.dart';
import '../../widgets/app_ui.dart';
import 'current_encounter_view.dart';
import 'encounter_preset_edit_page.dart';
import 'encounter_preset_view.dart';
import 'npc_card_edit_page.dart';
import 'npc_library_view.dart';
import 'npc_markdown_import_page.dart';

class DmPage extends StatefulWidget {
  final DmStorage? storage;
  final NpcMarkdownService? markdownService;

  const DmPage({super.key, this.storage, this.markdownService});

  @override
  State<DmPage> createState() => _DmPageState();
}

class _DmPageState extends State<DmPage> with WidgetsBindingObserver {
  late final DmStorage _storage;
  late final NpcMarkdownService _markdownService;
  DmData? _data;
  Object? _loadError;
  bool _loading = true;
  int _section = 0;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? DmStorage();
    _markdownService = widget.markdownService ?? NpcMarkdownService();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _save();
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final data = await _storage.load();
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final data = _data;
    if (data == null) return;
    try {
      await _storage.save(data);
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('DM 数据保存失败：$error。请检查存储空间后重试。')));
    }
  }

  Future<void> _editCard(NpcCard? source) async {
    final data = _data!;
    final result = await Navigator.push<NpcCard>(
      context,
      MaterialPageRoute(
        builder: (context) => NpcCardEditPage(
          card: source?.deepCopy() ?? NpcCard(),
          categories: data.sortedCategories,
        ),
      ),
    );
    if (result == null) return;
    final index = data.cards.indexWhere((card) => card.id == result.id);
    if (index < 0) {
      data.cards.add(result);
    } else {
      data.cards[index] = result;
    }
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('NPC 卡已保存')));
    }
  }

  Future<void> _duplicateCard(NpcCard card) async {
    final base = card.name.trim().isEmpty ? '未命名 NPC' : card.name.trim();
    final duplicate = card.deepCopy(newIdentity: true, name: '$base（副本）');
    _data!.cards.add(duplicate);
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已复制「$base」')));
    }
  }

  Future<void> _editPreset(EncounterPreset? source) async {
    final data = _data!;
    if (source == null && data.cards.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在 NPC 库创建 NPC 卡')));
      setState(() => _section = 0);
      return;
    }
    final result = await Navigator.push<EncounterPreset>(
      context,
      MaterialPageRoute(
        builder: (context) => EncounterPresetEditPage(
          preset: source?.deepCopy() ?? EncounterPreset(),
          cards: List.of(data.cards),
        ),
      ),
    );
    if (result == null) return;
    final index = data.presets.indexWhere((preset) => preset.id == result.id);
    if (index < 0) {
      data.presets.add(result);
    } else {
      data.presets[index] = result;
    }
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('遭遇预设已保存')));
  }

  Future<void> _duplicatePreset(EncounterPreset preset) async {
    final base = preset.name.trim().isEmpty ? '未命名预设' : preset.name.trim();
    _data!.presets.add(preset.deepCopy(newIdentity: true, name: '$base（副本）'));
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已复制「$base」')));
  }

  Future<void> _deletePreset(EncounterPreset preset) async {
    final name = preset.name.trim().isEmpty ? '未命名预设' : preset.name.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除遭遇预设'),
        content: Text('确定要删除「$name」吗？当前遭遇不会受到影响。'),
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
    _data!.presets.removeWhere((item) => item.id == preset.id);
    await _save();
  }

  Future<void> _startPreset(EncounterPreset preset) async {
    final data = _data!;
    if (!data.encounter.isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('替换当前遭遇'),
          content: const Text('当前遭遇中的实例、集群和运行时状态将被清空，并由该预设创建新的遭遇。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('替换并创建'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    data.encounter = preset.createEncounter();
    await _save();
    if (!mounted) return;
    setState(() => _section = 2);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已从「${preset.name.trim().isEmpty ? '未命名预设' : preset.name}」创建当前遭遇',
        ),
      ),
    );
  }

  Future<void> _extractCurrentEncounter() async {
    final data = _data!;
    if (data.encounter.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前遭遇为空，无法创建预设')));
      return;
    }
    await _editPreset(EncounterPreset.fromEncounter(data.encounter));
  }

  Future<void> _exportCard(NpcCard card) async {
    final data = _data!;
    final categoryName = data.categories
        .where((category) => category.id == card.categoryId)
        .map((category) => category.name)
        .firstOrNull;
    try {
      final result = await _markdownService.exportCard(
        card,
        categoryName: categoryName ?? defaultNpcCategoryName,
      );
      if (!mounted ||
          result.disposition == NpcMarkdownExportDisposition.cancelled) {
        return;
      }
      final action = result.disposition == NpcMarkdownExportDisposition.saved
          ? '已导出'
          : '已打开分享面板';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$action ${result.fileName}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('NPC 卡导出失败：$error')));
    }
  }

  Future<void> _exportBlankTemplate() async {
    try {
      final result = await _markdownService.exportBlankTemplate();
      if (!mounted ||
          result.disposition == NpcMarkdownExportDisposition.cancelled) {
        return;
      }
      final action = result.disposition == NpcMarkdownExportDisposition.saved
          ? '已导出'
          : '已打开分享面板';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$action ${result.fileName}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('空白模板导出失败：$error')));
    }
  }

  Future<void> _importCards() async {
    List<NpcMarkdownImportResult>? results;
    try {
      results = await _markdownService.pickImportFiles();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Markdown 文件读取失败：$error')));
      return;
    }
    if (!mounted || results == null) return;
    if (results.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有选择 Markdown 文件')));
      return;
    }

    final selections = await Navigator.push<List<NpcMarkdownImportSelection>>(
      context,
      MaterialPageRoute(
        builder: (context) => NpcMarkdownImportPage(
          results: results!,
          categories: List.of(_data!.sortedCategories),
        ),
      ),
    );
    if (!mounted || selections == null || selections.isEmpty) return;

    final data = _data!;
    for (final selection in selections) {
      var categoryId = selection.categoryId ?? defaultNpcCategoryId;
      final categoryName = selection.categoryNameToCreate?.trim() ?? '';
      if (categoryName.isNotEmpty) {
        final existing = data.categories
            .where(
              (category) =>
                  category.name.trim().toLowerCase() ==
                  categoryName.toLowerCase(),
            )
            .firstOrNull;
        if (existing != null) {
          categoryId = existing.id;
        } else {
          final category = NpcCategory(
            name: categoryName,
            sortOrder: data.categories.length,
          );
          data.categories.add(category);
          categoryId = category.id;
        }
      }
      final card = selection.result.card!.deepCopy(newIdentity: true)
        ..categoryId = categoryId;
      data.cards.add(card);
    }
    data.ensureDefaultCategory();
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已导入 ${selections.length} 张 NPC 卡')));
  }

  Future<void> _deleteCard(NpcCard card) async {
    final name = card.name.trim().isEmpty ? '未命名 NPC' : card.name.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除 NPC 卡'),
        content: Text('确定要删除「$name」吗？当前遭遇实例和遭遇预设都会保留各自的卡片快照。'),
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
    _data!.cards.removeWhere((item) => item.id == card.id);
    await _save();
  }

  Future<void> _moveCardCategory(NpcCard card) async {
    final selected = await showDialog<String?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('移动分类'),
        children: [
          ..._data!.sortedCategories.map(
            (category) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, category.id),
              child: ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(category.name),
              ),
            ),
          ),
        ],
      ),
    );
    if (selected == null) return;
    card.categoryId = selected;
    await _save();
  }

  List<String> _automaticNames(NpcCard card, int count) {
    final base = card.name.trim().isEmpty ? '未命名 NPC' : card.name.trim();
    if (count == 1) return [base];
    return List.generate(count, (index) => '$base ${index + 1}');
  }

  Future<void> _addInstances([EncounterGroup? targetGroup]) async {
    final data = _data!;
    if (data.cards.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在 NPC 库创建 NPC 卡')));
      setState(() => _section = 0);
      return;
    }

    var selectedCard = data.cards.first;
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
                ? '添加 NPC 到当前遭遇'
                : '添加 NPC 到「${targetGroup.name.trim().isEmpty ? '未命名集群' : targetGroup.name}」',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCard.id,
                    decoration: const InputDecoration(labelText: 'NPC 卡'),
                    items: data.cards
                        .map(
                          (card) => DropdownMenuItem(
                            value: card.id,
                            child: Text(
                              card.name.trim().isEmpty ? '未命名 NPC' : card.name,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) => setDialogState(() {
                      selectedCard = data.cards.firstWhere(
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '实例名称',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
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
              label: const Text('加入遭遇'),
            ),
          ],
        ),
      ),
    );

    if (accepted == true) {
      final created = data.addInstances(
        selectedCard,
        controllers.map((item) => item.text).toList(),
      );
      if (targetGroup != null) {
        data.assignInstancesToGroup(
          created.map((instance) => instance.id),
          targetGroup.id,
        );
      }
      await _save();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              targetGroup == null
                  ? '已加入 $count 个 NPC 实例'
                  : '已向「${targetGroup.name.trim().isEmpty ? '未命名集群' : targetGroup.name}」添加 $count 个 NPC 实例',
            ),
          ),
        );
      }
    }
    for (final controller in controllers) {
      controller.dispose();
    }
    for (final controller in retiredControllers) {
      controller.dispose();
    }
  }

  Future<String?> _promptName(String title, String initialValue) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '分类名称'),
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
    return result;
  }

  Future<void> _manageCategories() async {
    final data = _data!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final categories = data.sortedCategories;
          Future<void> add() async {
            final name = await _promptName('创建分类', '');
            if (name == null || name.isEmpty) return;
            data.categories.add(
              NpcCategory(name: name, sortOrder: data.categories.length),
            );
            await _save();
            setDialogState(() {});
          }

          Future<void> rename(NpcCategory category) async {
            final name = await _promptName('重命名分类', category.name);
            if (name == null || name.isEmpty) return;
            category.name = name;
            await _save();
            setDialogState(() {});
          }

          Future<void> remove(NpcCategory category) async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('删除分类'),
                content: Text(
                  '删除「${category.name}」后，其中的 NPC 卡会移动到“默认分类”，卡片不会被删除。',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('删除分类'),
                  ),
                ],
              ),
            );
            if (confirmed != true) return;
            data.deleteCategory(category.id);
            await _save();
            setDialogState(() {});
          }

          Future<void> move(int index, int offset) async {
            final target = index + offset;
            if (categories[index].isDefault ||
                target < 1 ||
                target >= categories.length) {
              return;
            }
            final currentOrder = categories[index].sortOrder;
            categories[index].sortOrder = categories[target].sortOrder;
            categories[target].sortOrder = currentOrder;
            data.normalizeCategoryOrder();
            await _save();
            setDialogState(() {});
          }

          return AlertDialog(
            title: const Text('分类管理'),
            content: SizedBox(
              width: 560,
              height: 440,
              child: ListView.separated(
                itemCount: categories.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final count = data.cards
                      .where((card) => card.categoryId == category.id)
                      .length;
                  return ListTile(
                    leading: Icon(
                      category.isDefault
                          ? Icons.folder_special_outlined
                          : Icons.folder_outlined,
                    ),
                    title: Text(category.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$count 张',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        IconButton(
                          tooltip: '上移',
                          onPressed: category.isDefault || index <= 1
                              ? null
                              : () => move(index, -1),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: '下移',
                          onPressed:
                              category.isDefault ||
                                  index == categories.length - 1
                              ? null
                              : () => move(index, 1),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        PopupMenuButton<String>(
                          tooltip: '分类操作',
                          onSelected: (value) => value == 'rename'
                              ? rename(category)
                              : remove(category),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('重命名'),
                            ),
                            if (!category.isDefault)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('删除'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: add,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('创建分类'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('完成'),
              ),
            ],
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _secondaryNavigation() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 520;
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: 0,
                  icon: compact ? null : const Icon(Icons.people_alt_outlined),
                  label: const Text('NPC 库'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: compact ? null : const Icon(Icons.bookmarks_outlined),
                  label: const Text('遭遇预设'),
                ),
                ButtonSegment(
                  value: 2,
                  icon: compact ? null : const Icon(Icons.sports_martial_arts),
                  label: const Text('当前遭遇'),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (selected) =>
                  setState(() => _section = selected.first),
            ),
          ),
        ),
      );
    },
  );

  Widget _sectionView(DmData data) => switch (_section) {
    0 => NpcLibraryView(
      data: data,
      onEdit: _editCard,
      onDuplicate: _duplicateCard,
      onExport: _exportCard,
      onMoveCategory: _moveCardCategory,
      onDelete: _deleteCard,
      onImport: _importCards,
      onExportBlankTemplate: _exportBlankTemplate,
      onManageCategories: _manageCategories,
    ),
    1 => EncounterPresetView(
      data: data,
      onEdit: _editPreset,
      onDuplicate: _duplicatePreset,
      onDelete: _deletePreset,
      onStart: _startPreset,
      onExtractCurrent: _extractCurrentEncounter,
    ),
    _ => CurrentEncounterView(
      data: data,
      onChanged: _save,
      onAddNpc: _addInstances,
      onSaveAsPreset: _extractCurrentEncounter,
    ),
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppLoadingState(label: '正在加载 DM 数据');
    if (_loadError != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: '无法读取 DM 数据',
        message: '原文件没有被覆盖。请检查文件内容或存储状态后重试。\n$_loadError',
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      );
    }

    final data = _data!;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _secondaryNavigation(),
            Expanded(child: _sectionView(data)),
          ],
        ),
      ),
      floatingActionButton:
          MediaQuery.sizeOf(context).width < kAppDesktopBreakpoint &&
              _section < 2
          ? FloatingActionButton.extended(
              onPressed: _section == 0
                  ? () => _editCard(null)
                  : () => _editPreset(null),
              icon: const Icon(Icons.add),
              label: Text(_section == 0 ? '新建 NPC' : '新建预设'),
            )
          : null,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
