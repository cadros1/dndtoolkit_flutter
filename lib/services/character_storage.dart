import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/character.dart';

class CharacterStorage {
  /// 获取应用文档目录路径
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// 保存角色
  /// 文件名为: UUID.json
  Future<File> saveCharacter(Character character) async {
    final path = await _localPath;
    final file = File('$path/${character.id}.json');
    
    // 将对象转为 Map，再转为 JSON 字符串
    String jsonStr = jsonEncode(character.toJson());
    
    return file.writeAsString(jsonStr);
  }

  /// 读取所有角色
  Future<List<Character>> loadAllCharacters() async {
    final path = await _localPath;
    final dir = Directory(path);
    List<Character> characters = [];

    // 检查目录是否存在
    if (!await dir.exists()) {
      return [];
    }

    // 获取目录下所有文件
    final List<FileSystemEntity> entities = dir.listSync();

    for (var entity in entities) {
      // 简单的过滤：只读取 .json 结尾的文件
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          String content = await entity.readAsString();
          Map<String, dynamic> jsonMap = jsonDecode(content);
          
          // 反序列化
          Character c = Character.fromJson(jsonMap);
          characters.add(c);
        } catch (e) {
          print("Error loading file ${entity.path}: $e");
          // 可以选择忽略损坏的文件
        }
      }
    }
    
    return characters;
  }

  /// 删除角色 (可选功能，方便测试)
  Future<void> deleteCharacter(String id) async {
    final path = await _localPath;
    final file = File('$path/$id.json');
    if (await file.exists()) {
      await file.delete();
    }
  }
}