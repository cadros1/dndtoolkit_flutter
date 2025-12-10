import 'dart:convert'; // [新增] 用于 base64Decode
import 'dart:typed_data'; // [新增] 用于 Uint8List
import 'package:flutter/material.dart';
import '../models/character.dart';
import '../services/character_storage.dart';
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
    await _storage.deleteCharacter(id);
    await _loadData();
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
        print("Avatar decode error: $e");
      }
    }

    // 2. 回退方案：显示文字
    return CircleAvatar(
      child: Text(char.profile.characterName.isNotEmpty
          ? char.profile.characterName[0]
          : "?"),
    );
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditPage(),
        tooltip: '新建角色',
        child: const Icon(Icons.add),
      ),
    );
  }
}