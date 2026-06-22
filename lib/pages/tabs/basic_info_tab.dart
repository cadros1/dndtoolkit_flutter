import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/character.dart';
import '../../widgets/app_ui.dart';

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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        const AppSectionTitle(
          title: "角色资料",
          subtitle: "跑团时最常扫读的身份信息",
          icon: Icons.badge_outlined,
        ),
        AppPanel(
          child: _buildResponsiveFields([
            _buildTextField(
              label: "角色姓名",
              initialValue: widget.character.profile.characterName,
              onChanged: (v) => widget.character.profile.characterName = v,
            ),
            _buildTextField(
              label: "玩家姓名",
              initialValue: widget.character.profile.playerName,
              onChanged: (v) => widget.character.profile.playerName = v,
            ),
            _buildTextField(
              label: "种族",
              initialValue: widget.character.profile.race,
              onChanged: (v) => widget.character.profile.race = v,
            ),
            _buildTextField(
              label: "职业与等级",
              initialValue: widget.character.profile.classAndLevel,
              onChanged: (v) => widget.character.profile.classAndLevel = v,
            ),
            _buildTextField(
              label: "背景",
              initialValue: widget.character.profile.background,
              onChanged: (v) => widget.character.profile.background = v,
            ),
            _buildTextField(
              label: "阵营",
              initialValue: widget.character.profile.alignment,
              onChanged: (v) => widget.character.profile.alignment = v,
            ),
          ]),
        ),
        const SizedBox(height: 18),
        const AppSectionTitle(title: "成长进度", icon: Icons.trending_up_outlined),
        AppPanel(
          child: _buildNumberField(
            label: "经验值 (XP)",
            initialValue: widget.character.profile.experiencePoints,
            onChanged: (v) => widget.character.profile.experiencePoints = v,
          ),
        ),
        const SizedBox(height: 18),
        const AppSectionTitle(
          title: "核心属性",
          subtitle: "数值与修正值会用于快捷检定",
          icon: Icons.casino_outlined,
        ),
        _buildAttributesGrid(),
      ],
    );
  }

  List<Widget> get _attributeWidgets => [
    AttributeStepper(
      label: "力量 (Str)",
      value: widget.character.attributes.strength,
      onChanged: (val) =>
          setState(() => widget.character.attributes.strength = val),
    ),
    AttributeStepper(
      label: "敏捷 (Dex)",
      value: widget.character.attributes.dexterity,
      onChanged: (val) =>
          setState(() => widget.character.attributes.dexterity = val),
    ),
    AttributeStepper(
      label: "体质 (Con)",
      value: widget.character.attributes.constitution,
      onChanged: (val) =>
          setState(() => widget.character.attributes.constitution = val),
    ),
    AttributeStepper(
      label: "智力 (Int)",
      value: widget.character.attributes.intelligence,
      onChanged: (val) =>
          setState(() => widget.character.attributes.intelligence = val),
    ),
    AttributeStepper(
      label: "感知 (Wis)",
      value: widget.character.attributes.wisdom,
      onChanged: (val) =>
          setState(() => widget.character.attributes.wisdom = val),
    ),
    AttributeStepper(
      label: "魅力 (Cha)",
      value: widget.character.attributes.charisma,
      onChanged: (val) =>
          setState(() => widget.character.attributes.charisma = val),
    ),
  ];

  Widget _buildAttributesGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 3
            : constraints.maxWidth >= 430
            ? 2
            : 1;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _attributeWidgets
              .map((w) => SizedBox(width: width, child: w))
              .toList(),
        );
      },
    );
  }

  Widget _buildResponsiveFields(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 2 : 1;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 12,
          children: fields
              .map((field) => SizedBox(width: width, child: field))
              .toList(),
        );
      },
    );
  }

  Widget _buildTextField({
    required String label,
    required String initialValue,
    required Function(String) onChanged,
  }) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(labelText: label),
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
      decoration: InputDecoration(labelText: label),
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStepButton(
                  icon: Icons.remove,
                  onTap: () {
                    if (value > 1) onChanged(value - 1);
                  },
                ),
                Text(
                  "$value",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                  ),
                ),
                _buildStepButton(
                  icon: Icons.add,
                  onTap: () {
                    if (value < 30) onChanged(value + 1);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                "修正值 $modStr",
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox.square(
      dimension: 44,
      child: IconButton.filledTonal(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
