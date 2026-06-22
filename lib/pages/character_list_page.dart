import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/character_storage.dart';
import '../services/pdf_data_service.dart';
import '../services/snack_bar_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import 'character_edit_page.dart';

class CharacterListPage extends StatefulWidget {
  const CharacterListPage({super.key});

  @override
  State<CharacterListPage> createState() => _CharacterListPageState();
}

class _CharacterListPageState extends State<CharacterListPage> {
  final CharacterStorage _storage = CharacterStorage();
  List<Character> _characters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await _storage.loadAllCharacters();
      if (mounted) setState(() => _characters = list);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToEditPage([Character? character]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CharacterEditPage(character: character ?? Character()),
      ),
    );
    if (mounted) await _loadData();
  }

  Future<void> _deleteCharacter(Character character) async {
    final name = _characterName(character);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.warning_rounded, color: cs.error, size: 42),
          title: const Text('删除角色'),
          content: Text('确定要删除「$name」吗？此操作无法撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.error),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _storage.deleteCharacter(character.id);
      await _loadData();
      if (mounted) SnackBarService.showSuccess('已删除「$name」');
    }
  }

  Future<void> _importCharacter() async {
    var dialogShown = false;
    try {
      SnackBarService.showInfo('导入中...');
      if (!mounted) return;
      dialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: AppPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在导入角色...'),
              ],
            ),
          ),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      final char = await PdfDataService.importCharacterPdfAsync();
      if (char == null) throw Exception('导入失败');
      await _storage.saveCharacter(char);
      await _loadData();
      if (mounted) Navigator.pop(context);
      SnackBarService.showSuccess('导入成功');
    } catch (e) {
      if (dialogShown && mounted) Navigator.pop(context);
      SnackBarService.showError(e.toString());
    }
  }

  Future<void> _exportCharacter(Character char) async {
    var dialogShown = false;
    try {
      if (!mounted) return;
      dialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: AppPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在导出 PDF...'),
              ],
            ),
          ),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      await PdfDataService.exportCharacterPdfAsync(char);
      if (mounted) Navigator.pop(context);
      SnackBarService.showSuccess('导出完成');
    } catch (e) {
      if (dialogShown && mounted) Navigator.pop(context);
      SnackBarService.showError(e.toString());
    }
  }

  String _characterName(Character char) {
    return char.profile.characterName.trim().isEmpty
        ? '未命名角色'
        : char.profile.characterName.trim();
  }

  String _details(Character char) {
    final parts = [
      char.profile.race.trim(),
      char.profile.classAndLevel.trim(),
    ].where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? '未配置种族/职业' : parts.join(' | ');
  }

  String _idPrefix(Character char) =>
      char.id.length >= 4 ? char.id.substring(0, 4) : char.id;

  Widget _buildAvatar(Character char, {double radius = 24}) {
    if (char.profile.portraitBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(char.profile.portraitBase64);
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
          backgroundColor: Colors.transparent,
        );
      } catch (_) {}
    }

    final cs = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      child: Text(
        _characterName(char).characters.first,
        style: TextStyle(
          fontSize: radius * 0.78,
          color: cs.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return AppPageHeader(
      icon: Icons.groups_2_outlined,
      title: '角色管理',
      subtitle: _characters.isEmpty
          ? '创建角色卡，或从 PDF 导入已有角色。'
          : '共 ${_characters.length} 名角色。点击卡片进入编辑。',
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('从 PDF 导入'),
          onPressed: _importCharacter,
        ),
        if (isDesktop)
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('新建角色'),
            onPressed: () => _navigateToEditPage(),
          ),
      ],
    );
  }

  Widget _buildMobileImportBar() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            _characters.isEmpty
                ? '导入已有角色卡，或使用右下角新建。'
                : '共 ${_characters.length} 名角色',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('从 PDF 导入'),
          onPressed: _importCharacter,
        ),
      ],
    );
  }

  Widget _buildCharacterCard(Character char, {required bool compact}) {
    final cs = Theme.of(context).colorScheme;
    final c = char.combat;
    final hpColor =
        c.hitPointsMax > 0 && c.hitPointsCurrent < c.hitPointsMax / 4
        ? cs.error
        : AppTheme.success;

    return AppPanel(
      padding: compact ? const EdgeInsets.all(14) : const EdgeInsets.all(18),
      onTap: () => _navigateToEditPage(char),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(char, radius: compact ? 25 : 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: _characterName(char)),
                          TextSpan(
                            text: ' #${_idPrefix(char)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _details(char),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '角色操作',
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'export') _exportCharacter(char);
                  if (value == 'delete') _deleteCharacter(char);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.picture_as_pdf_outlined),
                      title: Text('导出 PDF'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline, color: cs.error),
                      title: Text('删除', style: TextStyle(color: cs.error)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppStatPill(
                icon: Icons.favorite_outline,
                label: 'HP',
                value: '${c.hitPointsCurrent}/${c.hitPointsMax}',
                color: hpColor,
              ),
              AppStatPill(
                icon: Icons.shield_outlined,
                label: 'AC',
                value: '${c.armorClass}',
              ),
              AppStatPill(
                icon: Icons.bolt_outlined,
                label: '先攻',
                value: c.initiative >= 0
                    ? '+${c.initiative}'
                    : '${c.initiative}',
                color: AppTheme.info,
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _navigateToEditPage(char),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('编辑角色卡'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState({bool showImportAction = true}) {
    return AppEmptyState(
      icon: Icons.person_add_alt_1_outlined,
      title: '还没有角色',
      message: '先创建一个角色卡，跑团时就能快速检定、记录状态并导出 PDF。',
      action: FilledButton.icon(
        icon: const Icon(Icons.add),
        label: const Text('创建第一个角色'),
        onPressed: () => _navigateToEditPage(),
      ),
      secondaryAction: showImportAction
          ? TextButton.icon(
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('从 PDF 导入'),
              onPressed: _importCharacter,
            )
          : null,
    );
  }

  Widget _buildMobileList() {
    if (_characters.isEmpty) return _buildEmptyState(showImportAction: false);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
      itemCount: _characters.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _buildCharacterCard(_characters[index], compact: true),
    );
  }

  Widget _buildDesktopGrid() {
    if (_characters.isEmpty) return _buildEmptyState();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 340,
        mainAxisExtent: 250,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: _characters.length,
      itemBuilder: (context, index) =>
          _buildCharacterCard(_characters[index], compact: false),
    );
  }

  Widget _buildContent(bool isDesktop) {
    if (_isLoading) return const AppLoadingState(label: '正在读取角色');
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 24 : 16,
            16,
            isDesktop ? 24 : 16,
            isDesktop ? 16 : 12,
          ),
          child: isDesktop ? _buildHeader(isDesktop) : _buildMobileImportBar(),
        ),
        Expanded(child: isDesktop ? _buildDesktopGrid() : _buildMobileList()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kAppDesktopBreakpoint;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(top: isDesktop, child: _buildContent(isDesktop)),
          floatingActionButton: isDesktop
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _navigateToEditPage(),
                  icon: const Icon(Icons.add),
                  label: const Text('新建角色'),
                ),
        );
      },
    );
  }
}
