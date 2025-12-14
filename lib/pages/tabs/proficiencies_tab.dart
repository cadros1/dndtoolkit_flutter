import 'package:flutter/material.dart';
import '../../models/character.dart';
import '../../widgets/step_input_card.dart';

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
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSectionTitle("基础数值"),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StepInputCard(
                label: "熟练加值",
                value: _profile.proficiencyBonus,
                onChanged: (v) => setState(() => _profile.proficiencyBonus = v),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StepInputCard(
                label: "被动察觉",
                value: _profile.passivePerception,
                onChanged: (v) => setState(() => _profile.passivePerception = v),
              ),
            ),
          ],
        ),
        const Divider(height: 30),
        _buildSectionTitle("豁免熟练"),
        const SizedBox(height: 5),
        Wrap(
          spacing: 0,
          runSpacing: 0,
          children: [
            _buildCheckItem("力量豁免", _pro.strengthSave, (v) => _pro.strengthSave = v),
            _buildCheckItem("智力豁免", _pro.intelligenceSave, (v) => _pro.intelligenceSave = v),
            _buildCheckItem("敏捷豁免", _pro.dexteritySave, (v) => _pro.dexteritySave = v),
            _buildCheckItem("感知豁免", _pro.wisdomSave, (v) => _pro.wisdomSave = v),
            _buildCheckItem("体质豁免", _pro.constitutionSave, (v) => _pro.constitutionSave = v),
            _buildCheckItem("魅力豁免", _pro.charismaSave, (v) => _pro.charismaSave = v),
          ],
        ),
        const Divider(height: 30),
        _buildSectionTitle("技能熟练"),
        _buildSkillGroup("力量 (Strength)", [
          _SkillBinder("运动 (Athletics)", () => _pro.athletics, (v) => _pro.athletics = v),
        ]),
        _buildSkillGroup("敏捷 (Dexterity)", [
          _SkillBinder("体操 (Acrobatics)", () => _pro.acrobatics, (v) => _pro.acrobatics = v),
          _SkillBinder("巧手 (Sleight of Hand)", () => _pro.sleightOfHand, (v) => _pro.sleightOfHand = v),
          _SkillBinder("隐匿 (Stealth)", () => _pro.stealth, (v) => _pro.stealth = v),
        ]),
        _buildSkillGroup("智力 (Intelligence)", [
          _SkillBinder("奥秘 (Arcana)", () => _pro.arcana, (v) => _pro.arcana = v),
          _SkillBinder("历史 (History)", () => _pro.history, (v) => _pro.history = v),
          _SkillBinder("调查 (Investigation)", () => _pro.investigation, (v) => _pro.investigation = v),
          _SkillBinder("自然 (Nature)", () => _pro.nature, (v) => _pro.nature = v),
          _SkillBinder("宗教 (Religion)", () => _pro.religion, (v) => _pro.religion = v),
        ]),
        _buildSkillGroup("感知 (Wisdom)", [
          _SkillBinder("驯兽 (Animal Handling)", () => _pro.animalHandling, (v) => _pro.animalHandling = v),
          _SkillBinder("洞悉 (Insight)", () => _pro.insight, (v) => _pro.insight = v),
          _SkillBinder("医药 (Medicine)", () => _pro.medicine, (v) => _pro.medicine = v),
          _SkillBinder("察觉 (Perception)", () => _pro.perception, (v) => _pro.perception = v),
          _SkillBinder("求生 (Survival)", () => _pro.survival, (v) => _pro.survival = v),
        ]),
        _buildSkillGroup("魅力 (Charisma)", [
          _SkillBinder("欺瞒 (Deception)", () => _pro.deception, (v) => _pro.deception = v),
          _SkillBinder("威吓 (Intimidation)", () => _pro.intimidation, (v) => _pro.intimidation = v),
          _SkillBinder("表演 (Performance)", () => _pro.performance, (v) => _pro.performance = v),
          _SkillBinder("游说 (Persuasion)", () => _pro.persuasion, (v) => _pro.persuasion = v),
        ]),
        const Divider(height: 30),
        _buildSectionTitle("其他熟练项 & 语言"),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: _pro.otherProficienciesAndLanguages,
          maxLines: 5,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "工具熟练项、语言熟练项、武器熟练项……",
            alignLabelWithHint: true,
          ),
          onChanged: (v) => _pro.otherProficienciesAndLanguages = v,
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
    );
  }

  Widget _buildCheckItem(String label, bool value, Function(bool) onChanged) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 2 - 20,
      child: CheckboxListTile(
        title: Text(label, style: const TextStyle(fontSize: 14)),
        value: value,
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (v) => setState(() => onChanged(v ?? false)),
      ),
    );
  }

  Widget _buildSkillGroup(String groupName, List<_SkillBinder> skills) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ...skills.map((skill) => CheckboxListTile(
          title: Text(skill.name),
          value: skill.getter(),
          dense: true,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) => setState(() => skill.setter(v ?? false)),
        )),
      ],
    );
  }
}

class _SkillBinder {
  final String name;
  final bool Function() getter;
  final Function(bool) setter;
  _SkillBinder(this.name, this.getter, this.setter);
}