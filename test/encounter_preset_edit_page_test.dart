import 'package:dndtoolkit_flutter/models/dm_models.dart';
import 'package:dndtoolkit_flutter/pages/dm/encounter_preset_edit_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'preset editor uses one integrated NPC and group lineup on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final card = NpcCard(name: '狼', maximumHitPoints: 11);
      final guard = NpcCard(name: '守卫', maximumHitPoints: 18);
      final group = EncounterPresetGroup(name: '狼群');
      final preset = EncounterPreset(
        name: '森林伏击',
        groups: [group],
        entries: [
          EncounterPresetEntry.fromCard(card, count: 2, groupId: group.id),
          EncounterPresetEntry.fromCard(guard, sortOrder: 1),
        ],
      );
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final resultFuture = navigator.push<EncounterPreset>(
        MaterialPageRoute(
          builder: (_) =>
              EncounterPresetEditPage(preset: preset, cards: [card, guard]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NPC 与集群编排'), findsOneWidget);
      expect(find.text('集群安排'), findsNothing);
      expect(find.text('NPC 编排'), findsNothing);
      expect(find.text('狼群 · 2 名'), findsOneWidget);
      expect(find.text('狼 · 2 名'), findsOneWidget);
      expect(find.text('守卫 · 1 名'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('狼 · 2 名'));
      await tester.pumpAndSettle();
      final secondName = find.byKey(
        ValueKey('name-${preset.entries.first.id}-1-2'),
      );
      await tester.ensureVisible(secondName);
      await tester.enterText(secondName, '断耳');
      await tester.tap(find.text('保存并退出'));
      await tester.pumpAndSettle();
      final result = await resultFuture;

      expect(result, isNotNull);
      expect(result!.name, '森林伏击');
      final wolfEntry = result.entries.firstWhere(
        (entry) => entry.sourceCardId == card.id,
      );
      expect(wolfEntry.count, 2);
      expect(wolfEntry.instanceNames.last, '断耳');
      expect(wolfEntry.groupId, result.groups.single.id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a group can add NPC directly from its own menu', (tester) async {
    final card = NpcCard(name: '守卫');
    final group = EncounterPresetGroup(name: '城门小队');
    final preset = EncounterPreset(name: '守门战', groups: [group]);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final resultFuture = navigator.push<EncounterPreset>(
      MaterialPageRoute(
        builder: (_) => EncounterPresetEditPage(preset: preset, cards: [card]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('集群操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, '添加 NPC'));
    await tester.pumpAndSettle();
    expect(find.text('添加 NPC 到「城门小队」'), findsOneWidget);
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.text('守卫 · 1 名'), findsOneWidget);
    await tester.tap(find.text('保存并退出'));
    await tester.pumpAndSettle();
    final result = await resultFuture;

    expect(result, isNotNull);
    expect(result!.entries, hasLength(1));
    expect(result.entries.single.groupId, result.groups.single.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('integrated lineup survives mobile and desktop resizing', (
    tester,
  ) async {
    final card = NpcCard(name: '骷髅');
    final group = EncounterPresetGroup(name: '墓穴守卫');
    final preset = EncounterPreset(
      name: '墓穴入口',
      groups: [group],
      entries: [
        EncounterPresetEntry.fromCard(card, count: 2, groupId: group.id),
      ],
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final size in const [
      Size(360, 640),
      Size(1100, 760),
      Size(390, 844),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          home: EncounterPresetEditPage(preset: preset, cards: [card]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('NPC 与集群编排'), findsOneWidget);
      expect(find.text('墓穴守卫 · 2 名'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('preset editor requires a name and at least one NPC', (
    tester,
  ) async {
    final card = NpcCard(name: '守卫');
    await tester.pumpWidget(
      MaterialApp(
        home: EncounterPresetEditPage(preset: EncounterPreset(), cards: [card]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存并退出'));
    await tester.pump();
    expect(find.text('请填写预设名称'), findsOneWidget);
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '守门战');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并退出'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('请至少添加一种 NPC'), findsOneWidget);
  });
}
