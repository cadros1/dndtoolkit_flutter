import 'package:flutter/material.dart';

import '../../models/dm_models.dart';
import '../../services/npc_markdown_service.dart';
import '../../widgets/app_ui.dart';

class NpcMarkdownImportSelection {
  final NpcMarkdownImportResult result;
  final String? categoryId;
  final String? categoryNameToCreate;

  const NpcMarkdownImportSelection({
    required this.result,
    this.categoryId,
    this.categoryNameToCreate,
  });
}

class NpcMarkdownImportPage extends StatefulWidget {
  final List<NpcMarkdownImportResult> results;
  final List<NpcCategory> categories;

  const NpcMarkdownImportPage({
    super.key,
    required this.results,
    required this.categories,
  });

  @override
  State<NpcMarkdownImportPage> createState() => _NpcMarkdownImportPageState();
}

class _NpcMarkdownImportPageState extends State<NpcMarkdownImportPage> {
  static const _createPrefix = '__create__:';
  late final List<_ImportDraft> _drafts;

  @override
  void initState() {
    super.initState();
    _drafts = List.generate(widget.results.length, (index) {
      final result = widget.results[index];
      final categoryName = result.categoryName.trim();
      final existing = categoryName.isEmpty
          ? null
          : widget.categories
                .where(
                  (category) =>
                      category.name.trim().toLowerCase() ==
                      categoryName.toLowerCase(),
                )
                .firstOrNull;
      return _ImportDraft(
        selected: result.importable,
        categoryChoice:
            existing?.id ??
            (categoryName.isEmpty
                ? defaultNpcCategoryId
                : '$_createPrefix$index'),
      );
    });
  }

  int get _selectedCount {
    var count = 0;
    for (var index = 0; index < widget.results.length; index++) {
      if (widget.results[index].importable && _drafts[index].selected) count++;
    }
    return count;
  }

  List<NpcMarkdownImportSelection> _selections() {
    final selections = <NpcMarkdownImportSelection>[];
    for (var index = 0; index < widget.results.length; index++) {
      final result = widget.results[index];
      final draft = _drafts[index];
      if (!result.importable || !draft.selected) continue;
      if (draft.categoryChoice.startsWith(_createPrefix)) {
        selections.add(
          NpcMarkdownImportSelection(
            result: result,
            categoryNameToCreate: result.categoryName.trim(),
          ),
        );
      } else {
        selections.add(
          NpcMarkdownImportSelection(
            result: result,
            categoryId: draft.categoryChoice,
          ),
        );
      }
    }
    return selections;
  }

  Color _statusColor(ColorScheme colors, NpcMarkdownImportStatus status) =>
      switch (status) {
        NpcMarkdownImportStatus.verified => colors.primaryContainer,
        NpcMarkdownImportStatus.modified => colors.errorContainer,
        NpcMarkdownImportStatus.arbitrary => colors.secondaryContainer,
        NpcMarkdownImportStatus.unsupported => colors.tertiaryContainer,
        NpcMarkdownImportStatus.invalid => colors.surfaceContainerHighest,
      };

  Widget _statusPill(NpcMarkdownImportResult result) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusColor(colors, result.status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        result.statusLabel,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _categoryPicker(int index, NpcMarkdownImportResult result) {
    final draft = _drafts[index];
    final createChoice = '$_createPrefix$index';
    final canCreate =
        result.categoryName.trim().isNotEmpty &&
        !widget.categories.any(
          (category) =>
              category.name.trim().toLowerCase() ==
              result.categoryName.trim().toLowerCase(),
        );
    return DropdownButtonFormField<String>(
      key: ValueKey(draft.categoryChoice),
      initialValue: draft.categoryChoice,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '导入到分类',
        prefixIcon: Icon(Icons.folder_outlined),
      ),
      items: [
        ...widget.categories.map(
          (category) => DropdownMenuItem(
            value: category.id,
            child: Text(category.name, overflow: TextOverflow.ellipsis),
          ),
        ),
        if (canCreate)
          DropdownMenuItem(
            value: createChoice,
            child: Text(
              '创建“${result.categoryName.trim()}”',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: draft.selected
          ? (value) {
              if (value != null) {
                setState(() => draft.categoryChoice = value);
              }
            }
          : null,
    );
  }

  Widget _preview(NpcCard card) {
    final colors = Theme.of(context).colorScheme;
    final details = [
      if (card.sizeAndType.trim().isNotEmpty) card.sizeAndType.trim(),
      if (card.challengeRating.trim().isNotEmpty)
        'CR ${card.challengeRating.trim()}',
    ].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            card.name.trim().isEmpty ? '未命名 NPC' : card.name.trim(),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (details.isNotEmpty) Text(details),
          Text('AC ${card.armorClass}'),
          Text('HP ${card.maximumHitPoints}'),
          Text(
            '特性/动作 ${card.traits.length + card.actions.length + card.bonusActions.length + card.reactions.length + card.legendaryActions.length}',
          ),
        ],
      ),
    );
  }

  Widget _detailSection(NpcMarkdownImportResult result) {
    final rows = <Widget>[];
    if (result.warnings.isNotEmpty) {
      rows.add(_detailGroup('提醒', result.warnings));
    }
    if (result.missingFields.isNotEmpty) {
      rows.add(_detailGroup('缺失字段', result.missingFields));
    }
    if (result.unrecognizedContent.isNotEmpty) {
      rows.add(_detailGroup('未识别内容', result.unrecognizedContent));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 4),
      title: Text('识别详情（${rows.length} 类）'),
      children: rows,
    );
  }

  Widget _detailGroup(String label, List<String> values) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Align(
      alignment: Alignment.centerLeft,
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
          ...values
              .take(20)
              .map(
                (value) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $value'),
                ),
              ),
          if (values.length > 20) Text('另有 ${values.length - 20} 项未显示'),
        ],
      ),
    ),
  );

  Widget _resultCard(int index) {
    final result = widget.results[index];
    final draft = _drafts[index];
    final colors = Theme.of(context).colorScheme;
    return AppPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: result.importable && draft.selected,
                onChanged: result.importable
                    ? (value) => setState(() => draft.selected = value ?? false)
                    : null,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    result.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: _statusPill(result),
              ),
            ],
          ),
          if (result.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(result.errorMessage!),
            ),
          ],
          if (result.card != null) ...[
            const SizedBox(height: 8),
            _preview(result.card!),
            const SizedBox(height: 10),
            _categoryPicker(index, result),
          ],
          _detailSection(result),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedCount;
    final importableCount = widget.results
        .where((item) => item.importable)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('导入 NPC Markdown')),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              itemCount: widget.results.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${widget.results.length} 个文件 · $importableCount 个可导入',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      TextButton(
                        onPressed: importableCount == 0
                            ? null
                            : () => setState(() {
                                final selectAll =
                                    selectedCount < importableCount;
                                for (
                                  var item = 0;
                                  item < widget.results.length;
                                  item++
                                ) {
                                  if (widget.results[item].importable) {
                                    _drafts[item].selected = selectAll;
                                  }
                                }
                              }),
                        child: Text(
                          selectedCount < importableCount ? '全选' : '取消全选',
                        ),
                      ),
                    ],
                  );
                }
                return _resultCard(index - 1);
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: FilledButton.icon(
            onPressed: selectedCount == 0
                ? null
                : () => Navigator.pop(context, _selections()),
            icon: const Icon(Icons.file_download_done_outlined),
            label: Text('导入所选 $selectedCount 张'),
          ),
        ),
      ),
    );
  }
}

class _ImportDraft {
  bool selected;
  String categoryChoice;

  _ImportDraft({required this.selected, required this.categoryChoice});
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
