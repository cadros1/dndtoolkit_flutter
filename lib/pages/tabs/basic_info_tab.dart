import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/character.dart';

class BasicInfoTab extends StatefulWidget {
  final Character character;

  const BasicInfoTab({super.key, required this.character});

  @override
  State<BasicInfoTab> createState() => _BasicInfoTabState();
}

class _BasicInfoTabState extends State<BasicInfoTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSectionTitle("角色资料"),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: "角色姓名",
                initialValue: widget.character.profile.characterName,
                onChanged: (v) => widget.character.profile.characterName = v,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextField(
                label: "玩家姓名",
                initialValue: widget.character.profile.playerName,
                onChanged: (v) => widget.character.profile.playerName = v,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: "种族",
                initialValue: widget.character.profile.race,
                onChanged: (v) => widget.character.profile.race = v,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextField(
                label: "职业与等级",
                initialValue: widget.character.profile.classAndLevel,
                onChanged: (v) => widget.character.profile.classAndLevel = v,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: "背景",
                initialValue: widget.character.profile.background,
                onChanged: (v) => widget.character.profile.background = v,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextField(
                label: "阵营",
                initialValue: widget.character.profile.alignment,
                onChanged: (v) => widget.character.profile.alignment = v,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildNumberField(
          label: "经验值 (XP)",
          initialValue: widget.character.profile.experiencePoints,
          onChanged: (v) => widget.character.profile.experiencePoints = v,
        ),
        const Divider(height: 30),
        _buildSectionTitle("核心属性"),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            AttributeStepper(
              label: "力量 (Str)",
              value: widget.character.attributes.strength,
              onChanged: (val) => setState(() => widget.character.attributes.strength = val),
            ),
            AttributeStepper(
              label: "智力 (Int)",
              value: widget.character.attributes.intelligence,
              onChanged: (val) => setState(() => widget.character.attributes.intelligence = val),
            ),
            AttributeStepper(
              label: "敏捷 (Dex)",
              value: widget.character.attributes.dexterity,
              onChanged: (val) => setState(() => widget.character.attributes.dexterity = val),
            ),
            AttributeStepper(
              label: "感知 (Wis)",
              value: widget.character.attributes.wisdom,
              onChanged: (val) => setState(() => widget.character.attributes.wisdom = val),
            ),
            AttributeStepper(
              label: "体质 (Con)",
              value: widget.character.attributes.constitution,
              onChanged: (val) => setState(() => widget.character.attributes.constitution = val),
            ),
            AttributeStepper(
              label: "魅力 (Cha)",
              value: widget.character.attributes.charisma,
              onChanged: (val) => setState(() => widget.character.attributes.charisma = val),
            ),
          ],
        ),
        const SizedBox(height: 50),
      ],
    );
  }

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
  }) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildNumberField({
    required String label,
    required int initialValue,
    required Function(int) onChanged,
  }) {
    return TextFormField(
      initialValue: initialValue.toString(),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) {
        onChanged(int.tryParse(v) ?? 0);
      },
    );
  }
}

class AttributeStepper extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const AttributeStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    int mod = ((value - 10) / 2).floor();
    String modStr = mod >= 0 ? "+$mod" : "$mod";
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStepButton(
                  icon: Icons.remove,
                  onTap: () { if (value > 1) onChanged(value - 1); },
                ),
                Text("$value", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                _buildStepButton(
                  icon: Icons.add,
                  onTap: () { if (value < 30) onChanged(value + 1); },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                "调整值: $modStr",
                style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.withOpacity(0.1)),
        child: Icon(icon, size: 20),
      ),
    );
  }
}