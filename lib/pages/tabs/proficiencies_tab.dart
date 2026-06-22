import 'package:flutter/material.dart';
import '../../models/character.dart';
import '../../widgets/step_input_card.dart';
import '../../widgets/app_ui.dart';

class ProficienciesTab extends StatefulWidget {
  final Character character;

  const ProficienciesTab({super.key, required this.character});

  @override
  State<ProficienciesTab> createState() => _ProficienciesTabState();
}

class _ProficienciesTabState extends State<ProficienciesTab> {
  // 方便访问的 getter
  Proficiencies get _pro => widget.character.proficiencies;
  Profile get _profile => widget.character.profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        const AppSectionTitle(
          title: "基础数值",
          subtitle: "影响豁免、技能和被动察觉",
          icon: Icons.calculate_outlined,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth >= 420;
            final cards = [
              StepInputCard(
                label: "熟练加值",
                value: _profile.proficiencyBonus,
                onChanged: (v) => setState(() => _profile.proficiencyBonus = v),
              ),
              StepInputCard(
                label: "被动察觉",
                value: _profile.passivePerception,
                onChanged: (v) =>
                    setState(() => _profile.passivePerception = v),
              ),
            ];
            if (!horizontal) {
              return Column(
                children: [cards[0], const SizedBox(height: 12), cards[1]],
              );
            }
            return Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const AppSectionTitle(title: "豁免熟练", icon: Icons.shield_outlined),
        AppPanel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final columns = constraints.maxWidth >= 260 ? 2 : 1;
              final itemWidth = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: 10,
                children: [
                  _buildCheckItem(
                    "力量豁免",
                    _pro.strengthSave,
                    (v) => _pro.strengthSave = v,
                    width: itemWidth,
                  ),
                  _buildCheckItem(
                    "智力豁免",
                    _pro.intelligenceSave,
                    (v) => _pro.intelligenceSave = v,
                    width: itemWidth,
                  ),
                  _buildCheckItem(
                    "敏捷豁免",
                    _pro.dexteritySave,
                    (v) => _pro.dexteritySave = v,
                    width: itemWidth,
                  ),
                  _buildCheckItem(
                    "感知豁免",
                    _pro.wisdomSave,
                    (v) => _pro.wisdomSave = v,
                    width: itemWidth,
                  ),
                  _buildCheckItem(
                    "体质豁免",
                    _pro.constitutionSave,
                    (v) => _pro.constitutionSave = v,
                    width: itemWidth,
                  ),
                  _buildCheckItem(
                    "魅力豁免",
                    _pro.charismaSave,
                    (v) => _pro.charismaSave = v,
                    width: itemWidth,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        const AppSectionTitle(
          title: "技能熟练",
          subtitle: "按关联属性分组",
          icon: Icons.fact_check_outlined,
        ),
        _buildSkillsGrid(),
        const SizedBox(height: 18),
        const AppSectionTitle(
          title: "其他熟练项 & 语言",
          icon: Icons.translate_outlined,
        ),
        AppPanel(
          child: TextFormField(
            initialValue: _pro.otherProficienciesAndLanguages,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: "工具熟练项、语言熟练项、武器熟练项……",
              alignLabelWithHint: true,
            ),
            onChanged: (v) => _pro.otherProficienciesAndLanguages = v,
          ),
        ),
      ],
    );
  }

  // 所有技能分组的数据定义
  List<_SkillGroupData> get _skillsData => [
    _SkillGroupData("力量 (Strength)", [
      _SkillBinder(
        "运动 (Athletics)",
        () => _pro.athletics,
        (v) => _pro.athletics = v,
      ),
    ]),
    _SkillGroupData("敏捷 (Dexterity)", [
      _SkillBinder(
        "体操 (Acrobatics)",
        () => _pro.acrobatics,
        (v) => _pro.acrobatics = v,
      ),
      _SkillBinder(
        "巧手 (Sleight of Hand)",
        () => _pro.sleightOfHand,
        (v) => _pro.sleightOfHand = v,
      ),
      _SkillBinder("隐匿 (Stealth)", () => _pro.stealth, (v) => _pro.stealth = v),
    ]),
    _SkillGroupData("智力 (Intelligence)", [
      _SkillBinder("奥秘 (Arcana)", () => _pro.arcana, (v) => _pro.arcana = v),
      _SkillBinder("历史 (History)", () => _pro.history, (v) => _pro.history = v),
      _SkillBinder(
        "调查 (Investigation)",
        () => _pro.investigation,
        (v) => _pro.investigation = v,
      ),
      _SkillBinder("自然 (Nature)", () => _pro.nature, (v) => _pro.nature = v),
      _SkillBinder(
        "宗教 (Religion)",
        () => _pro.religion,
        (v) => _pro.religion = v,
      ),
    ]),
    _SkillGroupData("感知 (Wisdom)", [
      _SkillBinder(
        "驯兽 (Animal Handling)",
        () => _pro.animalHandling,
        (v) => _pro.animalHandling = v,
      ),
      _SkillBinder("洞悉 (Insight)", () => _pro.insight, (v) => _pro.insight = v),
      _SkillBinder(
        "医药 (Medicine)",
        () => _pro.medicine,
        (v) => _pro.medicine = v,
      ),
      _SkillBinder(
        "察觉 (Perception)",
        () => _pro.perception,
        (v) => _pro.perception = v,
      ),
      _SkillBinder(
        "求生 (Survival)",
        () => _pro.survival,
        (v) => _pro.survival = v,
      ),
    ]),
    _SkillGroupData("魅力 (Charisma)", [
      _SkillBinder(
        "欺瞒 (Deception)",
        () => _pro.deception,
        (v) => _pro.deception = v,
      ),
      _SkillBinder(
        "威吓 (Intimidation)",
        () => _pro.intimidation,
        (v) => _pro.intimidation = v,
      ),
      _SkillBinder(
        "表演 (Performance)",
        () => _pro.performance,
        (v) => _pro.performance = v,
      ),
      _SkillBinder(
        "游说 (Persuasion)",
        () => _pro.persuasion,
        (v) => _pro.persuasion = v,
      ),
    ]),
  ];

  Widget _buildSkillGroupWidget(String groupName, List<_SkillBinder> skills) {
    return AppPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            groupName,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          ...skills.map(
            (skill) => CheckboxListTile(
              title: Text(skill.name),
              value: skill.getter(),
              dense: true,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setState(() => skill.setter(v ?? false)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 宽屏时用两列展示技能分组
        if (constraints.maxWidth >= 500) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: _skillsData
                      .sublist(0, 3)
                      .map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildSkillGroupWidget(d.name, d.skills),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: _skillsData
                      .sublist(3, 5)
                      .map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildSkillGroupWidget(d.name, d.skills),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          );
        }
        // 窄屏：垂直堆叠
        return Column(
          children: _skillsData
              .map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSkillGroupWidget(d.name, d.skills),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildCheckItem(
    String label,
    bool value,
    Function(bool) onChanged, {
    required double width,
  }) {
    final cs = Theme.of(context).colorScheme;
    final foreground = value ? cs.onPrimaryContainer : cs.onSurface;
    return SizedBox(
      width: width,
      height: 48,
      child: Semantics(
        button: true,
        selected: value,
        child: Material(
          color: value
              ? cs.primaryContainer.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.34
                      : 0.7,
                )
              : cs.surfaceContainerHighest.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.28
                      : 0.42,
                ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
              color: value
                  ? cs.primary.withValues(alpha: 0.34)
                  : cs.outlineVariant,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() => onChanged(!value)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    value ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                    color: value ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillGroupData {
  final String name;
  final List<_SkillBinder> skills;
  const _SkillGroupData(this.name, this.skills);
}

class _SkillBinder {
  final String name;
  final bool Function() getter;
  final Function(bool) setter;
  _SkillBinder(this.name, this.getter, this.setter);
}
