import 'package:flutter/material.dart';
import '../../models/character.dart';
import '../../widgets/step_input_card.dart';
import '../../widgets/currency_step_row.dart';
import '../../widgets/app_ui.dart';

class CombatTab extends StatefulWidget {
  final Character character;

  const CombatTab({super.key, required this.character});

  @override
  State<CombatTab> createState() => _CombatTabState();
}

class _CombatTabState extends State<CombatTab> {
  // 便捷访问器
  CombatStats get _combat => widget.character.combat;
  Inventory get _inv => widget.character.inventory;
  List<Weapon> get _weapons => widget.character.weapons;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        const AppSectionTitle(
          title: "战斗摘要",
          subtitle: "跑团中最常修改和查看的状态",
          icon: Icons.health_and_safety_outlined,
        ),
        _buildResponsiveGrid([
          StepInputCard(
            label: "护甲等级 (AC)",
            value: _combat.armorClass,
            onChanged: (v) => setState(() => _combat.armorClass = v),
          ),
          StepInputCard(
            label: "先攻加值",
            value: _combat.initiative,
            onChanged: (v) => setState(() => _combat.initiative = v),
          ),
          _buildTextCard(
            label: "速度",
            value: _combat.speed,
            onChanged: (v) => setState(() => _combat.speed = v),
          ),
          StepInputCard(
            label: "最大生命值",
            value: _combat.hitPointsMax,
            onChanged: (v) => setState(() => _combat.hitPointsMax = v),
          ),
        ]),
        const SizedBox(height: 12),
        AppPanel(
          child: TextFormField(
            initialValue: _combat.hitDiceTotal,
            decoration: const InputDecoration(labelText: "最大生命骰"),
            onChanged: (v) => _combat.hitDiceTotal = v,
          ),
        ),
        const SizedBox(height: 18),
        const AppSectionTitle(title: "武器攻击", icon: Icons.gps_fixed_outlined),
        ...List.generate(_weapons.length, (index) {
          return _buildWeaponCard(index, _weapons[index]);
        }),
        const SizedBox(height: 6),
        const AppSectionTitle(
          title: "其他攻击/法术备注",
          icon: Icons.edit_note_outlined,
        ),
        AppPanel(
          child: TextFormField(
            initialValue: _combat.attacksAndSpellcastingNotes,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: "",
              alignLabelWithHint: true,
            ),
            onChanged: (v) => _combat.attacksAndSpellcastingNotes = v,
          ),
        ),
        const SizedBox(height: 18),
        const AppSectionTitle(title: "装备", icon: Icons.backpack_outlined),
        AppPanel(
          child: TextFormField(
            initialValue: _inv.equipmentText,
            maxLines: 6,
            decoration: const InputDecoration(alignLabelWithHint: true),
            onChanged: (v) => _inv.equipmentText = v,
          ),
        ),
        const SizedBox(height: 18),
        const AppSectionTitle(
          title: "财富",
          icon: Icons.account_balance_wallet_outlined,
        ),
        _buildWealthCard(),
        const SizedBox(height: 18),
        const AppSectionTitle(title: "特殊能力", icon: Icons.auto_awesome_outlined),
        AppPanel(
          child: TextFormField(
            initialValue: _combat.ability,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: "",
              alignLabelWithHint: true,
            ),
            onChanged: (v) => _combat.ability = v,
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }

  Widget _buildTextCard({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return AppPanel(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8), // 稍微高一点以对齐步进器
            TextFormField(
              initialValue: value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onChanged,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildWealthCard() {
    final currencyItems = [
      CurrencyStepRow(
        label: "CP",
        value: _inv.cP,
        onChanged: (v) => setState(() => _inv.cP = v),
      ),
      CurrencyStepRow(
        label: "SP",
        value: _inv.sP,
        onChanged: (v) => setState(() => _inv.sP = v),
      ),
      CurrencyStepRow(
        label: "EP",
        value: _inv.eP,
        onChanged: (v) => setState(() => _inv.eP = v),
      ),
      CurrencyStepRow(
        label: "GP",
        value: _inv.gP,
        onChanged: (v) => setState(() => _inv.gP = v),
      ),
      CurrencyStepRow(
        label: "PP",
        value: _inv.pP,
        onChanged: (v) => setState(() => _inv.pP = v),
      ),
    ];

    return AppPanel(
      child: Padding(
        padding: EdgeInsets.zero,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 宽屏：用 Wrap 紧凑排列
            if (constraints.maxWidth >= 400) {
              return Wrap(spacing: 24, runSpacing: 4, children: currencyItems);
            }
            // 窄屏：垂直堆叠
            return Column(children: currencyItems);
          },
        ),
      ),
    );
  }

  Widget _buildWeaponCard(int index, Weapon weapon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.zero,
        child: AppPanel(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "武器 ${index + 1}",
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      initialValue: weapon.name,
                      decoration: const InputDecoration(labelText: "武器名称"),
                      onChanged: (v) => weapon.name = v,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: weapon.attackBonus == 0
                          ? ""
                          : weapon.attackBonus.toString(),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: "攻击加值"),
                      onChanged: (v) =>
                          weapon.attackBonus = int.tryParse(v) ?? 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: weapon.damage,
                decoration: const InputDecoration(labelText: "伤害类型"),
                onChanged: (v) => weapon.damage = v,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
