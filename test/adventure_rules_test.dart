import 'package:dndtoolkit_flutter/models/character.dart';
import 'package:dndtoolkit_flutter/services/adventure_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdventureRules HP limits', () {
    test('current HP stays between zero and maximum HP', () {
      expect(AdventureRules.clampCurrentHitPoints(-4, 12), 0);
      expect(AdventureRules.clampCurrentHitPoints(7, 12), 7);
      expect(AdventureRules.clampCurrentHitPoints(18, 12), 12);
      expect(AdventureRules.clampCurrentHitPoints(3, -2), 0);
    });

    test('temporary HP has only a lower bound', () {
      expect(AdventureRules.clampTemporaryHitPoints(-1), 0);
      expect(AdventureRules.clampTemporaryHitPoints(999), 999);
    });

    test('death saves show only for a configured character at zero HP', () {
      expect(
        AdventureRules.shouldShowDeathSaves(
          currentHitPoints: 0,
          maximumHitPoints: 12,
        ),
        isTrue,
      );
      expect(
        AdventureRules.shouldShowDeathSaves(
          currentHitPoints: 1,
          maximumHitPoints: 12,
        ),
        isFalse,
      );
      expect(
        AdventureRules.shouldShowDeathSaves(
          currentHitPoints: 0,
          maximumHitPoints: 0,
        ),
        isFalse,
      );
    });
  });

  group('AdventureRules death saves', () {
    test('rolls 2 through 9 add one failure', () {
      for (final roll in [2, 9]) {
        final result = AdventureRules.resolveDeathSave(
          roll: roll,
          successes: 1,
          failures: 0,
        );
        expect(result.successes, 1);
        expect(result.failures, 1);
        expect(result.outcome, DeathSaveOutcome.pending);
      }
    });

    test('rolls 10 through 19 add one success', () {
      for (final roll in [10, 19]) {
        final result = AdventureRules.resolveDeathSave(
          roll: roll,
          successes: 0,
          failures: 1,
        );
        expect(result.successes, 1);
        expect(result.failures, 1);
        expect(result.outcome, DeathSaveOutcome.pending);
      }
    });

    test('natural 1 adds two failures and caps at death', () {
      final first = AdventureRules.resolveDeathSave(
        roll: 1,
        successes: 1,
        failures: 0,
      );
      expect(first.failures, 2);
      expect(first.outcome, DeathSaveOutcome.pending);

      final terminal = AdventureRules.resolveDeathSave(
        roll: 1,
        successes: 1,
        failures: 2,
      );
      expect(terminal.failures, 3);
      expect(terminal.outcome, DeathSaveOutcome.dead);
    });

    test('third success stabilizes without removing failures', () {
      final result = AdventureRules.resolveDeathSave(
        roll: 10,
        successes: 2,
        failures: 2,
      );
      expect(result.successes, 3);
      expect(result.failures, 2);
      expect(result.outcome, DeathSaveOutcome.stable);
    });

    test('natural 20 clears progress and regains a hit point', () {
      final result = AdventureRules.resolveDeathSave(
        roll: 20,
        successes: 2,
        failures: 2,
      );
      expect(result.successes, 0);
      expect(result.failures, 0);
      expect(result.outcome, DeathSaveOutcome.regainedHitPoint);
    });

    test('rejects values outside a d20', () {
      expect(
        () =>
            AdventureRules.resolveDeathSave(roll: 0, successes: 0, failures: 0),
        throwsRangeError,
      );
      expect(
        () => AdventureRules.resolveDeathSave(
          roll: 21,
          successes: 0,
          failures: 0,
        ),
        throwsRangeError,
      );
    });

    test('existing death save fields keep their JSON round trip', () {
      final character = Character();
      character.combat
        ..deathSuccess1 = true
        ..deathSuccess2 = true
        ..deathFail1 = true;

      final restored = Character.fromJson(character.toJson());
      expect(restored.combat.deathSuccess1, isTrue);
      expect(restored.combat.deathSuccess2, isTrue);
      expect(restored.combat.deathSuccess3, isFalse);
      expect(restored.combat.deathFail1, isTrue);
    });
  });
}
