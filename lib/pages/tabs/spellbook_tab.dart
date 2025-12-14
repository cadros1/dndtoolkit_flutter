import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/character.dart';
import '../../widgets/step_input_card.dart';

class SpellbookTab extends StatefulWidget {
  final Character character;

  const SpellbookTab({super.key, required this.character});

  @override
  State<SpellbookTab> createState() => _SpellbookTabState();
}

class _SpellbookTabState extends State<SpellbookTab> {
  // 便捷访问器
  Spellbook get _book => widget.character.spellbook;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // --- 1. 顶部施法面板 ---
        _buildHeaderSection(),
        
        const Divider(height: 30),

        // --- 2. 法术列表 (0-9环) ---
        // 遍历 allSpells 列表
        ..._book.allSpells.map((group) {
          return _buildSpellLevelCard(group);
        }),

        const SizedBox(height: 50),
      ],
    );
  }

  /// 构建顶部施法基础信息
  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("施法能力"),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildTextField(
                label: "施法职业",
                initialValue: _book.spellcastingClass,
                onChanged: (v) => _book.spellcastingClass = v,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _buildTextField(
                label: "施法关键属性",
                initialValue: _book.spellcastingAbility,
                onChanged: (v) => _book.spellcastingAbility = v,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StepInputCard(
                label: "法术豁免难度",
                value: _book.spellSaveDC,
                onChanged: (v) => setState(() => _book.spellSaveDC = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StepInputCard(
                label: "法术攻击加值",
                value: _book.spellAttackBonus,
                onChanged: (v) => setState(() => _book.spellAttackBonus = v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建单层法术环位卡片
  Widget _buildSpellLevelCard(SpellLevelGroup group) {
    bool isCantrip = group.level == 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: group.level <= 1,
        
        // 我们将“总法术位”输入框放入 title 中
        title: Row(
          children: [
            // 左侧：标题 (如 1环法术)
            Text(
              group.levelLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            
            const Spacer(), // 撑开空间，把后面的推到右边

            // 右侧：法术位输入 (戏法不显示)
            if (!isCantrip) ...[
              const Text("总法术位: ", style: TextStyle(fontSize: 12, color: Colors.grey)),
              SizedBox(
                width: 40,
                // 这里使用 SizedBox 包裹输入框
                child: TextFormField(
                  initialValue: group.totalSlots.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    border: UnderlineInputBorder(), // 使用下划线更简洁
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => group.totalSlots = int.tryParse(v) ?? 0,
                ),
              ),
              const SizedBox(width: 8), // 给默认的展开箭头留点距离
            ]
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // 列表头
                if (group.spells.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        if (!isCantrip) 
                          const SizedBox(width: 30, child: Center(child: Text("准备", style: TextStyle(fontSize: 10, color: Colors.grey)))),
                        const SizedBox(width: 10),
                        const Expanded(child: Text("法术名称", style: TextStyle(fontSize: 12, color: Colors.grey))),
                      ],
                    ),
                  ),
                
                // 仅显示法术行，移除增删按钮
                ...List.generate(group.spells.length, (index) {
                  final spell = group.spells[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      children: [
                        // 1. 准备复选框 (戏法不显示)
                        if (!isCantrip)
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: Checkbox(
                              value: spell.isPrepared,
                              onChanged: (val) {
                                setState(() {
                                  spell.isPrepared = val ?? false;
                                });
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        
                        const SizedBox(width: 10),

                        // 2. 法术名称输入
                        Expanded(
                          child: TextFormField(
                            initialValue: spell.name,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              border: const UnderlineInputBorder(),
                              hintText: '法术名称${index + 1}',
                              hintStyle: const TextStyle(color: Colors.grey),
                            ),
                            onChanged: (v) => spell.name = v,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 辅助组件 ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String initialValue,
    required Function(String) onChanged,
    String? hint,
  }) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildBigNumberBox({
    required String label,
    required int value,
    required Function(int) onChanged,
    bool showPlusSign = false,
  }) {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextFormField(
              initialValue: value.toString(),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                prefixText: showPlusSign && value > 0 ? "+" : null, 
                contentPadding: EdgeInsets.zero,
              ),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))],
              onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}