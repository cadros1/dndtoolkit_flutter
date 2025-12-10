import 'package:dndtoolkit_flutter/pages/tabs/spellbook_tab.dart';
import 'package:flutter/material.dart';
import '../models/character.dart';
import '../services/character_storage.dart';

import 'tabs/basic_info_tab.dart';
import 'tabs/proficiencies_tab.dart';
import 'tabs/combat_tab.dart';
import 'tabs/character_settings_tab.dart';

class CharacterEditPage extends StatefulWidget {
  final Character character;

  const CharacterEditPage({super.key, required this.character});

  @override
  State<CharacterEditPage> createState() => _CharacterEditPageState();
}

class _CharacterEditPageState extends State<CharacterEditPage> {
  final CharacterStorage _storage = CharacterStorage();
  late Character _editingChar;

  // Tab 定义
  final List<String> _tabs = [
    "基础信息",
    "技能豁免",
    "战斗数据",
    "人物设定",
    "施法信息",
  ];

  @override
  void initState() {
    super.initState();
    _editingChar = widget.character;
  }

  Future<void> _saveAndExit() async {
    _editingChar.combat.hitDiceCurrent = _editingChar.combat.hitDiceTotal;
    _editingChar.combat.hitPointsCurrent = _editingChar.combat.hitPointsMax;
    _editingChar.combat.hitPointsTemp = 0;
    for (var spellLevelGroup in _editingChar.spellbook.allSpells) {
      spellLevelGroup.remainSlots = spellLevelGroup.totalSlots;
    }
    await _storage.saveCharacter(_editingChar);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('角色已保存')),
    );

    Navigator.pop(context, true); 
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_editingChar.profile.characterName.isEmpty
              ? "新建角色"
              : _editingChar.profile.characterName),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.save),
              label: const Text("保存"),
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              onPressed: _saveAndExit,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
        body: TabBarView(
          children: [
            // 1. 基础信息
            BasicInfoTab(character: _editingChar),
            
            // 2. 技能与豁免
            ProficienciesTab(character: _editingChar),
            
            // 3. 战斗数据
            CombatTab(character: _editingChar),

            // 4. 人物设定
            CharacterSettingsTab(character: _editingChar),
            
            // 5. 施法信息
            SpellbookTab(character: _editingChar),
          ],
        ),
      ),
    );
  }
}