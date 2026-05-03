import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/character.dart';
import '../services/character_storage.dart';
import 'character_edit_page.dart';
import '../services/pdf_data_service.dart';
import '../services/snack_bar_service.dart';

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
      setState(() {
        _characters = list;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

    if (mounted) {
      await _loadData();
    }
  }

  Future<void> _deleteCharacter(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("删除角色"),
        content: Text("确定要删除该角色吗？此操作无法撤销。"),
        actions:[
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
      SnackBarService.showSuccess("已删除该角色");
    }
  }

  // [新增] 构建头像的辅助方法
  Widget _buildAvatar(Character char) {
    // 1. 尝试读取图片
    if (char.profile.portraitBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(char.profile.portraitBase64);
        return CircleAvatar(
          backgroundImage: MemoryImage(bytes), // 有图显示图
          backgroundColor: Colors.transparent, // 防止背景色干扰
        );
      } catch (e) {
        // 解码失败（比如数据损坏），静默失败并显示文字
        //print("Avatar decode error: $e");
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("头像加载失败"),
            content: Text("$e"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("确定"),
              ),
            ],
          ),
        );
      }
    }

    // 2. 回退方案：显示文字
    return CircleAvatar(
      child: Text(char.profile.characterName.isNotEmpty
          ? char.profile.characterName[0]
          : "?"),
    );
  }

  // 导入处理的辅助方法
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

  // 导出处理的辅助方法
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: _characters.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("还没有角色"),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _navigateToEditPage(),
                    child: const Text("创建第一个角色"),
                  )
                ],
              ),
            )
          : ListView.builder(
              itemCount: _characters.length,
              itemBuilder: (context, index) {
                final char = _characters[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    // [修改] 使用新的头像构建方法
                    leading: _buildAvatar(char),
                    
                    title: Text(char.profile.characterName.isEmpty
                        ? "未命名"
                        : char.profile.characterName),
                    subtitle: Text(
                        "${char.profile.race} ${char.profile.classAndLevel}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _navigateToEditPage(char),
                        ),
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.green),
                          onPressed: () => _exportCharacter(char),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteCharacter(char.id),
                        ),
                      ],
                    ),
                    onTap: () => _navigateToEditPage(char),
                  ),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children:[
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
}