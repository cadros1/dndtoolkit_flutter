import 'package:dndtoolkit_flutter/models/dm_models.dart';
import 'package:dndtoolkit_flutter/pages/dm/npc_card_edit_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NPC editor merges defenses and derives disabled modifiers', (
    tester,
  ) async {
    final data = DmData();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: NpcCardEditPage(
          card: NpcCard(),
          categories: data.sortedCategories,
        ),
      ),
    );
    await tester.tap(find.text('属性与信息').first);
    await tester.pumpAndSettle();

    expect(find.text('防御信息'), findsNothing);
    expect(find.widgetWithText(TextFormField, '伤害抗性'), findsOneWidget);
    final modifierFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((field) => field.decoration?.labelText == '调整值');
    expect(modifierFields, hasLength(6));
    expect(modifierFields.every((field) => field.enabled == false), isTrue);

    await tester.tap(find.byTooltip('力量加 1'));
    await tester.pump();
    await tester.tap(find.byTooltip('力量加 1'));
    await tester.pump();

    expect(find.text('+1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
