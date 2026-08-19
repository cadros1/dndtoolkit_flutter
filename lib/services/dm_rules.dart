import 'dart:math';

enum DmAdvantageState { disadvantage, normal, advantage }

class DmRollResult {
  final int die;
  final int? secondDie;
  final int selectedDie;
  final int bonus;

  const DmRollResult({
    required this.die,
    required this.secondDie,
    required this.selectedDie,
    required this.bonus,
  });

  int get total => selectedDie + bonus;
}

class DmRules {
  const DmRules._();

  static DmRollResult resolveRoll({
    required int sides,
    required int firstDie,
    int? secondDie,
    required int bonus,
    required DmAdvantageState advantage,
  }) {
    if (sides < 2) throw RangeError.range(sides, 2, null, 'sides');
    if (firstDie < 1 || firstDie > sides) {
      throw RangeError.range(firstDie, 1, sides, 'firstDie');
    }
    if (advantage != DmAdvantageState.normal) {
      if (secondDie == null || secondDie < 1 || secondDie > sides) {
        throw RangeError.range(secondDie ?? 0, 1, sides, 'secondDie');
      }
    }

    final selected = switch (advantage) {
      DmAdvantageState.advantage => max(firstDie, secondDie!),
      DmAdvantageState.disadvantage => min(firstDie, secondDie!),
      DmAdvantageState.normal => firstDie,
    };
    return DmRollResult(
      die: firstDie,
      secondDie: secondDie,
      selectedDie: selected,
      bonus: bonus,
    );
  }
}
