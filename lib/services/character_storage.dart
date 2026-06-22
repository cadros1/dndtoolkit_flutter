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
  Future<File> saveCharacter(
    Character character, {
    bool touchUpdatedAt = true,
  }) async {
    final path = await _localPath;
    final file = File('$path/${character.id}.json');

    // 保存前更新最后修改时间
    if (touchUpdatedAt) {
      character.updatedAt = DateTime.now().toUtc();
    }

    // 将对象转为 Map，再转为 JSON 字符串
    String jsonStr = jsonEncode(character.toJson());

    return file.writeAsString(jsonStr);
  }

  /// 保存同步下载的角色，保留远端 updatedAt 以维持冲突检测语义。
  Future<File> saveDownloadedCharacter(Character character) {
    return saveCharacter(character, touchUpdatedAt: false);
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
          final content = await entity.readAsString();
          final decoded = jsonDecode(content);
          if (decoded is! Map) {
            stderr.writeln('跳过非角色 JSON 文件：${entity.path}');
            continue;
          }

          final jsonMap = Map<String, dynamic>.from(decoded);
          if (!_looksLikeCharacterJson(jsonMap)) {
            stderr.writeln('跳过结构不匹配的 JSON 文件：${entity.path}');
            continue;
          }

          // 反序列化
          final c = Character.fromJson(jsonMap);
          characters.add(c);
        } catch (e, stackTrace) {
          stderr.writeln('读取角色文件失败，已跳过：${entity.path}');
          stderr.writeln(e);
          stderr.writeln(stackTrace);
        }
      }
    }

    return characters;
  }

  bool _looksLikeCharacterJson(Map<String, dynamic> json) {
    final hasId = json['Id'] is String && (json['Id'] as String).isNotEmpty;
    final hasCharacterSection =
        json.containsKey('Profile') ||
        json.containsKey('Attributes') ||
        json.containsKey('Combat') ||
        json.containsKey('Proficiencies') ||
        json.containsKey('Roleplay') ||
        json.containsKey('Spellbook');
    return hasId && hasCharacterSection;
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
