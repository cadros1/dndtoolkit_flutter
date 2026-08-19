import 'package:dndtoolkit_flutter/services/dm_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DM generic dice', () {
    test('normal uses the first die and applies the total bonus', () {
      final result = DmRules.resolveRoll(
        sides: 20,
        firstDie: 12,
        bonus: 3,
        advantage: DmAdvantageState.normal,
      );

      expect(result.selectedDie, 12);
      expect(result.total, 15);
      expect(result.secondDie, isNull);
    });

    test('advantage chooses high and disadvantage chooses low', () {
      final advantage = DmRules.resolveRoll(
        sides: 8,
        firstDie: 2,
        secondDie: 7,
        bonus: -1,
        advantage: DmAdvantageState.advantage,
      );
      final disadvantage = DmRules.resolveRoll(
        sides: 8,
        firstDie: 2,
        secondDie: 7,
        bonus: 0,
        advantage: DmAdvantageState.disadvantage,
      );

      expect(advantage.selectedDie, 7);
      expect(advantage.total, 6);
      expect(disadvantage.selectedDie, 2);
    });

    test('rejects die results outside the selected sides', () {
      expect(
        () => DmRules.resolveRoll(
          sides: 6,
          firstDie: 7,
          bonus: 0,
          advantage: DmAdvantageState.normal,
        ),
        throwsRangeError,
      );
    });
  });
}
