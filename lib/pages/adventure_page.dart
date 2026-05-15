import 'dart:math';
import 'package:flutter/material.dart';
import '../models/character.dart';
import '../services/character_storage.dart';
import '../widgets/currency_step_row.dart';

const _kDesktopBreakpoint = 600.0;

class AdventurePage extends StatefulWidget {
  const AdventurePage({super.key});

  @override
  State<AdventurePage> createState() => _AdventurePageState();
}

class _AdventurePageState extends State<AdventurePage> with WidgetsBindingObserver {
  final CharacterStorage _storage = CharacterStorage();
  List<Character> _characters = [];
  Character? _selectedChar;

  // --- 骰子控制状态 ---
  RollOption _currentOption = RollOption.free();
  int _extraBonus = 0;
  int _dieSize = 20;
  int _rollCount = 1;
  _AdvantageState _advantage = _AdvantageState.none;

  // --- 日志列表 ---
  final List<RollLog> _logs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 移除监听
    _autoSave(); // 在切换底部Tab离开页面时触发保存
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用退到后台、锁屏、或弹出系统级弹窗失去焦点时触发保存
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _autoSave();
    }
  }

  Future<void> _loadData() async {
    final list = await _storage.loadAllCharacters();
    if (!mounted) return;
    setState(() {
      _characters = list;
      if (_characters.isNotEmpty) {
        _selectedChar = _characters.first;
      } else {
        _selectedChar = null;
      }
      _currentOption = RollOption.free();
      _extraBonus = 0;
    });
  }

  /// 自动保存 (静默保存)
  Future<void> _autoSave() async {
    if (_selectedChar != null) {
      await _storage.saveCharacter(_selectedChar!);
    }
  }

  int get _currentBaseBonus {
    if (_selectedChar == null) return 0;
    return _currentOption.calculateBonus(_selectedChar!);
  }

  // --- 页面主体布局 ---
  @override
  Widget build(BuildContext context) {
    if (_characters.isEmpty) {
      return const Center(child: Text("请先在列表页创建角色"));
    }
    if (_selectedChar == null) {
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

  // ---- 移动端布局 ----
  Widget _buildMobileLayout() {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          _buildHeaderArea(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                const SizedBox(height: 12),
                _buildRollControlPanel(isDesktop: false),
                const Divider(height: 30, thickness: 2),
                _buildLogSection(),
                const SizedBox(height: 50),
              ],
            ),
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
          _buildHeaderArea(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 骰子面板：固定宽度，内部可滚动
                SizedBox(
                  width: 450,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
                    child: _buildRollControlPanel(isDesktop: true),
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                // 日志区：占据剩余宽度
                Expanded(child: _buildLogSection()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- 共享：头部区域 ----
  Widget _buildHeaderArea() {
    return Material(
      elevation: 4,
      child: Column(
        children: [
          _buildTopBar(),
          _buildBasicInfoCard(),
          _buildBottomSheetEntryChips(),
        ],
      ),
    );
  }

  // ---- 共享：检定日志区 ----
  Widget _buildLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("检定日志", style: Theme.of(context).textTheme.titleMedium),
            if (_logs.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text("清空"),
                onPressed: () => setState(() => _logs.clear()),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_logs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: Text("暂无记录", style: TextStyle(color: Colors.grey))),
          )
        else
          ..._logs.map((log) => _buildLogItem(log)),
      ],
    );
  }

  // --- 顶部栏 ---
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          const Icon(Icons.person, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Character>(
                value: _selectedChar,
                isExpanded: true,
                items: _characters.map((Character char) {
                  return DropdownMenuItem<Character>(
                    value: char,
                    child: Text(
                      char.profile.characterName.isEmpty
                          ? "未命名"
                          : "${char.profile.characterName}-${char.profile.race}-${char.profile.classAndLevel}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
                onChanged: (Character? newValue) {
                  if (newValue != null) {
                    _autoSave();
                    setState(() {
                      _selectedChar = newValue;
                      _currentOption = RollOption.free();
                      _extraBonus = 0;
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 基础信息卡片（固定区域，不随日志滚动） ---
  // 包含：HP（当前/临时/生命条）、生命骰、AC、先攻、速度
  Widget _buildBasicInfoCard() {
    final c = _selectedChar!.combat;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: _buildHpSection(c),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _buildEditableStatBox(
                    label: "生命骰",
                    currentStr: c.hitDiceCurrent,
                    maxStr: c.hitDiceTotal,
                    isStringMode: true,
                    onChangedStr: (currStr) {
                      c.hitDiceCurrent = currStr;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildReadOnlyBox("护甲等级（AC）", "${c.armorClass}")),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildReadOnlyBox("先攻加值",
                        "${c.initiative >= 0 ? '+' : ''}${c.initiative}")),
                const SizedBox(width: 8),
                Expanded(child: _buildReadOnlyBox("速度", c.speed)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- BottomSheet 入口 Chip 行 ---
  Widget _buildBottomSheetEntryChips() {
    final chips = Row(
      children: [
        ActionChip(
          avatar: const Icon(Icons.account_balance_wallet, size: 18),
          label: const Text("钱币"),
          onPressed: _showCurrencyBottomSheet,
        ),
        const SizedBox(width: 8),
        ActionChip(
          avatar: const Icon(Icons.auto_fix_high, size: 18),
          label: const Text("法术"),
          onPressed: _showSpellSlotBottomSheet,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 桌面端不需要横向滚动
        if (constraints.maxWidth >= _kDesktopBreakpoint) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: chips,
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: chips,
        );
      },
    );
  }

  // --- 法术 BottomSheet ---
  // 采用 Card + ExpansionTile 展示各环法术位消耗和已配置的法术（只读）
  void _showSpellSlotBottomSheet() {
    if (_selectedChar == null) return;
    final spellbook = _selectedChar!.spellbook;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            // ---- 内部辅助组件 ----

            Widget buildMiniBtn(IconData icon, VoidCallback onTap) {
              return InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 14),
                ),
              );
            }

            Widget buildSlotStepper(SpellLevelGroup group) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildMiniBtn(Icons.remove, () {
                    if (group.remainSlots > 0) {
                      setModalState(() => group.remainSlots--);
                      _autoSave();
                    }
                  }),
                  const SizedBox(width: 4),
                  Text(
                    '${group.remainSlots}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: group.remainSlots == 0 ? Colors.red : Theme.of(ctx).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    ' / ${group.totalSlots}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 4),
                  buildMiniBtn(Icons.add, () {
                    if (group.remainSlots < group.totalSlots) {
                      setModalState(() => group.remainSlots++);
                      _autoSave();
                    }
                  }),
                ],
              );
            }

            Widget buildReadOnlySpellRow(Spell spell) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      spell.isPrepared ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 18,
                      color: spell.isPrepared
                          ? Theme.of(ctx).colorScheme.primary
                          : Theme.of(ctx).colorScheme.outline,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        spell.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget buildSpellList(SpellLevelGroup group) {
              final namedSpells = group.spells.where((s) => s.name.trim().isNotEmpty).toList();

              if (namedSpells.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '未配置法术',
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.outline,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: namedSpells.map((spell) => buildReadOnlySpellRow(spell)).toList(),
                ),
              );
            }

            Widget buildSpellCard({
              required SpellLevelGroup group,
              required bool showSlotsEditor,
            }) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1,
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: group.level <= 1,
                  title: Row(
                    children: [
                      Text(
                        group.levelLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      if (showSlotsEditor) buildSlotStepper(group),
                    ],
                  ),
                  children: [buildSpellList(group)],
                ),
              );
            }

            // ---- 主体布局 ----
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('法术', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),

                    // 戏法 (level 0) — 不展示法术位编辑器
                    buildSpellCard(
                      group: spellbook.allSpells.firstWhere((g) => g.level == 0),
                      showSlotsEditor: false,
                    ),

                    // 1-9 环法术
                    ...spellbook.allSpells
                        .where((g) => g.level >= 1 && g.level <= 9)
                        .map((group) => buildSpellCard(
                              group: group,
                              showSlotsEditor: true,
                            )),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- HP 区域 (含可视化生命条) ---
  Widget _buildHpSection(CombatStats c) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            const Text("生命值 (HP)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // 1. 当前生命值控制行
            _buildHpStepperRow(
              label: "当前",
              value: c.hitPointsCurrent,
              color: (c.hitPointsCurrent < c.hitPointsMax / 4) ? Colors.red : Colors.green,
              suffixText: "/ ${c.hitPointsMax}", // 显示在数字后面的最大值
              onChanged: (val) {
                setState(() => c.hitPointsCurrent = val);
              },
            ),

            const SizedBox(height: 8),

            // 2. 临时生命值控制行
            _buildHpStepperRow(
              label: "临时",
              value: c.hitPointsTemp,
              color: Colors.blue,
              onChanged: (val) {
                setState(() => c.hitPointsTemp = val);
              },
            ),

            const SizedBox(height: 12),
            // 3. 生命条
            _buildHpBar(c.hitPointsCurrent, c.hitPointsMax + c.hitPointsTemp, c.hitPointsTemp),
          ],
        ),
      ),
    );
  }

  // 内部辅助方法：构建带按钮的 HP 行
  Widget _buildHpStepperRow({
    required String label,
    required int value,
    required Color color,
    required ValueChanged<int> onChanged,
    String? suffixText,
  }) {
    // 使用 Controller 确保按钮更新时输入框同步更新
    final controller = TextEditingController(text: value.toString());
    // 光标移到最后
    controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));

    return Row(
      children: [
        SizedBox(width: 32, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
        // 减号
        InkWell(
          onTap: () => onChanged(value - 1),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.remove, size: 20),
          ),
        ),
        
        // 输入框
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 45,
                child: TextField(
                  controller: controller,
                  key: ValueKey("hp_field_$label$value"), // 强制重绘以更新值
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                  onChanged: (v) {
                    final newVal = int.tryParse(v);
                    if (newVal != null) onChanged(newVal);
                  },
                ),
              ),
              if (suffixText != null)
                Flexible(
                  child: Text(
                    suffixText, 
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    overflow: TextOverflow.ellipsis, // 防止溢出
                  ),
                ),
            ],
          ),
        ),

        // 加号
        InkWell(
          onTap: () => onChanged(value + 1),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.add, size: 20),
          ),
        ),
      ],
    );
  }

  // --- 新版生命条实现 ---
  // 结构: |---当前(红/绿)---|---临时(蓝)---|---空白(灰)---|
  Widget _buildHpBar(int current, int maxHP, int temp) {
    if (maxHP <= 0) maxHP = 1;
    
    // 确保数值非负
    int safeCurrent = max(0, current);
    int safeTemp = max(0, temp);
    
    // 计算总容量：MaxHP 和 (Current + Temp) 中较大的那个
    // 这样当有大量临时生命时，条子会变长，或者以最大值为基准
    int totalCapacity = max(maxHP, safeCurrent + safeTemp);
    if (totalCapacity == 0) totalCapacity = 1;

    // 计算空白部分的 flex 值
    int emptySpace = totalCapacity - safeCurrent - safeTemp;
    if (emptySpace < 0) emptySpace = 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 12,
        color: Colors.grey.shade300, // 默认底色（即空白部分）
        child: Row(
          children: [
            // 1. 当前生命条
            if (safeCurrent > 0)
              Expanded(
                flex: safeCurrent,
                child: Container(
                  color: (safeCurrent < maxHP / 4) ? Colors.red : Colors.green,
                ),
              ),
            // 2. 临时生命条 (紧挨着当前生命)
            if (safeTemp > 0)
              Expanded(
                flex: safeTemp,
                child: Container(
                  color: Colors.blue,
                ),
              ),
            // 3. 空白部分 (代表损失的血量)
            // 使用 Expanded 占位，Flex 比例 = (Max - Curr - Temp)
            if (emptySpace > 0)
              Expanded(
                flex: emptySpace,
                child: Container(
                  color: Colors.transparent, // 透出底部的灰色
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- 骰子控制面板 ---
  Widget _buildRollControlPanel({bool isDesktop = false}) {
    final baseBonus = _currentBaseBonus;

    return Column(
      children: [
        // 检定类型
        InkWell(
          onTap: _showRollOptionSheet,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.primary),
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("检定类型", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      _currentOption.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_drop_down_circle_outlined),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 加值
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  const Text("基础加值", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text("${baseBonus >= 0 ? '+' : ''}$baseBonus",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            ),
            const Text("+", style: TextStyle(fontSize: 20, color: Colors.grey)),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  const Text("额外加值", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => setState(() => _extraBonus--),
                        icon: const Icon(Icons.remove),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          "${_extraBonus >= 0 ? '+' : ''}$_extraBonus",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => setState(() => _extraBonus++),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 设置
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            SegmentedButton<_AdvantageState>(
              segments: const [
                ButtonSegment(value: _AdvantageState.dis, label: Text("劣势")),
                ButtonSegment(value: _AdvantageState.none, label: Text("正常")),
                ButtonSegment(value: _AdvantageState.adv, label: Text("优势")),
              ],
              selected: {_advantage},
              onSelectionChanged: (Set<_AdvantageState> newSelection) {
                setState(() => _advantage = newSelection.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),

            DropdownButton<int>(
              value: _currentOption.isLockedD20 ? 20 : _dieSize,
              onChanged: _currentOption.isLockedD20
                  ? null
                  : (v) => setState(() => _dieSize = v!),
              items: [4, 6, 8, 10, 12, 20, 100]
                  .map((e) => DropdownMenuItem(value: e, child: Text("D$e")))
                  .toList(),
            ),

            DropdownButton<int>(
              value: _rollCount,
              onChanged: (v) => setState(() => _rollCount = v!),
              items: [1, 2, 3, 4, 5, 10]
                  .map((e) => DropdownMenuItem(value: e, child: Text("$e次")))
                  .toList(),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ROLL 按钮
        Center(
          child: SizedBox(
            width: isDesktop ? 300 : double.infinity,
            height: 60,
            child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: _performRoll,
            child: Text(
              "ROLL ( D${_currentOption.isLockedD20 ? 20 : _dieSize} )",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          ),
        ),
      ],
    );
  }

  // --- 执行检定 ---
  void _performRoll() {
    final random = Random();
    final actualDie = _currentOption.isLockedD20 ? 20 : _dieSize;
    final base = _currentBaseBonus;
    final totalMod = base + _extraBonus;

    for (int i = 0; i < _rollCount; i++) {
      int r1 = random.nextInt(actualDie) + 1;
      int r2 = random.nextInt(actualDie) + 1;

      int finalRollVal = r1;
      String detailStr = "$r1";

      if (_advantage == _AdvantageState.adv) {
        finalRollVal = max(r1, r2);
        detailStr = "优[$r1, $r2] -> $finalRollVal";
      } else if (_advantage == _AdvantageState.dis) {
        finalRollVal = min(r1, r2);
        detailStr = "劣[$r1, $r2] -> $finalRollVal";
      }

      int finalResult = finalRollVal + totalMod;
      String modStr = totalMod >= 0 ? "+$totalMod" : "$totalMod";

      final log = RollLog(
        title: _currentOption.name,
        result: finalResult,
        detail: "$detailStr (骰值) $modStr (加值) = $finalResult",
        isCrit: (actualDie == 20 && finalRollVal == 20),
        isFail: (actualDie == 20 && finalRollVal == 1),
      );

      setState(() {
        _logs.insert(0, log);
      });
    }
  }

  // --- 检定选择浮层 ---
  void _showRollOptionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return DefaultTabController(
            length: 4,
            child: Column(
              children: [
                const TabBar(
                  tabs: [Tab(text: "属性/豁免"), Tab(text: "技能"), Tab(text: "其它"), Tab(text: "自由")],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // 属性/豁免
                      ListView(
                        controller: scrollController,
                        children: [
                          _buildSectionHeader("属性检定"),
                          // 映射中文名
                          _buildOptionTile("力量检定", RollType.attrCheck, "str"),
                          _buildOptionTile("敏捷检定", RollType.attrCheck, "dex"),
                          _buildOptionTile("体质检定", RollType.attrCheck, "con"),
                          _buildOptionTile("智力检定", RollType.attrCheck, "int"),
                          _buildOptionTile("感知检定", RollType.attrCheck, "wis"),
                          _buildOptionTile("魅力检定", RollType.attrCheck, "cha"),
                          const Divider(),
                          _buildSectionHeader("豁免检定"),
                          _buildOptionTile("力量豁免", RollType.save, "str"),
                          _buildOptionTile("敏捷豁免", RollType.save, "dex"),
                          _buildOptionTile("体质豁免", RollType.save, "con"),
                          _buildOptionTile("智力豁免", RollType.save, "int"),
                          _buildOptionTile("感知豁免", RollType.save, "wis"),
                          _buildOptionTile("魅力豁免", RollType.save, "cha"),
                        ],
                      ),
                      // 技能
                      ListView(
                        controller: scrollController,
                        children: [
                          _buildSectionHeader("全部技能"),
                          _buildOptionTile("运动 (Athletics)", RollType.skill, "athletics"),
                          _buildOptionTile("体操 (Acrobatics)", RollType.skill, "acrobatics"),
                          _buildOptionTile("巧手 (Sleight of Hand)", RollType.skill, "sleightOfHand"),
                          _buildOptionTile("隐匿 (Stealth)", RollType.skill, "stealth"),
                          _buildOptionTile("奥秘 (Arcana)", RollType.skill, "arcana"),
                          _buildOptionTile("历史 (History)", RollType.skill, "history"),
                          _buildOptionTile("调查 (Investigation)", RollType.skill, "investigation"),
                          _buildOptionTile("自然 (Nature)", RollType.skill, "nature"),
                          _buildOptionTile("宗教 (Religion)", RollType.skill, "religion"),
                          _buildOptionTile("驯兽 (Animal Handling)", RollType.skill, "animalHandling"),
                          _buildOptionTile("洞悉 (Insight)", RollType.skill, "insight"),
                          _buildOptionTile("医药 (Medicine)", RollType.skill, "medicine"),
                          _buildOptionTile("察觉 (Perception)", RollType.skill, "perception"),
                          _buildOptionTile("求生 (Survival)", RollType.skill, "survival"),
                          _buildOptionTile("欺瞒 (Deception)", RollType.skill, "deception"),
                          _buildOptionTile("威吓 (Intimidation)", RollType.skill, "intimidation"),
                          _buildOptionTile("表演 (Performance)", RollType.skill, "performance"),
                          _buildOptionTile("游说 (Persuasion)", RollType.skill, "persuasion"),
                        ],
                      ),
                      // 其它
                      ListView(
                        controller: scrollController,
                        children: [
                          _buildOptionTile("先攻检定", RollType.initiative, ""),
                          _buildOptionTile("死亡豁免", RollType.deathSave, ""),
                          const Divider(),
                          _buildSectionHeader("武器命中检定"),
                          if (_selectedChar != null)
                            ..._selectedChar!.weapons.map((w) => ListTile(
                                  title: Text(w.name.isEmpty ? "未命名武器" : w.name),
                                  subtitle: Text(w.damage),
                                  trailing: Text(w.attackBonus >= 0 ? "+${w.attackBonus}" : "${w.attackBonus}"),
                                  onTap: () {
                                    setState(() {
                                      _currentOption = RollOption(name: "命中检定: ${w.name}", type: RollType.weapon, manualBonus: w.attackBonus);
                                    });
                                    Navigator.pop(context);
                                  },
                                )),
                        ],
                      ),
                      // 自由
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() => _currentOption = RollOption.free());
                            Navigator.pop(context);
                          },
                          child: const Text("选择自由检定"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCurrencyBottomSheet() {
    if (_selectedChar == null) return;
    final inv = _selectedChar!.inventory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允许弹窗高度根据内容自适应（避免被键盘挤压）
      useSafeArea: true,
      builder: (BuildContext context) {
        // 使用 StatefulBuilder，这样弹窗内部调用 setModalState 时，仅刷新弹窗UI，不刷新整个冒险页
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              // 关键：底部加上键盘的高度，使得键盘弹出时整个 BottomSheet 会被向上顶起
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // 高度收缩到内容实际高度
                  children:[
                    // 顶部标题和关闭按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children:[
                        const Text("钱币", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    
                    // 引入复用的 CurrencyStepRow 组件，五个货币项
                    CurrencyStepRow(
                      label: "CP",
                      value: inv.cP,
                      onChanged: (v) {
                        setModalState(() => inv.cP = v);
                        _autoSave(); // 静默保存
                      },
                    ),
                    const Divider(height: 8, thickness: 0.5),
                    CurrencyStepRow(
                      label: "SP",
                      value: inv.sP,
                      onChanged: (v) {
                        setModalState(() => inv.sP = v);
                        _autoSave();
                      },
                    ),
                    const Divider(height: 8, thickness: 0.5),
                    CurrencyStepRow(
                      label: "EP",
                      value: inv.eP,
                      onChanged: (v) {
                        setModalState(() => inv.eP = v);
                        _autoSave();
                      },
                    ),
                    const Divider(height: 8, thickness: 0.5),
                    CurrencyStepRow(
                      label: "GP",
                      value: inv.gP,
                      onChanged: (v) {
                        setModalState(() => inv.gP = v);
                        _autoSave();
                      },
                    ),
                    const Divider(height: 8, thickness: 0.5),
                    CurrencyStepRow(
                      label: "PP",
                      value: inv.pP,
                      onChanged: (v) {
                        setModalState(() => inv.pP = v);
                        _autoSave();
                      },
                    ),
                    const SizedBox(height: 24), // 底部留白
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.grey.withValues(alpha: 0.05),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildOptionTile(String title, RollType type, String key) {
    return ListTile(
      title: Text(title),
      onTap: () {
        setState(() {
          _currentOption = RollOption(name: title, type: type, key: key);
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildLogItem(RollLog log) {
    Color? color;
    if (log.isCrit) color = Colors.green.shade100;
    if (log.isFail) color = Colors.red.shade100;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color ?? Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(log.detail, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Text(
            "${log.result}",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableStatBox({
    required String label,
    String? currentStr,
    String? maxStr,
    bool isStringMode = false,
    Function(String curr)? onChangedStr,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 50,
                  child: TextFormField(
                    initialValue: currentStr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(isDense: true, border: UnderlineInputBorder(), contentPadding: EdgeInsets.zero),
                    onChanged: (v) => onChangedStr?.call(v),
                  ),
                ),
                const Text(" / ", style: TextStyle(fontSize: 16)),
                Text(maxStr ?? "", style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyBox(String label, String value) {
    return Card(
      color: Colors.grey.shade100,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10)),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// --- 辅助类 ---
enum _AdvantageState { none, adv, dis }

enum RollType {
  free,
  attrCheck,
  save,
  skill,
  initiative,
  deathSave,
  weapon,
}

class RollOption {
  final String name;
  final RollType type;
  final String key;
  final int manualBonus;

  RollOption(
      {required this.name,
      required this.type,
      this.key = "",
      this.manualBonus = 0});

  factory RollOption.free() => RollOption(name: "自由检定", type: RollType.free);
  bool get isLockedD20 => type != RollType.free;

  int calculateBonus(Character char) {
    final attr = char.attributes;
    final prof = char.proficiencies;
    final bonus = char.profile.proficiencyBonus;

    switch (type) {
      case RollType.free:
        return 0;
      case RollType.attrCheck:
        return _getMod(attr, key);
      case RollType.save:
        int base = _getMod(attr, key);
        bool hasProf = _getSaveProf(prof, key);
        return base + (hasProf ? bonus : 0);
      case RollType.skill:
        return _calcSkillBonus(char, key);
      case RollType.initiative:
        return char.combat.initiative;
      case RollType.deathSave:
        return 0;
      case RollType.weapon:
        return manualBonus;
    }
  }

  int _getMod(Attributes a, String k) {
    switch (k) {
      case 'str': return a.strengthMod;
      case 'dex': return a.dexterityMod;
      case 'con': return a.constitutionMod;
      case 'int': return a.intelligenceMod;
      case 'wis': return a.wisdomMod;
      case 'cha': return a.charismaMod;
      default: return 0;
    }
  }

  bool _getSaveProf(Proficiencies p, String k) {
    switch (k) {
      case 'str': return p.strengthSave;
      case 'dex': return p.dexteritySave;
      case 'con': return p.constitutionSave;
      case 'int': return p.intelligenceSave;
      case 'wis': return p.wisdomSave;
      case 'cha': return p.charismaSave;
      default: return false;
    }
  }

  int _calcSkillBonus(Character c, String k) {
    final a = c.attributes;
    final p = c.proficiencies;
    final b = c.profile.proficiencyBonus;
    int mod = 0;
    bool isProf = false;

    if (['athletics'].contains(k)) {
      mod = a.strengthMod;
    } else if (['acrobatics', 'sleightOfHand', 'stealth'].contains(k)) {
      mod = a.dexterityMod;
    } else if (['arcana', 'history', 'investigation', 'nature', 'religion'].contains(k)) {
      mod = a.intelligenceMod;
    } else if (['animalHandling', 'insight', 'medicine', 'perception', 'survival'].contains(k)) {
      mod = a.wisdomMod;
    } else if (['deception', 'intimidation', 'performance', 'persuasion'].contains(k)) {
      mod = a.charismaMod;
    }
    switch (k) {
      case 'athletics': isProf = p.athletics; break;
      case 'acrobatics': isProf = p.acrobatics; break;
      case 'sleightOfHand': isProf = p.sleightOfHand; break;
      case 'stealth': isProf = p.stealth; break;
      case 'arcana': isProf = p.arcana; break;
      case 'history': isProf = p.history; break;
      case 'investigation': isProf = p.investigation; break;
      case 'nature': isProf = p.nature; break;
      case 'religion': isProf = p.religion; break;
      case 'animalHandling': isProf = p.animalHandling; break;
      case 'insight': isProf = p.insight; break;
      case 'medicine': isProf = p.medicine; break;
      case 'perception': isProf = p.perception; break;
      case 'survival': isProf = p.survival; break;
      case 'deception': isProf = p.deception; break;
      case 'intimidation': isProf = p.intimidation; break;
      case 'performance': isProf = p.performance; break;
      case 'persuasion': isProf = p.persuasion; break;
    }
    return mod + (isProf ? b : 0);
  }
}

class RollLog {
  final String title;
  final int result;
  final String detail;
  final bool isCrit;
  final bool isFail;

  RollLog({
    required this.title,
    required this.result,
    required this.detail,
    this.isCrit = false,
    this.isFail = false,
  });
}