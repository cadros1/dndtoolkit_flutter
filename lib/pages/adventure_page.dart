import 'dart:math';
import 'package:flutter/material.dart';
import '../models/character.dart';
import '../services/character_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_step_row.dart';
import '../widgets/app_ui.dart';

class AdventurePage extends StatefulWidget {
  const AdventurePage({super.key});

  @override
  State<AdventurePage> createState() => _AdventurePageState();
}

class _AdventurePageState extends State<AdventurePage>
    with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
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
      return const AppEmptyState(
        icon: Icons.person_add_alt_1_outlined,
        title: "请先创建角色",
        message: "冒险操作台需要读取角色卡，创建角色后即可进行快捷检定和状态管理。",
      );
    }
    if (_selectedChar == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kAppDesktopBreakpoint) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }

  // ---- 移动端布局 ----
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeaderArea(isDesktop: false),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                children: [
                  _buildRollControlPanel(isDesktop: false),
                  const SizedBox(height: 10),
                  _buildLogSection(fill: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 桌面端布局 ----
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeaderArea(isDesktop: true),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 骰子面板：固定宽度，内部可滚动
                  SizedBox(
                    width: 470,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 12, 24),
                      child: _buildRollControlPanel(isDesktop: true),
                    ),
                  ),
                  VerticalDivider(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  // 日志区：占据剩余宽度
                  Expanded(child: _buildLogSection(fill: true)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 共享：头部区域 ----
  Widget _buildHeaderArea({required bool isDesktop}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 24 : 16,
        isDesktop ? 12 : 8,
        isDesktop ? 24 : 16,
        0,
      ),
      child: Column(
        children: [
          _buildTopBar(isDesktop: isDesktop),
          SizedBox(height: isDesktop ? 10 : 8),
          _buildBasicInfoCard(isDesktop: isDesktop),
        ],
      ),
    );
  }

  // ---- 共享：检定日志区 ----
  Widget _buildLogSection({required bool fill}) {
    final header = AppSectionTitle(
      title: "检定日志",
      subtitle: _logs.isEmpty ? "投骰结果会显示在这里" : "最近结果在最上方",
      icon: Icons.history_outlined,
      trailing: _logs.isEmpty
          ? null
          : TextButton.icon(
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text("清空"),
              onPressed: () => setState(() => _logs.clear()),
            ),
    );

    Widget emptyLog() {
      return AppPanel(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: Text(
              "暂无记录",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    if (fill) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            Expanded(
              child: _logs.isEmpty
                  ? Center(child: emptyLog())
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _logs.length,
                      itemBuilder: (context, index) =>
                          _buildLogItem(_logs[index]),
                    ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        if (_logs.isEmpty)
          emptyLog()
        else
          ..._logs.map((log) => _buildLogItem(log)),
      ],
    );
  }

  // --- 顶部栏 ---
  Widget _buildTopBar({required bool isDesktop}) {
    final cs = Theme.of(context).colorScheme;
    return AppPanel(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 16 : 12,
        isDesktop ? 14 : 8,
        isDesktop ? 16 : 12,
        isDesktop ? 14 : 8,
      ),
      child: Row(
        children: [
          Container(
            width: isDesktop ? 44 : 38,
            height: isDesktop ? 44 : 38,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(isDesktop ? 15 : 13),
            ),
            child: Icon(
              Icons.person_search_outlined,
              color: cs.primary,
              size: isDesktop ? 24 : 21,
            ),
          ),
          SizedBox(width: isDesktop ? 12 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "当前角色",
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<Character>(
                    value: _selectedChar,
                    isExpanded: true,
                    isDense: !isDesktop,
                    borderRadius: BorderRadius.circular(16),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                      fontSize: isDesktop ? null : 15,
                    ),
                    items: _characters.map((Character char) {
                      final name = char.profile.characterName.isEmpty
                          ? "未命名"
                          : char.profile.characterName;
                      final details = [
                        char.profile.race,
                        char.profile.classAndLevel,
                      ].where((v) => v.trim().isNotEmpty).join(" / ");
                      return DropdownMenuItem<Character>(
                        value: char,
                        child: Text(
                          details.isEmpty ? name : "$name  $details",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: isDesktop ? null : 15,
                          ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 基础信息卡片（固定区域，不随日志滚动） ---
  // 包含：HP（当前/临时/生命条）、生命骰、AC、先攻、速度
  Widget _buildBasicInfoCard({required bool isDesktop}) {
    final c = _selectedChar!.combat;
    final cs = Theme.of(context).colorScheme;

    return AppPanel(
      padding: EdgeInsets.all(isDesktop ? 14 : 9),
      shadowAlpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.12,
      shadowBlur: 30,
      shadowOffset: const Offset(0, 14),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = isDesktop
                    ? constraints.maxWidth >= 620
                    : constraints.maxWidth >= 380;
                final hp = _buildHpSection(c, compact: !isDesktop);
                final hitDice = _buildEditableStatBox(
                  label: "生命骰",
                  currentStr: c.hitDiceCurrent,
                  maxStr: c.hitDiceTotal,
                  compact: !isDesktop,
                  onChangedStr: (currStr) {
                    c.hitDiceCurrent = currStr;
                  },
                );
                if (!wide) {
                  return Column(
                    children: [
                      hp,
                      SizedBox(height: isDesktop ? 8 : 6),
                      hitDice,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: hp),
                    SizedBox(width: isDesktop ? 12 : 8),
                    Expanded(flex: 3, child: hitDice),
                  ],
                );
              },
            ),
            SizedBox(height: isDesktop ? 10 : 8),
            LayoutBuilder(
              builder: (context, constraints) {
                Widget statPill({
                  required IconData icon,
                  required String label,
                  required String value,
                  Color? color,
                }) {
                  if (isDesktop) {
                    return AppStatPill(
                      icon: icon,
                      label: label,
                      value: value,
                      color: color,
                    );
                  }
                  final accent = color ?? cs.primary;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.16
                            : 0.09,
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withValues(alpha: 0.22)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: accent),
                        const SizedBox(width: 4),
                        Text(
                          '$label ',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 11,
                            color: accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final stats = Wrap(
                  spacing: isDesktop ? 8 : 6,
                  runSpacing: isDesktop ? 8 : 6,
                  children: [
                    statPill(
                      icon: Icons.shield_outlined,
                      label: "AC",
                      value: "${c.armorClass}",
                    ),
                    statPill(
                      icon: Icons.bolt_outlined,
                      label: "先攻",
                      value: "${c.initiative >= 0 ? '+' : ''}${c.initiative}",
                      color: AppTheme.info,
                    ),
                    statPill(
                      icon: Icons.directions_run_outlined,
                      label: "速度",
                      value: c.speed,
                    ),
                  ],
                );

                if (isDesktop || constraints.maxWidth < 390) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      stats,
                      if (!isDesktop) ...[
                        const SizedBox(height: 6),
                        _buildBottomSheetEntryChips(isDesktop: isDesktop),
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: stats),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 142,
                      child: _buildBottomSheetEntryChips(isDesktop: isDesktop),
                    ),
                  ],
                );
              },
            ),
            if (isDesktop) ...[
              const SizedBox(height: 10),
              _buildBottomSheetEntryChips(isDesktop: isDesktop),
            ],
          ],
        ),
      ),
    );
  }

  // --- BottomSheet 入口 Chip 行 ---
  Widget _buildBottomSheetEntryChips({required bool isDesktop}) {
    final density = isDesktop
        ? VisualDensity.standard
        : const VisualDensity(horizontal: -2, vertical: -2);
    final chips = Row(
      children: [
        ActionChip.elevated(
          visualDensity: density,
          labelPadding: EdgeInsets.symmetric(horizontal: isDesktop ? 8 : 4),
          avatar: Icon(Icons.account_balance_wallet, size: isDesktop ? 18 : 16),
          label: const Text("钱币"),
          onPressed: _showCurrencyBottomSheet,
        ),
        SizedBox(width: isDesktop ? 8 : 6),
        ActionChip.elevated(
          visualDensity: density,
          labelPadding: EdgeInsets.symmetric(horizontal: isDesktop ? 8 : 4),
          avatar: Icon(Icons.auto_fix_high, size: isDesktop ? 18 : 16),
          label: const Text("法术"),
          onPressed: _showSpellSlotBottomSheet,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 桌面端不需要横向滚动
        if (isDesktop) {
          return Align(alignment: Alignment.centerLeft, child: chips);
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
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
              return SizedBox.square(
                dimension: 36,
                child: IconButton.filledTonal(
                  onPressed: onTap,
                  icon: Icon(icon, size: 16),
                  padding: EdgeInsets.zero,
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
                      color: group.remainSlots == 0
                          ? Colors.red
                          : Theme.of(ctx).colorScheme.onSurface,
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
                      spell.isPrepared
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
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
              final namedSpells = group.spells
                  .where((s) => s.name.trim().isNotEmpty)
                  .toList();

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
                  children: namedSpells
                      .map((spell) => buildReadOnlySpellRow(spell))
                      .toList(),
                ),
              );
            }

            Widget buildSpellCard({
              required SpellLevelGroup group,
              required bool showSlotsEditor,
            }) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppPanel(
                  padding: EdgeInsets.zero,
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
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.auto_fix_high,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '法术',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 戏法 (level 0) — 不展示法术位编辑器
                    buildSpellCard(
                      group: spellbook.allSpells.firstWhere(
                        (g) => g.level == 0,
                      ),
                      showSlotsEditor: false,
                    ),

                    // 1-9 环法术
                    ...spellbook.allSpells
                        .where((g) => g.level >= 1 && g.level <= 9)
                        .map(
                          (group) => buildSpellCard(
                            group: group,
                            showSlotsEditor: true,
                          ),
                        ),

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
  Widget _buildHpSection(CombatStats c, {bool compact = false}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.34,
        ),
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.favorite_outline, color: cs.primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  "生命值 (HP)",
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 6 : 12),

            // 1. 当前生命值控制行
            _buildHpStepperRow(
              label: "当前",
              value: c.hitPointsCurrent,
              color: (c.hitPointsCurrent < c.hitPointsMax / 4)
                  ? cs.error
                  : AppTheme.success,
              suffixText: "/ ${c.hitPointsMax}", // 显示在数字后面的最大值
              compact: compact,
              onChanged: (val) {
                setState(() => c.hitPointsCurrent = val);
              },
            ),

            SizedBox(height: compact ? 4 : 8),

            // 2. 临时生命值控制行
            _buildHpStepperRow(
              label: "临时",
              value: c.hitPointsTemp,
              color: AppTheme.info,
              compact: compact,
              onChanged: (val) {
                setState(() => c.hitPointsTemp = val);
              },
            ),

            SizedBox(height: compact ? 6 : 12),
            // 3. 生命条
            _buildHpBar(
              c.hitPointsCurrent,
              c.hitPointsMax + c.hitPointsTemp,
              c.hitPointsTemp,
              height: compact ? 8 : 12,
            ),
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
    bool compact = false,
  }) {
    return _HpStepperRow(
      label: label,
      value: value,
      color: color,
      suffixText: suffixText,
      compact: compact,
      onChanged: onChanged,
    );
  }

  // --- 新版生命条实现 ---
  // 结构: |---当前(红/绿)---|---临时(蓝)---|---空白(灰)---|
  Widget _buildHpBar(int current, int maxHP, int temp, {double height = 12}) {
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
        height: height,
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.7),
        child: Row(
          children: [
            // 1. 当前生命条
            if (safeCurrent > 0)
              Expanded(
                flex: safeCurrent,
                child: Container(
                  color: (safeCurrent < maxHP / 4)
                      ? Theme.of(context).colorScheme.error
                      : AppTheme.success,
                ),
              ),
            // 2. 临时生命条 (紧挨着当前生命)
            if (safeTemp > 0)
              Expanded(
                flex: safeTemp,
                child: Container(color: AppTheme.info),
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
    final cs = Theme.of(context).colorScheme;
    final dieLabel = "D${_currentOption.isLockedD20 ? 20 : _dieSize}";
    final compact = !isDesktop;

    Widget bonusBox(String label, String value, Color color) {
      return Expanded(
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 68 : 86),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.16
                  : 0.09,
            ),
            borderRadius: BorderRadius.circular(compact ? 14 : 16),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: compact ? 22 : 26,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget bonusStepButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
    }) {
      final size = compact ? 36.0 : 44.0;
      return SizedBox.square(
        dimension: size,
        child: IconButton.filledTonal(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: compact ? 16 : 18),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            fixedSize: Size.square(size),
            minimumSize: Size.square(size),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    Widget extraBonusBox() {
      return Expanded(
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 68 : 86),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: cs.primary.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.16
                  : 0.09,
            ),
            borderRadius: BorderRadius.circular(compact ? 14 : 16),
            border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "额外加值",
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: compact ? 4 : 6),
              Row(
                children: [
                  bonusStepButton(
                    icon: Icons.remove,
                    tooltip: "减少额外加值",
                    onPressed: () => setState(() => _extraBonus--),
                  ),
                  Expanded(
                    child: Text(
                      "${_extraBonus >= 0 ? '+' : ''}$_extraBonus",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: compact ? 21 : 24,
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  bonusStepButton(
                    icon: Icons.add,
                    tooltip: "增加额外加值",
                    onPressed: () => setState(() => _extraBonus++),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return AppPanel(
      padding: EdgeInsets.all(isDesktop ? 16 : 11),
      shadowAlpha: Theme.of(context).brightness == Brightness.dark
          ? 0.08
          : 0.03,
      shadowBlur: 12,
      shadowOffset: const Offset(0, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.casino_outlined, color: cs.primary, size: 20),
              const SizedBox(width: 6),
              Text(
                "快捷检定",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          InkWell(
            onTap: _showRollOptionSheet,
            borderRadius: BorderRadius.circular(compact ? 16 : 18),
            child: Container(
              padding: EdgeInsets.all(compact ? 10 : 14),
              decoration: BoxDecoration(
                border: Border.all(color: cs.primary.withValues(alpha: 0.45)),
                borderRadius: BorderRadius.circular(compact ? 16 : 18),
                color: cs.primaryContainer.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.18
                      : 0.42,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "检定类型",
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: compact ? 2 : 4),
                        Text(
                          _currentOption.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 17 : 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.expand_more, color: cs.primary),
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          Row(
            children: [
              bonusBox(
                "基础加值",
                "${baseBonus >= 0 ? '+' : ''}$baseBonus",
                cs.onSurfaceVariant,
              ),
              SizedBox(width: compact ? 8 : 10),
              extraBonusBox(),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          SegmentedButton<_AdvantageState>(
            style: ButtonStyle(
              visualDensity: compact
                  ? const VisualDensity(horizontal: -2, vertical: -2)
                  : VisualDensity.standard,
              tapTargetSize: compact
                  ? MaterialTapTargetSize.shrinkWrap
                  : MaterialTapTargetSize.padded,
            ),
            segments: const [
              ButtonSegment(
                value: _AdvantageState.dis,
                icon: Icon(Icons.south_west),
                label: Text("劣势"),
              ),
              ButtonSegment(
                value: _AdvantageState.none,
                icon: Icon(Icons.drag_handle),
                label: Text("正常"),
              ),
              ButtonSegment(
                value: _AdvantageState.adv,
                icon: Icon(Icons.north_east),
                label: Text("优势"),
              ),
            ],
            selected: {_advantage},
            onSelectionChanged: (Set<_AdvantageState> newSelection) {
              setState(() => _advantage = newSelection.first);
            },
          ),
          SizedBox(height: compact ? 10 : 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _currentOption.isLockedD20 ? 20 : _dieSize,
                  decoration: InputDecoration(
                    isDense: compact,
                    labelText: "骰面",
                    prefixIcon: const Icon(Icons.polyline_outlined),
                    prefixIconConstraints: compact
                        ? const BoxConstraints(minWidth: 36, minHeight: 36)
                        : null,
                    contentPadding: compact
                        ? const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          )
                        : null,
                  ),
                  onChanged: _currentOption.isLockedD20
                      ? null
                      : (v) => setState(() => _dieSize = v!),
                  items: [4, 6, 8, 10, 12, 20, 100]
                      .map(
                        (e) => DropdownMenuItem(value: e, child: Text("D$e")),
                      )
                      .toList(),
                ),
              ),
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _rollCount,
                  decoration: InputDecoration(
                    isDense: compact,
                    labelText: "次数",
                    prefixIcon: const Icon(Icons.repeat),
                    prefixIconConstraints: compact
                        ? const BoxConstraints(minWidth: 36, minHeight: 36)
                        : null,
                    contentPadding: compact
                        ? const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _rollCount = v!),
                  items: [1, 2, 3, 4, 5, 10]
                      .map(
                        (e) => DropdownMenuItem(value: e, child: Text("$e 次")),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 16),
          SizedBox(
            width: isDesktop ? 320 : double.infinity,
            height: compact ? 54 : 62,
            child: FilledButton.icon(
              onPressed: _performRoll,
              icon: const Icon(Icons.casino_outlined),
              label: Text(
                "ROLL ($dieLabel)",
                style: TextStyle(
                  fontSize: compact ? 20 : 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
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
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.rule_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "选择检定类型",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: "关闭",
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(icon: Icon(Icons.fitness_center), text: "属性/豁免"),
                    Tab(icon: Icon(Icons.fact_check_outlined), text: "技能"),
                    Tab(icon: Icon(Icons.gps_fixed_outlined), text: "其它"),
                    Tab(icon: Icon(Icons.casino_outlined), text: "自由"),
                  ],
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
                          _buildOptionTile(
                            "运动 (Athletics)",
                            RollType.skill,
                            "athletics",
                          ),
                          _buildOptionTile(
                            "体操 (Acrobatics)",
                            RollType.skill,
                            "acrobatics",
                          ),
                          _buildOptionTile(
                            "巧手 (Sleight of Hand)",
                            RollType.skill,
                            "sleightOfHand",
                          ),
                          _buildOptionTile(
                            "隐匿 (Stealth)",
                            RollType.skill,
                            "stealth",
                          ),
                          _buildOptionTile(
                            "奥秘 (Arcana)",
                            RollType.skill,
                            "arcana",
                          ),
                          _buildOptionTile(
                            "历史 (History)",
                            RollType.skill,
                            "history",
                          ),
                          _buildOptionTile(
                            "调查 (Investigation)",
                            RollType.skill,
                            "investigation",
                          ),
                          _buildOptionTile(
                            "自然 (Nature)",
                            RollType.skill,
                            "nature",
                          ),
                          _buildOptionTile(
                            "宗教 (Religion)",
                            RollType.skill,
                            "religion",
                          ),
                          _buildOptionTile(
                            "驯兽 (Animal Handling)",
                            RollType.skill,
                            "animalHandling",
                          ),
                          _buildOptionTile(
                            "洞悉 (Insight)",
                            RollType.skill,
                            "insight",
                          ),
                          _buildOptionTile(
                            "医药 (Medicine)",
                            RollType.skill,
                            "medicine",
                          ),
                          _buildOptionTile(
                            "察觉 (Perception)",
                            RollType.skill,
                            "perception",
                          ),
                          _buildOptionTile(
                            "求生 (Survival)",
                            RollType.skill,
                            "survival",
                          ),
                          _buildOptionTile(
                            "欺瞒 (Deception)",
                            RollType.skill,
                            "deception",
                          ),
                          _buildOptionTile(
                            "威吓 (Intimidation)",
                            RollType.skill,
                            "intimidation",
                          ),
                          _buildOptionTile(
                            "表演 (Performance)",
                            RollType.skill,
                            "performance",
                          ),
                          _buildOptionTile(
                            "游说 (Persuasion)",
                            RollType.skill,
                            "persuasion",
                          ),
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
                            ..._selectedChar!.weapons.map(
                              (w) => ListTile(
                                title: Text(w.name.isEmpty ? "未命名武器" : w.name),
                                subtitle: Text(w.damage),
                                trailing: Text(
                                  w.attackBonus >= 0
                                      ? "+${w.attackBonus}"
                                      : "${w.attackBonus}",
                                ),
                                onTap: () {
                                  setState(() {
                                    _currentOption = RollOption(
                                      name: "命中检定: ${w.name}",
                                      type: RollType.weapon,
                                      manualBonus: w.attackBonus,
                                    );
                                  });
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                        ],
                      ),
                      // 自由
                      Center(
                        child: FilledButton.icon(
                          onPressed: () {
                            setState(() => _currentOption = RollOption.free());
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.casino_outlined),
                          label: const Text("选择自由检定"),
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
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "钱币",
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 引入复用的 CurrencyStepRow 组件，五个货币项
                    AppPanel(
                      child: Column(
                        children: [
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
                        ],
                      ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildOptionTile(String title, RollType type, String key) {
    final selected =
        _currentOption.name == title &&
        _currentOption.type == type &&
        _currentOption.key == key;
    final cs = Theme.of(context).colorScheme;
    final icon = switch (type) {
      RollType.attrCheck => Icons.fitness_center,
      RollType.save => Icons.shield_outlined,
      RollType.skill => Icons.fact_check_outlined,
      RollType.initiative => Icons.bolt_outlined,
      RollType.deathSave => Icons.heart_broken_outlined,
      RollType.weapon => Icons.gps_fixed_outlined,
      RollType.free => Icons.casino_outlined,
    };
    return ListTile(
      leading: Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
      title: Text(title),
      selected: selected,
      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      trailing: selected ? Icon(Icons.check_circle, color: cs.primary) : null,
      onTap: () {
        setState(() {
          _currentOption = RollOption(name: title, type: type, key: key);
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildLogItem(RollLog log) {
    final cs = Theme.of(context).colorScheme;
    Color accent = cs.primary;
    if (log.isCrit) accent = AppTheme.success;
    if (log.isFail) accent = cs.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.07,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  log.detail,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            "${log.result}",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableStatBox({
    required String label,
    String? currentStr,
    String? maxStr,
    bool compact = false,
    Function(String curr)? onChangedStr,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.32 : 0.5,
        ),
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: cs.primary,
              ),
            ),
            SizedBox(height: compact ? 4 : 6),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: compact ? 36 : 40,
                    padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: TextFormField(
                      initialValue: currentStr,
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(
                        fontSize: compact ? 18 : 20,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) => onChangedStr?.call(v),
                    ),
                  ),
                ),
                if (maxStr != null) ...[
                  SizedBox(width: compact ? 6 : 8),
                  Text(
                    "/ $maxStr",
                    style: TextStyle(
                      fontSize: compact ? 12 : 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HpStepperRow extends StatefulWidget {
  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;
  final String? suffixText;
  final bool compact;

  const _HpStepperRow({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
    this.suffixText,
    this.compact = false,
  });

  @override
  State<_HpStepperRow> createState() => _HpStepperRowState();
}

class _HpStepperRowState extends State<_HpStepperRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant _HpStepperRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.value.toString();
    if (nextText != _controller.text) {
      _controller.text = nextText;
      _controller.selection = TextSelection.collapsed(offset: nextText.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChanged(String value) {
    final newVal = int.tryParse(value);
    if (newVal != null) widget.onChanged(newVal);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final buttonSize = widget.compact ? 36.0 : 42.0;
    final fieldHeight = widget.compact ? 36.0 : 42.0;
    final iconSize = widget.compact ? 16.0 : 18.0;

    Widget stepButton({
      required IconData icon,
      required VoidCallback onPressed,
    }) {
      return SizedBox.square(
        dimension: buttonSize,
        child: IconButton.filledTonal(
          onPressed: onPressed,
          icon: Icon(icon, size: iconSize),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            fixedSize: Size.square(buttonSize),
            minimumSize: Size.square(buttonSize),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: widget.compact ? 30 : 34,
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: widget.compact ? 12 : null,
              fontWeight: FontWeight.w800,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        stepButton(
          icon: Icons.remove,
          onPressed: () => widget.onChanged(widget.value - 1),
        ),
        Expanded(
          child: Container(
            height: fieldHeight,
            margin: EdgeInsets.symmetric(horizontal: widget.compact ? 5 : 8),
            padding: EdgeInsets.symmetric(horizontal: widget.compact ? 8 : 10),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(
                      fontSize: widget.compact ? 17 : 20,
                      fontWeight: FontWeight.bold,
                      color: widget.color,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: _handleTextChanged,
                  ),
                ),
                if (widget.suffixText != null) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      widget.suffixText!,
                      style: TextStyle(
                        fontSize: widget.compact ? 13 : 16,
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        stepButton(
          icon: Icons.add,
          onPressed: () => widget.onChanged(widget.value + 1),
        ),
      ],
    );
  }
}

// --- 辅助类 ---
enum _AdvantageState { none, adv, dis }

enum RollType { free, attrCheck, save, skill, initiative, deathSave, weapon }

class RollOption {
  final String name;
  final RollType type;
  final String key;
  final int manualBonus;

  RollOption({
    required this.name,
    required this.type,
    this.key = "",
    this.manualBonus = 0,
  });

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
      case 'str':
        return a.strengthMod;
      case 'dex':
        return a.dexterityMod;
      case 'con':
        return a.constitutionMod;
      case 'int':
        return a.intelligenceMod;
      case 'wis':
        return a.wisdomMod;
      case 'cha':
        return a.charismaMod;
      default:
        return 0;
    }
  }

  bool _getSaveProf(Proficiencies p, String k) {
    switch (k) {
      case 'str':
        return p.strengthSave;
      case 'dex':
        return p.dexteritySave;
      case 'con':
        return p.constitutionSave;
      case 'int':
        return p.intelligenceSave;
      case 'wis':
        return p.wisdomSave;
      case 'cha':
        return p.charismaSave;
      default:
        return false;
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
    } else if ([
      'arcana',
      'history',
      'investigation',
      'nature',
      'religion',
    ].contains(k)) {
      mod = a.intelligenceMod;
    } else if ([
      'animalHandling',
      'insight',
      'medicine',
      'perception',
      'survival',
    ].contains(k)) {
      mod = a.wisdomMod;
    } else if ([
      'deception',
      'intimidation',
      'performance',
      'persuasion',
    ].contains(k)) {
      mod = a.charismaMod;
    }
    switch (k) {
      case 'athletics':
        isProf = p.athletics;
        break;
      case 'acrobatics':
        isProf = p.acrobatics;
        break;
      case 'sleightOfHand':
        isProf = p.sleightOfHand;
        break;
      case 'stealth':
        isProf = p.stealth;
        break;
      case 'arcana':
        isProf = p.arcana;
        break;
      case 'history':
        isProf = p.history;
        break;
      case 'investigation':
        isProf = p.investigation;
        break;
      case 'nature':
        isProf = p.nature;
        break;
      case 'religion':
        isProf = p.religion;
        break;
      case 'animalHandling':
        isProf = p.animalHandling;
        break;
      case 'insight':
        isProf = p.insight;
        break;
      case 'medicine':
        isProf = p.medicine;
        break;
      case 'perception':
        isProf = p.perception;
        break;
      case 'survival':
        isProf = p.survival;
        break;
      case 'deception':
        isProf = p.deception;
        break;
      case 'intimidation':
        isProf = p.intimidation;
        break;
      case 'performance':
        isProf = p.performance;
        break;
      case 'persuasion':
        isProf = p.persuasion;
        break;
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
