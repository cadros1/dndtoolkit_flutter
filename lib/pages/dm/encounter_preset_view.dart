import 'package:flutter/material.dart';

import '../../models/dm_models.dart';
import '../../widgets/app_ui.dart';

class EncounterPresetView extends StatefulWidget {
  final DmData data;
  final Future<void> Function(EncounterPreset? preset) onEdit;
  final Future<void> Function(EncounterPreset preset) onDuplicate;
  final Future<void> Function(EncounterPreset preset) onDelete;
  final Future<void> Function(EncounterPreset preset) onStart;
  final Future<void> Function() onExtractCurrent;

  const EncounterPresetView({
    super.key,
    required this.data,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onStart,
    required this.onExtractCurrent,
  });

  @override
  State<EncounterPresetView> createState() => _EncounterPresetViewState();
}

class _EncounterPresetViewState extends State<EncounterPresetView> {
  String _query = '';

  List<EncounterPreset> get _filteredPresets {
    final query = _query.trim().toLowerCase();
    final presets = widget.data.presets.where((preset) {
      if (query.isEmpty) return true;
      return [
        preset.name,
        ...preset.groups.map((group) => group.name),
        ...preset.entries.map((entry) => entry.displayCardName),
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
    presets.sort(
      (left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
    );
    return presets;
  }

  Widget _searchField() => TextField(
    decoration: const InputDecoration(
      labelText: '搜索遭遇预设',
      prefixIcon: Icon(Icons.search),
    ),
    onChanged: (value) => setState(() => _query = value),
  );

  Widget _presetCard(EncounterPreset preset) {
    final colors = Theme.of(context).colorScheme;
    final name = preset.name.trim().isEmpty ? '未命名预设' : preset.name.trim();
    final npcNames = preset.entries
        .map((entry) => entry.displayCardName)
        .toSet()
        .take(3)
        .join('、');
    return AppPanel(
      padding: EdgeInsets.zero,
      onTap: () => widget.onEdit(preset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.bookmarks_outlined,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '预设操作',
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        widget.onEdit(preset);
                      case 'copy':
                        widget.onDuplicate(preset);
                      case 'delete':
                        widget.onDelete(preset);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'copy', child: Text('复制')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                AppStatPill(label: 'NPC', value: '${preset.instanceCount}'),
                AppStatPill(label: '集群', value: '${preset.groups.length}'),
              ],
            ),
            if (npcNames.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                npcNames,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => widget.onStart(preset),
              icon: const Icon(Icons.play_arrow),
              label: const Text('创建当前遭遇'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => AppEmptyState(
    icon: _query.isEmpty ? Icons.bookmarks_outlined : Icons.search_off,
    title: widget.data.presets.isEmpty ? '还没有遭遇预设' : '没有匹配结果',
    message: widget.data.presets.isEmpty
        ? '创建预设后，可以按保存的 NPC 数量、名称和集群安排快速开始遭遇。'
        : '请调整搜索词。',
    action: widget.data.presets.isEmpty
        ? FilledButton.icon(
            onPressed: () => widget.onEdit(null),
            icon: const Icon(Icons.add),
            label: const Text('新建遭遇预设'),
          )
        : null,
    secondaryAction:
        widget.data.presets.isEmpty && !widget.data.encounter.isEmpty
        ? OutlinedButton.icon(
            onPressed: widget.onExtractCurrent,
            icon: const Icon(Icons.save_as_outlined),
            label: const Text('从当前遭遇创建'),
          )
        : null,
  );

  Widget _list(List<EncounterPreset> presets, double width) {
    if (presets.isEmpty) return _empty();
    final columns = width >= 1000
        ? 3
        : width >= 640
        ? 2
        : 1;
    if (columns == 1) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
        itemCount: presets.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _presetCard(presets[index]),
      );
    }
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final cardExtent = 190.0 + ((textScale - 1).clamp(0, 1) * 72).toDouble();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: cardExtent,
      ),
      itemCount: presets.length,
      itemBuilder: (context, index) => _presetCard(presets[index]),
    );
  }

  Widget _mobile(List<EncounterPreset> presets) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: Row(
          children: [
            Expanded(child: _searchField()),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: '预设页面操作',
              onSelected: (value) {
                if (value == 'extract') widget.onExtractCurrent();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'extract',
                  enabled: !widget.data.encounter.isEmpty,
                  child: const Text('从当前遭遇创建'),
                ),
              ],
            ),
          ],
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) =>
              _list(presets, constraints.maxWidth),
        ),
      ),
    ],
  );

  Widget _desktop(List<EncounterPreset> presets) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Expanded(child: _searchField()),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: widget.data.encounter.isEmpty
                  ? null
                  : widget.onExtractCurrent,
              icon: const Icon(Icons.save_as_outlined),
              label: const Text('从当前遭遇创建'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => widget.onEdit(null),
              icon: const Icon(Icons.add),
              label: const Text('新建预设'),
            ),
          ],
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) =>
              _list(presets, constraints.maxWidth),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final presets = _filteredPresets;
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= kAppDesktopBreakpoint
          ? _desktop(presets)
          : _mobile(presets),
    );
  }
}
