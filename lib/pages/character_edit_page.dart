import 'dart:convert'; // [新增] 用于 JSON 序列化比对
import 'package:flutter/material.dart';
import '../models/character.dart';
import '../services/character_storage.dart';

import 'tabs/basic_info_tab.dart';
import 'tabs/proficiencies_tab.dart';
import 'tabs/combat_tab.dart';
import 'tabs/character_settings_tab.dart';
import 'tabs/spellbook_tab.dart';

class CharacterEditPage extends StatefulWidget {
  final Character character;

  const CharacterEditPage({super.key, required this.character});

  @override
  State<CharacterEditPage> createState() => _CharacterEditPageState();
}

class _CharacterEditPageState extends State<CharacterEditPage> {
  final CharacterStorage _storage = CharacterStorage();
  late Character _editingChar;

  // [新增] 用于脏检查，记录初始状态的 JSON 字符串
  late String _initialJson; 
  // [新增] 用于控制是否允许直接退出
  bool _forceExit = false;

  // Tab 定义
  final List<String> _tabs =[
    "基础信息",
    "技能豁免",
    "冒险信息",
    "人物设定",
    "施法信息",
  ];

  @override
  void initState() {
    super.initState();
    _editingChar = widget.character;
    // 记录刚进入页面时的角色数据快照
    _initialJson = jsonEncode(_editingChar.toJson());
  }

  // [新增] 判断是否有未保存的修改
  bool _hasChanges() {
    return _initialJson != jsonEncode(_editingChar.toJson());
  }

  // [新增] 强制执行退出操作，绕过拦截
  void _performExit([bool saved = false]) {
    setState(() {
      _forceExit = true;
    });
    // 等待下一帧渲染完成，canPop 生效后执行真正的 Pop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, saved);
    });
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

    //[修改] 调用强制退出方法，并带回 true 标记已保存
    _performExit(true); 
  }

  // [新增] 显示退出确认对话框
  Future<String?> _showExitDialog() {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("未保存的更改"),
        content: const Text("您修改了角色卡但尚未保存，直接退出将丢失本次编辑的内容。"),
        actions:[
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text("直接退出", style: TextStyle(color: Colors.red)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text("保存并退出"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // [修改] 使用 PopScope 包裹，拦截返回事件
    return PopScope(
      canPop: _forceExit, // 如果为 false，则拦截返回并触发 onPopInvokedWithResult
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // 已经成功退出，直接返回

        // 1. 如果没有任何修改，直接放行退出
        if (!_hasChanges()) {
          _performExit();
          return;
        }

        // 2. 如果有修改，弹出确认框
        final String? action = await _showExitDialog();
        
        // 3. 根据用户的选择执行相应的逻辑
        if (action == 'save') {
          await _saveAndExit();
        } else if (action == 'discard') {
          _performExit(); // 丢弃修改，直接退出
        }
        // 如果 action == 'cancel' 或点击了空白处关闭弹窗，则什么也不做，留在当前页面
      },
      child: DefaultTabController(
        length: _tabs.length,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_editingChar.profile.characterName.isEmpty
                ? "新建角色"
                : _editingChar.profile.characterName),
            actions:[
              TextButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("保存并退出"),
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
            children:[
              // 1. 基础信息
              BasicInfoTab(character: _editingChar),
              
              // 2. 技能与豁免
              ProficienciesTab(character: _editingChar),
              
              // 3. 冒险信息
              CombatTab(character: _editingChar),

              // 4. 人物设定
              CharacterSettingsTab(character: _editingChar),
              
              // 5. 施法信息
              SpellbookTab(character: _editingChar),
            ],
          ),
        ),
      ),
    );
  }
}