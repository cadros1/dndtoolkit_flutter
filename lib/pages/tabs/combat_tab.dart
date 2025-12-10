import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/character.dart';

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
      padding: const EdgeInsets.all(16.0),
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildBigStatBox(
                label: "护甲等级(AC)",
                value: _combat.armorClass,
                onChanged: (v) => _combat.armorClass = v,
                icon: Icons.shield_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBigStatBox(
                label: "先攻加值",
                value: _combat.initiative,
                onChanged: (v) => _combat.initiative = v,
                icon: Icons.flash_on,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextBox(
                label: "速度",
                initialValue: _combat.speed,
                onChanged: (v) => _combat.speed = v,
                icon: Icons.directions_run,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildNumberField(
                label: "最大生命值",
                value: _combat.hitPointsMax,
                onChanged: (v) => _combat.hitPointsMax = v,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: TextFormField(
                initialValue: _combat.hitDiceTotal,
                decoration: const InputDecoration(
                  labelText: "最大生命骰",
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => _combat.hitDiceTotal = v,
              ),
            ),
          ],
        ),
        const Divider(height: 40),
        _buildSectionTitle("武器攻击"),
        const SizedBox(height: 10),
        ...List.generate(_weapons.length, (index) {
          return _buildWeaponCard(index, _weapons[index]);
        }),
        _buildSectionTitle("其他攻击/法术备注"),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _combat.attacksAndSpellcastingNotes,
          maxLines: 4,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "",
            alignLabelWithHint: true,
          ),
          onChanged: (v) => _combat.attacksAndSpellcastingNotes = v,
        ),
        const SizedBox(height: 24),
        _buildSectionTitle("装备"),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _inv.equipmentText,
          maxLines: 6, // 稍微大一点的框
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            alignLabelWithHint: true, // 让Label在多行模式下位于顶部
          ),
          onChanged: (v) => _inv.equipmentText = v,
        ),

        const SizedBox(height: 24),
        const Divider(height: 30),
        _buildSectionTitle("特殊能力"),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _combat.ability,
          maxLines: 6,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "",
            alignLabelWithHint: true,
          ),
          onChanged: (v) => _combat.ability = v,
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

  Widget _buildBigStatBox({
    required String label,
    required int value,
    required Function(int) onChanged,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, color: Colors.grey),
            const SizedBox(height: 4),
            TextFormField(
              initialValue: value.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
              onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBox({
    required String label,
    required String initialValue,
    required Function(String) onChanged,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, color: Colors.grey),
            const SizedBox(height: 4),
            TextFormField(
              initialValue: initialValue,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onChanged,
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({required String label, required int value, required Function(int) onChanged}) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
    );
  }

  Widget _buildWeaponCard(int index, Weapon weapon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("武器 ${index + 1}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: weapon.name,
                    decoration: const InputDecoration(labelText: "武器名称", isDense: true, border: UnderlineInputBorder()),
                    onChanged: (v) => weapon.name = v,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: weapon.attackBonus == 0 ? "" : weapon.attackBonus.toString(),
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    decoration: const InputDecoration(labelText: "攻击加值", isDense: true, border: UnderlineInputBorder()),
                    onChanged: (v) => weapon.attackBonus = int.tryParse(v) ?? 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: weapon.damage,
              decoration: const InputDecoration(labelText: "伤害类型", isDense: true, border: UnderlineInputBorder()),
              onChanged: (v) => weapon.damage = v,
            ),
          ],
        ),
      ),
    );
  }
}