import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/character.dart';
import '../services/character_storage.dart';
import '../widgets/app_ui.dart';

import 'tabs/basic_info_tab.dart';
import 'tabs/proficiencies_tab.dart';
import 'tabs/combat_tab.dart';
import 'tabs/character_settings_tab.dart';
import 'tabs/spellbook_tab.dart';

/// 桌面端内容最大宽度
const _kDesktopContentMaxWidth = 880.0;

class CharacterEditPage extends StatefulWidget {
  final Character character;

  const CharacterEditPage({super.key, required this.character});

  @override
  State<CharacterEditPage> createState() => _CharacterEditPageState();
}

class _CharacterEditPageState extends State<CharacterEditPage> {
  final CharacterStorage _storage = CharacterStorage();
  late Character _editingChar;

  late String _initialJson;
  bool _forceExit = false;

  // 桌面端侧栏当前选中的 tab 索引
  int _desktopTabIndex = 0;

  // Tab 定义
  final List<_TabDef> _tabs = const [
    _TabDef("基础信息", "身份、属性与经验", Icons.person_outline),
    _TabDef("技能豁免", "熟练、豁免与技能", Icons.shield_outlined),
    _TabDef("冒险信息", "战斗、装备与财富", Icons.sports_kabaddi_outlined),
    _TabDef("人物设定", "形象、经历与特质", Icons.menu_book_outlined),
    _TabDef("施法信息", "法术能力与法术位", Icons.auto_fix_high),
  ];

  @override
  void initState() {
    super.initState();
    _editingChar = widget.character;
    _initialJson = jsonEncode(_editingChar.toJson());
  }

  bool _hasChanges() {
    return _initialJson != jsonEncode(_editingChar.toJson());
  }

  void _performExit([bool saved = false]) {
    setState(() => _forceExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, saved);
    });
  }

  Future<void> _saveAndExit() async {
    await _storage.saveCharacter(_editingChar);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('角色已保存')));
    _performExit(true);
  }

  Future<String?> _showExitDialog() {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("未保存的更改"),
        content: const Text("您修改了角色卡但尚未保存，直接退出将丢失本次编辑的内容。"),
        actions: [
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

  // ---- 构建指定 tab 的内容 Widget ----
  Widget _buildTabContent(int index) {
    return switch (index) {
      0 => BasicInfoTab(character: _editingChar),
      1 => ProficienciesTab(character: _editingChar),
      2 => CombatTab(character: _editingChar),
      3 => CharacterSettingsTab(character: _editingChar),
      4 => SpellbookTab(character: _editingChar),
      _ => BasicInfoTab(character: _editingChar),
    };
  }

  // ---- 移动端布局 ----
  Widget _buildMobileLayout() {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editingChar.profile.characterName.isEmpty
              ? "新建角色"
              : _editingChar.profile.characterName,
        ),
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs
              .map((t) => Tab(icon: Icon(t.icon), text: t.label))
              .toList(),
        ),
      ),
      body: TabBarView(
        children: List.generate(_tabs.length, (i) => _buildTabContent(i)),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: FilledButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: const Text("保存并退出"),
            onPressed: _saveAndExit,
          ),
        ),
      ),
    );
  }

  // ---- 桌面端布局 ----
  Widget _buildDesktopLayout() {
    final cs = Theme.of(context).colorScheme;
    final title = _editingChar.profile.characterName.isEmpty
        ? "新建角色"
        : _editingChar.profile.characterName;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text(
              '编辑角色卡信息',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text("保存并退出"),
            onPressed: _saveAndExit,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧导航面板
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(right: BorderSide(color: cs.outlineVariant)),
            ),
            child: SizedBox(
              width: 236,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  final selected = i == _desktopTabIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      minVerticalPadding: 10,
                      leading: Icon(
                        tab.icon,
                        color: selected ? cs.primary : cs.onSurfaceVariant,
                      ),
                      title: Text(
                        tab.label,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: selected ? cs.primary : cs.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        tab.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: selected,
                      selectedTileColor: cs.primaryContainer.withValues(
                        alpha: 0.55,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onTap: () => setState(() => _desktopTabIndex = i),
                    ),
                  );
                }),
              ),
            ),
          ),
          // 右侧内容区（各 tab 内已有 ListView，无需外层再包 ScrollView）
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _kDesktopContentMaxWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildTabContent(_desktopTabIndex),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _forceExit,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!_hasChanges()) {
          _performExit();
          return;
        }
        final String? action = await _showExitDialog();
        if (action == 'save') {
          await _saveAndExit();
        } else if (action == 'discard') {
          _performExit();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= kAppDesktopBreakpoint) {
            return _buildDesktopLayout();
          }
          return DefaultTabController(
            length: _tabs.length,
            child: _buildMobileLayout(),
          );
        },
      ),
    );
  }
}

/// 侧栏导航定义
class _TabDef {
  final String label;
  final String subtitle;
  final IconData icon;
  const _TabDef(this.label, this.subtitle, this.icon);
}
