import 'package:flutter/material.dart';

import '../../models/dm_models.dart';
import '../../widgets/app_ui.dart';

class NpcLibraryView extends StatefulWidget {
  final DmData data;
  final Future<void> Function(NpcCard? card) onEdit;
  final Future<void> Function(NpcCard card) onDuplicate;
  final Future<void> Function(NpcCard card) onExport;
  final Future<void> Function(NpcCard card) onMoveCategory;
  final Future<void> Function(NpcCard card) onDelete;
  final Future<void> Function() onImport;
  final Future<void> Function() onExportBlankTemplate;
  final Future<void> Function() onManageCategories;

  const NpcLibraryView({
    super.key,
    required this.data,
    required this.onEdit,
    required this.onDuplicate,
    required this.onExport,
    required this.onMoveCategory,
    required this.onDelete,
    required this.onImport,
    required this.onExportBlankTemplate,
    required this.onManageCategories,
  });

  @override
  State<NpcLibraryView> createState() => _NpcLibraryViewState();
}

class _NpcLibraryViewState extends State<NpcLibraryView> {
  static const _all = '__all__';
  String _query = '';
  String _categoryFilter = _all;

  String _categoryName(NpcCard card) {
    return widget.data.categories
            .where((category) => category.id == card.categoryId)
            .map((category) => category.name)
            .firstOrNull ??
        defaultNpcCategoryName;
  }

  List<NpcCard> get _filteredCards {
    final normalized = _query.trim().toLowerCase();
    final cards = widget.data.cards.where((card) {
      final matchesCategory =
          _categoryFilter == _all || card.categoryId == _categoryFilter;
      if (!matchesCategory) return false;
      if (normalized.isEmpty) return true;
      return [
        card.name,
        card.sizeAndType,
        card.challengeRating,
        card.speed,
        _categoryName(card),
      ].any((value) => value.toLowerCase().contains(normalized));
    }).toList();
    cards.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return cards;
  }

  Widget _searchField() => TextField(
    decoration: const InputDecoration(
      labelText: '搜索 NPC 卡',
      prefixIcon: Icon(Icons.search),
    ),
    onChanged: (value) => setState(() => _query = value),
  );

  Widget _categoryDropdown() => DropdownButtonFormField<String>(
    initialValue: _categoryFilter,
    decoration: const InputDecoration(labelText: '分类筛选'),
    items: [
      const DropdownMenuItem(value: _all, child: Text('全部')),
      ...widget.data.sortedCategories.map(
        (category) =>
            DropdownMenuItem(value: category.id, child: Text(category.name)),
      ),
    ],
    onChanged: (value) => setState(() => _categoryFilter = value ?? _all),
  );

  Widget _card(NpcCard card) {
    final cs = Theme.of(context).colorScheme;
    final name = card.name.trim().isEmpty ? '未命名 NPC' : card.name.trim();
    final meta = [
      _categoryName(card),
      card.sizeAndType.trim(),
      if (card.challengeRating.trim().isNotEmpty)
        'CR ${card.challengeRating.trim()}',
    ].where((part) => part.isNotEmpty).join(' · ');

    return AppPanel(
      padding: EdgeInsets.zero,
      onTap: () => widget.onEdit(card),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_search_outlined, color: cs.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        meta.isEmpty ? '未填写分类与类型' : meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '更多操作',
                  onSelected: (value) {
                    switch (value) {
                      case 'export':
                        widget.onExport(card);
                      case 'copy':
                        widget.onDuplicate(card);
                      case 'move':
                        widget.onMoveCategory(card);
                      case 'delete':
                        widget.onDelete(card);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'export', child: Text('导出 Markdown')),
                    PopupMenuItem(value: 'copy', child: Text('复制')),
                    PopupMenuItem(value: 'move', child: Text('移动分类')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => AppEmptyState(
    icon: _query.isEmpty ? Icons.person_search_outlined : Icons.search_off,
    title: widget.data.cards.isEmpty ? '还没有 NPC 卡' : '没有匹配结果',
    message: widget.data.cards.isEmpty
        ? '手工创建一张 NPC 卡，即可在当前遭遇中重复实例化使用。'
        : '请调整搜索词或分类筛选。',
    action: widget.data.cards.isEmpty
        ? FilledButton.icon(
            onPressed: () => widget.onEdit(null),
            icon: const Icon(Icons.add),
            label: const Text('新建 NPC 卡'),
          )
        : null,
  );

  Widget _cardsLayout(List<NpcCard> cards, double maxWidth) {
    if (cards.isEmpty) return _empty();
    final columns = maxWidth >= 980
        ? 3
        : maxWidth >= 620
        ? 2
        : 1;
    if (columns == 1) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) => _card(cards[index]),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 72,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) => _card(cards[index]),
    );
  }

  Widget _mobile(List<NpcCard> cards) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: Column(
          children: [
            _searchField(),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _categoryDropdown()),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'NPC 库操作',
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    switch (value) {
                      case 'import':
                        widget.onImport();
                      case 'template':
                        widget.onExportBlankTemplate();
                      case 'categories':
                        widget.onManageCategories();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'import', child: Text('导入 Markdown')),
                    PopupMenuItem(value: 'template', child: Text('导出空白模板')),
                    PopupMenuItem(value: 'categories', child: Text('管理分类')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (_, c) => _cardsLayout(cards, c.maxWidth),
        ),
      ),
    ],
  );

  Widget _desktop(List<NpcCard> cards) {
    final cs = Theme.of(context).colorScheme;
    final categories = widget.data.sortedCategories;
    Widget categoryTile(String value, String label, IconData icon) => ListTile(
      selected: _categoryFilter == value,
      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Icon(icon),
      title: Text(label),
      onTap: () => setState(() => _categoryFilter = value),
    );

    return Row(
      children: [
        SizedBox(
          width: 220,
          child: Material(
            color: cs.surface,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                categoryTile(_all, '全部', Icons.select_all),
                const SizedBox(height: 4),
                const Divider(height: 16),
                ...categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: categoryTile(
                      category.id,
                      category.name,
                      Icons.folder_outlined,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: widget.onManageCategories,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('管理分类'),
                ),
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1, color: cs.outlineVariant),
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(child: _searchField()),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: widget.onImport,
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('导入'),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'NPC 库操作',
                      onSelected: (value) {
                        if (value == 'template') {
                          widget.onExportBlankTemplate();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'template', child: Text('导出空白模板')),
                      ],
                    ),
                    const SizedBox(width: 4),
                    FilledButton.icon(
                      onPressed: () => widget.onEdit(null),
                      icon: const Icon(Icons.add),
                      label: const Text('新建 NPC'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, constraints) =>
                      _cardsLayout(cards, constraints.maxWidth),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = _filteredCards;
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= kAppDesktopBreakpoint
          ? _desktop(cards)
          : _mobile(cards),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
