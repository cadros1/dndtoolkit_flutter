import 'dart:math';
import 'package:flutter/material.dart';
import '../models/character.dart';
import '../services/character_storage.dart';

class AdventurePage extends StatefulWidget {
  const AdventurePage({super.key});

  @override
  State<AdventurePage> createState() => _AdventurePageState();
}

class _AdventurePageState extends State<AdventurePage> {
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
    _loadData();
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

  /// 手动保存
  Future<void> _manualSave() async {
    if (_selectedChar != null) {
      // 收起键盘
      FocusManager.instance.primaryFocus?.unfocus();
      await _storage.saveCharacter(_selectedChar!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("角色状态已保存")),
        );
      }
    }
  }

  /// 自动保存 (用于修改HP/法术位等关键数值后静默保存)
  Future<void> _autoSave() async {
    if (_selectedChar != null) {
      await _storage.saveCharacter(_selectedChar!);
    }
  }

  int get _currentBaseBonus {
    if (_selectedChar == null) return 0;
    return _currentOption.calculateBonus(_selectedChar!);
  }

  @override
  Widget build(BuildContext context) {
    if (_characters.isEmpty) {
      return const Center(child: Text("请先在列表页创建角色"));
    }
    if (_selectedChar == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      // 避免键盘弹出时顶起布局，保持日志流式显示
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // 1. 顶部角色选择栏 + 保存按钮
          _buildTopBar(),

          // 2. 主内容滚动区域
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // --- A. 状态仪表盘 ---
                _buildStatusDashboard(),
                const Divider(height: 24),

                // --- B. 骰子控制面板 ---
                _buildRollControlPanel(),
                
                const Divider(height: 30, thickness: 2),

                // --- C. 检定日志 ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("检定日志", style: Theme.of(context).textTheme.titleMedium),
                    if (_logs.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text("清空"),
                        onPressed: () => setState(() => _logs.clear()),
                      )
                  ],
                ),
                const SizedBox(height: 8),
                if (_logs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text("暂无记录", style: TextStyle(color: Colors.grey))),
                  )
                else
                  // 显示日志列表
                  ..._logs.map((log) => _buildLogItem(log)),
                  
                // 底部留白
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
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
          IconButton.filled(
            onPressed: _manualSave,
            icon: const Icon(Icons.save),
            tooltip: "保存状态",
          ),
        ],
      ),
    );
  }

  // --- 状态仪表盘 ---
  Widget _buildStatusDashboard() {
    final c = _selectedChar!.combat;
    final b = _selectedChar!.spellbook;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行：生命值 & 生命骰
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
                  _autoSave();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 第二行：护甲, 先攻, 速度
        Row(
          children: [
            Expanded(child: _buildReadOnlyBox("护甲", "${c.armorClass}")),
            const SizedBox(width: 8),
            Expanded(
                child: _buildReadOnlyBox("先攻",
                    "${c.initiative >= 0 ? '+' : ''}${c.initiative}")),
            const SizedBox(width: 8),
            Expanded(child: _buildReadOnlyBox("速度", c.speed)),
          ],
        ),
        const SizedBox(height: 12),

        // 第三行：法术位
        const Text("法术位",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...b.allSpells
                .where((g) => g.level > 0 && g.level <= 9)
                .map((group) {
              return SizedBox(
                width: 70,
                child: _buildEditableSpellSlotBox(
                  level: group.level,
                  current: group.remainSlots,
                  max: group.totalSlots,
                  onChanged: (val) {
                    setState(() {
                      group.remainSlots = val;
                    });
                    _autoSave();
                  },
                ),
              );
            }),
          ],
        )
      ],
    );
  }

  // --- HP 区域 (含可视化生命条) ---
  Widget _buildHpSection(CombatStats c) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            const Text("生命值", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            // 数值输入
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  child: TextFormField(
                    initialValue: c.hitPointsCurrent.toString(),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(isDense: true, border: UnderlineInputBorder(), contentPadding: EdgeInsets.zero),
                    onChanged: (v) {
                      setState(() => c.hitPointsCurrent = int.tryParse(v) ?? 0);
                      _autoSave();
                    },
                  ),
                ),
                const Text(" / ", style: TextStyle(fontSize: 16)),
                Text("${c.hitPointsMax}", style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(width: 8),
                const Text("临时:", style: TextStyle(fontSize: 10, color: Colors.blue)),
                SizedBox(
                  width: 30,
                  child: TextFormField(
                    initialValue: c.hitPointsTemp.toString(),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(isDense: true, border: UnderlineInputBorder(), contentPadding: EdgeInsets.zero),
                    onChanged: (v) {
                      setState(() => c.hitPointsTemp = int.tryParse(v) ?? 0);
                      _autoSave();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 生命条
            _buildHpBar(c.hitPointsCurrent, c.hitPointsMax + c.hitPointsTemp, c.hitPointsTemp),
          ],
        ),
      ),
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

  // --- 法术位输入框 ---
  Widget _buildEditableSpellSlotBox({
    required int level,
    required int current,
    required int max,
    required Function(int) onChanged
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
        color: current == 0 ? Colors.red.shade50 : Colors.white,
      ),
      child: Column(
        children: [
          Text("$level环", style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                child: TextFormField(
                  key: ValueKey("spell_${level}_$current"),
                  initialValue: current.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
                    color: current == 0 ? Colors.red : Colors.black
                  ),
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                  onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
                ),
              ),
              const Text("/", style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text("$max", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  // --- 骰子控制面板 ---
  Widget _buildRollControlPanel() {
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
        SizedBox(
          width: double.infinity,
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