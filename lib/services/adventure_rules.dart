import 'dart:math';

enum DeathSaveOutcome { pending, stable, dead, regainedHitPoint }

class DeathSaveRollResult {
  final int successes;
  final int failures;
  final DeathSaveOutcome outcome;

  const DeathSaveRollResult({
    required this.successes,
    required this.failures,
    required this.outcome,
  });
}

class AdventureRules {
  const AdventureRules._();

  static int clampCurrentHitPoints(int value, int maximum) {
    return value.clamp(0, max(0, maximum));
  }

  static int clampTemporaryHitPoints(int value) => max(0, value);

  static bool shouldShowDeathSaves({
    required int currentHitPoints,
    required int maximumHitPoints,
  }) {
    return maximumHitPoints > 0 && currentHitPoints == 0;
  }

  static DeathSaveRollResult resolveDeathSave({
    required int roll,
    required int successes,
    required int failures,
  }) {
    if (roll < 1 || roll > 20) {
      throw RangeError.range(roll, 1, 20, 'roll');
    }

    var nextSuccesses = successes.clamp(0, 3);
    var nextFailures = failures.clamp(0, 3);

    if (roll == 20) {
      return const DeathSaveRollResult(
        successes: 0,
        failures: 0,
        outcome: DeathSaveOutcome.regainedHitPoint,
      );
    }

    if (roll == 1) {
      nextFailures = min(3, nextFailures + 2);
    } else if (roll >= 10) {
      nextSuccesses = min(3, nextSuccesses + 1);
    } else {
      nextFailures = min(3, nextFailures + 1);
    }

    final outcome = nextSuccesses >= 3
        ? DeathSaveOutcome.stable
        : nextFailures >= 3
        ? DeathSaveOutcome.dead
        : DeathSaveOutcome.pending;

    return DeathSaveRollResult(
      successes: nextSuccesses,
      failures: nextFailures,
      outcome: outcome,
    );
  }
}
