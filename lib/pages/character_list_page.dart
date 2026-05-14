import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/character.dart';
import '../services/character_storage.dart';
import 'character_edit_page.dart';
import '../services/pdf_data_service.dart';
import '../services/snack_bar_service.dart';

/// 桌面端布局断点，与 main_screen.dart 保持一致
const _kDesktopBreakpoint = 600.0;

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
        builder: (context) => CharacterEditPage(
          character: character ?? Character(),
        ),
      ),
    );
    if (mounted) await _loadData();
  }

  Future<void> _deleteCharacter(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("删除角色"),
        content: const Text("确定要删除该角色吗？此操作无法撤销。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("取消"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("删除"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _storage.deleteCharacter(id);
      await _loadData();
      if (mounted) SnackBarService.showSuccess("已删除该角色");
    }
  }

  // ---- 共享辅助组件 ----

  /// 头像构建，[radius] 默认 20（移动端），桌面端可传入更大值
  Widget _buildAvatar(Character char, {double radius = 20}) {
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
    // 回退：显示名字首字母
    return CircleAvatar(
      radius: radius,
      child: Text(
        char.profile.characterName.isNotEmpty
            ? char.profile.characterName[0]
            : "?",
        style: TextStyle(fontSize: radius * 0.8),
      ),
    );
  }

  /// 角色名 + #id前四位
  Widget _buildNameWithId(Character char) {
    final cs = Theme.of(context).colorScheme;
    final name = char.profile.characterName.isEmpty ? "未命名" : char.profile.characterName;
    final idPrefix = char.id.length >= 4 ? char.id.substring(0, 4) : char.id;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: name),
          TextSpan(
            text: ' #$idPrefix',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
        ],
      ),
    );
  }

  // ---- 操作按钮组件 ----

  Widget _buildEditButton(Character char, {bool iconOnly = false}) {
    if (iconOnly) {
      return IconButton(
        icon: const Icon(Icons.edit, color: Colors.blue),
        tooltip: '编辑',
        onPressed: () => _navigateToEditPage(char),
      );
    }
    return TextButton.icon(
      icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
      label: const Text("编辑", style: TextStyle(color: Colors.blue)),
      onPressed: () => _navigateToEditPage(char),
    );
  }

  Widget _buildExportButton(Character char, {bool iconOnly = false}) {
    if (iconOnly) {
      return IconButton(
        icon: const Icon(Icons.picture_as_pdf, color: Colors.green),
        tooltip: '导出 PDF',
        onPressed: () => _exportCharacter(char),
      );
    }
    return TextButton.icon(
      icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.green),
      label: const Text("导出", style: TextStyle(color: Colors.green)),
      onPressed: () => _exportCharacter(char),
    );
  }

  Widget _buildDeleteButton(String id, {bool iconOnly = false}) {
    if (iconOnly) {
      return IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        tooltip: '删除',
        onPressed: () => _deleteCharacter(id),
      );
    }
    return TextButton.icon(
      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
      label: const Text("删除", style: TextStyle(color: Colors.red)),
      onPressed: () => _deleteCharacter(id),
    );
  }

  // ---- 导入导出逻辑 ----

  Future<void> _importCharacter() async {
    var dialogShown = false;
    try {
      SnackBarService.showInfo("导入中...");
      if (!mounted) return;
      dialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("正在导入角色..."),
                ],
              ),
            ),
          ),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      final char = await PdfDataService.importCharacterPdfAsync();
      if (char == null) throw Exception("导入失败");
      await _storage.saveCharacter(char);
      await _loadData();
      if (mounted) Navigator.pop(context);
      SnackBarService.showSuccess("导入成功！");
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
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("正在导出 PDF..."),
                ],
              ),
            ),
          ),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      await PdfDataService.exportCharacterPdfAsync(char);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (dialogShown && mounted) Navigator.pop(context);
      SnackBarService.showError(e.toString());
    }
  }

  // ---- 移动端卡片 ----
  Widget _buildMobileCard(Character char) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: _buildAvatar(char, radius: 20),
        title: _buildNameWithId(char),
        subtitle: Text("${char.profile.race} ${char.profile.classAndLevel}"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEditButton(char, iconOnly: true),
            _buildExportButton(char, iconOnly: true),
            _buildDeleteButton(char.id, iconOnly: true),
          ],
        ),
        onTap: () => _navigateToEditPage(char),
      ),
    );
  }

  // ---- 桌面端卡片 ----
  Widget _buildDesktopCard(Character char) {
    final cs = Theme.of(context).colorScheme;
    final c = char.combat;

    return Card(
      margin: const EdgeInsets.all(6),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToEditPage(char),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 头像
              _buildAvatar(char, radius: 36),
              const SizedBox(height: 10),
              // 角色名 + id
              DefaultTextStyle(
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
                child: _buildNameWithId(char),
              ),
              const SizedBox(height: 2),
              // 种族 | 职业
              Text(
                char.profile.race.isNotEmpty || char.profile.classAndLevel.isNotEmpty
                    ? '${char.profile.race}${char.profile.race.isNotEmpty && char.profile.classAndLevel.isNotEmpty ? " | " : ""}${char.profile.classAndLevel}'
                    : '未配置种族/职业',
                style: TextStyle(fontSize: 12, color: cs.outline),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // 战斗摘要
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatChip('HP', '${c.hitPointsCurrent}/${c.hitPointsMax}'),
                  const SizedBox(width: 12),
                  _buildStatChip('AC', '${c.armorClass}'),
                ],
              ),
              const SizedBox(height: 10),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildEditButton(char),
                  _buildExportButton(char),
                  _buildDeleteButton(char.id),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
      ),
    );
  }

  // ---- 桌面端顶部工具栏 ----
  Widget _buildDesktopToolbar() {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text(
              '角色列表',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.file_upload, size: 18),
              label: const Text("从PDF导入"),
              onPressed: _importCharacter,
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text("新建角色"),
              onPressed: () => _navigateToEditPage(),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 桌面端网格内容 ----
  Widget _buildDesktopGrid() {
    if (_characters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64,
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text("还没有角色", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("创建第一个角色"),
              onPressed: () => _navigateToEditPage(),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 270,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: _characters.length,
      itemBuilder: (context, index) => _buildDesktopCard(_characters[index]),
    );
  }

  // ---- 移动端布局 ----
  Widget _buildMobileLayout() {
    if (_characters.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("还没有角色"),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => _navigateToEditPage(),
                child: const Text("创建第一个角色"),
              ),
            ],
          ),
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: "import_btn",
              onPressed: _importCharacter,
              tooltip: '从PDF导入',
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
              child: const Icon(Icons.file_upload),
            ),
            const SizedBox(height: 16),
            FloatingActionButton(
              heroTag: "new_btn",
              onPressed: () => _navigateToEditPage(),
              tooltip: '新建角色',
              child: const Icon(Icons.add),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: ListView.builder(
        itemCount: _characters.length,
        itemBuilder: (context, index) => _buildMobileCard(_characters[index]),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "import_btn",
            onPressed: _importCharacter,
            tooltip: '从PDF导入',
            backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            child: const Icon(Icons.file_upload),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "new_btn",
            onPressed: () => _navigateToEditPage(),
            tooltip: '新建角色',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  // ---- 桌面端布局 ----
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Column(
        children: [
          _buildDesktopToolbar(),
          Expanded(child: _buildDesktopGrid()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _kDesktopBreakpoint) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }
}
