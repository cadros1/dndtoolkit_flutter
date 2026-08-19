import 'package:shared_preferences/shared_preferences.dart';

/// 保存冒险操作台最近选择的角色。
class AdventureSelectionService {
  static const _selectedCharacterIdKey = 'adventure_selected_character_id';

  static AdventureSelectionService? _instance;
  static AdventureSelectionService get instance =>
      _instance ??= AdventureSelectionService._();

  AdventureSelectionService._();

  Future<String?> getSelectedCharacterId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_selectedCharacterIdKey)?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  Future<void> saveSelectedCharacterId(String characterId) async {
    final id = characterId.trim();
    if (id.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCharacterIdKey, id);
  }

  Future<void> clearSelectedCharacterId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedCharacterIdKey);
  }
}
