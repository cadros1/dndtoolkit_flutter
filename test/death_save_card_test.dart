import 'package:dndtoolkit_flutter/theme/app_theme.dart';
import 'package:dndtoolkit_flutter/widgets/death_save_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpInteractiveCard(
    WidgetTester tester, {
    int initialSuccesses = 0,
    int initialFailures = 0,
    int? initialLastRoll,
    ThemeData? theme,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    var successes = initialSuccesses;
    var failures = initialFailures;
    int? lastRoll = initialLastRoll;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return DeathSaveCard(
                    successes: successes,
                    failures: failures,
                    lastRoll: lastRoll,
                    isDesktop: false,
                    onRoll: () {},
                    onReset: () => setState(() {
                      successes = 0;
                      failures = 0;
                      lastRoll = null;
                    }),
                    onSuccessesChanged: (value) =>
                        setState(() => successes = value),
                    onFailuresChanged: (value) =>
                        setState(() => failures = value),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'manual progress fills in order and can back out terminal state',
    (tester) async {
      await pumpInteractiveCard(tester);

      await tester.tap(find.byKey(const ValueKey('death-save-成功-2')));
      await tester.pumpAndSettle();
      expect(find.text('成功 2/3'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('death-save-成功-3')));
      await tester.pumpAndSettle();
      expect(find.text('稳定'), findsOneWidget);
      final terminalButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('death-save-roll-button')),
      );
      expect(terminalButton.onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('death-save-成功-3')));
      await tester.pumpAndSettle();
      expect(find.text('成功 2/3'), findsOneWidget);
      final resumedButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('death-save-roll-button')),
      );
      expect(resumedButton.onPressed, isNotNull);
    },
  );

  testWidgets('failure progress fills from the outer visual circle inward', (
    tester,
  ) async {
    await pumpInteractiveCard(tester);

    final outerCircle = find.byKey(const ValueKey('death-save-失败-1'));
    final innerCircle = find.byKey(const ValueKey('death-save-失败-3'));
    expect(
      tester.getCenter(outerCircle).dx,
      greaterThan(tester.getCenter(innerCircle).dx),
    );

    await tester.tap(outerCircle);
    await tester.pumpAndSettle();
    expect(find.text('失败 1/3'), findsOneWidget);
    expect(find.bySemanticsLabel('死亡豁免失败第 1 次，已记录'), findsOneWidget);
  });

  testWidgets('reset clears progress and the latest result only', (
    tester,
  ) async {
    await pumpInteractiveCard(
      tester,
      initialSuccesses: 1,
      initialFailures: 2,
      initialLastRoll: 1,
    );

    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('death-save-reset-button')));
    await tester.pumpAndSettle();

    expect(find.text('成功 0/3'), findsOneWidget);
    expect(find.text('失败 0/3'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('three failures show death and lock further rolls', (
    tester,
  ) async {
    await pumpInteractiveCard(tester, initialSuccesses: 1, initialFailures: 3);

    expect(find.text('死亡'), findsOneWidget);
    final rollButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('death-save-roll-button')),
    );
    expect(rollButton.onPressed, isNull);
  });

  testWidgets('critical rolls have descriptive semantics', (tester) async {
    await pumpInteractiveCard(tester, initialLastRoll: 20);
    expect(find.bySemanticsLabel('死亡豁免骰面 20，自然 20'), findsOneWidget);

    await pumpInteractiveCard(tester, initialLastRoll: 1);
    expect(find.bySemanticsLabel('死亡豁免骰面 1，自然 1'), findsOneWidget);
  });

  testWidgets('common phone width keeps progress in the sketched first row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await pumpInteractiveCard(tester);

    final successY = tester
        .getCenter(find.byKey(const ValueKey('death-save-成功-1')))
        .dy;
    final outcomeY = tester
        .getCenter(find.byKey(const ValueKey('death-save-outcome')))
        .dy;
    final failureY = tester
        .getCenter(find.byKey(const ValueKey('death-save-失败-1')))
        .dy;
    expect((successY - outcomeY).abs(), lessThan(20));
    expect((failureY - outcomeY).abs(), lessThan(20));
  });

  testWidgets('small dark layout supports large text and touch targets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);

    await pumpInteractiveCard(
      tester,
      theme: AppTheme.dark(),
      textScaler: const TextScaler.linear(1.6),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('death-save-成功-1'))),
      const Size(44, 44),
    );
    expect(
      find.byKey(const ValueKey('death-save-roll-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('death-save-reset-button')),
      findsOneWidget,
    );
  });
}
