import 'dart:io';

import 'package:dndtoolkit_flutter/models/dm_models.dart';
import 'package:dndtoolkit_flutter/pages/dm/dm_page.dart';
import 'package:dndtoolkit_flutter/services/dm_storage.dart';
import 'package:dndtoolkit_flutter/services/npc_markdown_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DM page exposes NPC library and current encounter sections', (
    tester,
  ) async {
    final storage = _MemoryDmStorage();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });

    await tester.pumpWidget(MaterialApp(home: DmPage(storage: storage)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('NPC 库'), findsOneWidget);
    expect(find.text('遭遇预设'), findsOneWidget);
    expect(find.text('当前遭遇'), findsOneWidget);
    expect(find.text('DM'), findsNothing);
    expect(tester.getTopLeft(find.text('NPC 库')).dy, greaterThanOrEqualTo(44));
    expect(find.text('还没有 NPC 卡'), findsOneWidget);
    expect(find.text('新建 NPC'), findsOneWidget);

    await tester.tap(find.text('当前遭遇'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('当前遭遇为空'), findsOneWidget);
    expect(find.text('添加 NPC'), findsWidgets);
    expect(find.text('创建集群'), findsOneWidget);
    expect(find.text('掷骰'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('DM library stays usable on a small Android viewport', (
    tester,
  ) async {
    final data = DmData(
      cards: [
        NpcCard(
          name: '有较长名称的城镇守卫队长',
          sizeAndType: '中型类人生物',
          maximumHitPoints: 27,
          armorClass: 16,
          speed: '30 尺，攀爬 20 尺',
          challengeRating: '1/2',
        ),
      ],
    );
    final storage = _MemoryDmStorage(initial: data);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(home: DmPage(storage: storage)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('有较长名称的城镇守卫队长'), findsOneWidget);
    expect(find.text('加入遭遇'), findsNothing);
    expect(find.text('HP'), findsNothing);
    expect(find.text('AC'), findsNothing);
    expect(find.textContaining('速度'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'current encounter uses the wide master-detail layout without overflow',
    (tester) async {
      final data = DmData();
      final card = NpcCard(
        name: '地精',
        sizeAndType: '小型类人生物',
        maximumHitPoints: 7,
        armorClass: 15,
      );
      data.cards.add(card);
      final instances = data.addInstances(card, ['地精 1', '地精 2', '地精 3']);
      instances.first.initiative = 14;
      final group = EncounterGroup(name: '地精小队', initiative: 12);
      data.encounter.groups.add(group);
      data.assignInstancesToGroup(
        instances.skip(1).map((instance) => instance.id),
        group.id,
      );
      final storage = _MemoryDmStorage(initial: data);
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(home: DmPage(storage: storage)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('当前遭遇'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('地精小队'), findsOneWidget);
      expect(find.text('选择一个 NPC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('group initiative can be set from the initiative target', (
    tester,
  ) async {
    final data = DmData();
    final group = EncounterGroup(name: '狼群');
    data.encounter.groups.add(group);
    final storage = _MemoryDmStorage(initial: data);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(home: DmPage(storage: storage)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('当前遭遇'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('—'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '17');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(group.initiative, 17);
    expect(find.text('17'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NPCs added from a group menu join that group directly', (
    tester,
  ) async {
    final data = DmData(cards: [NpcCard(name: '狼', maximumHitPoints: 11)]);
    final group = EncounterGroup(name: '狼群');
    data.encounter.groups.add(group);
    final storage = _MemoryDmStorage(initial: data);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(home: DmPage(storage: storage)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('当前遭遇'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('集群操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, '添加 NPC'));
    await tester.pumpAndSettle();
    expect(find.text('添加 NPC 到「狼群」'), findsOneWidget);

    await tester.tap(find.text('加入遭遇'));
    await tester.pumpAndSettle();

    expect(data.encounter.instances, hasLength(1));
    expect(data.encounter.instances.single.groupId, group.id);
    expect(find.text('狼 · AC 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DM page survives repeated responsive reconstruction', (
    tester,
  ) async {
    final storage = _MemoryDmStorage();
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Widget app() => MaterialApp(
      home: LayoutBuilder(
        builder: (context, constraints) => KeyedSubtree(
          key: ValueKey(constraints.maxWidth >= 720),
          child: DmPage(storage: storage),
        ),
      ),
    );

    tester.view.physicalSize = const Size(700, 700);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(900, 700);
    await tester.pump();
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(700, 700);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('无法读取 DM 数据'), findsNothing);
    expect(find.text('NPC 库'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Markdown import creates new cards and a missing category', (
    tester,
  ) async {
    final existing = NpcCard(name: '同名守卫', maximumHitPoints: 10);
    final data = DmData(cards: [existing]);
    final storage = _MemoryDmStorage(initial: data);
    final importResult = NpcMarkdownCodec.parse(
      'guard.md',
      NpcMarkdownCodec.exportCard(
        NpcCard(name: '同名守卫', maximumHitPoints: 22, armorClass: 16),
        categoryName: '城镇',
      ),
    );
    final markdownService = _FakeMarkdownService([importResult]);
    tester.view.physicalSize = const Size(1100, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: DmPage(storage: storage, markdownService: markdownService),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入所选 1 张'));
    await tester.pumpAndSettle();

    expect(data.cards, hasLength(2));
    expect(data.cards.map((card) => card.name), everyElement('同名守卫'));
    expect(data.cards.last.id, isNot(existing.id));
    expect(data.cards.last.maximumHitPoints, 22);
    final town = data.categories.singleWhere(
      (category) => category.name == '城镇',
    );
    expect(data.cards.last.categoryId, town.id);
    expect(find.text('已导入 1 张 NPC 卡'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a preset creates a fresh current encounter and replaces only after confirmation',
    (tester) async {
      final oldCard = NpcCard(name: '旧守卫', maximumHitPoints: 20);
      final newCard = NpcCard(name: '狼', maximumHitPoints: 11);
      final data = DmData(cards: [oldCard, newCard]);
      data.addInstances(oldCard, ['受伤守卫']).single.setCurrentHitPoints(3);
      data.presets.add(
        EncounterPreset(
          name: '狼群突袭',
          entries: [EncounterPresetEntry.fromCard(newCard, count: 2)],
        ),
      );
      final storage = _MemoryDmStorage(initial: data);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(home: DmPage(storage: storage)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('遭遇预设'));
      await tester.pumpAndSettle();
      expect(find.text('狼群突袭'), findsOneWidget);

      await tester.tap(find.text('创建当前遭遇'));
      await tester.pumpAndSettle();
      expect(find.text('替换当前遭遇'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(data.encounter.instances.single.displayName, '受伤守卫');
      expect(data.encounter.instances.single.currentHitPoints, 3);

      await tester.tap(find.text('创建当前遭遇'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('替换并创建'));
      await tester.pumpAndSettle();

      expect(data.encounter.instances, hasLength(2));
      expect(
        data.encounter.instances.map((instance) => instance.currentHitPoints),
        everyElement(11),
      );
      expect(find.text('掷骰'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('current encounter can be extracted and saved as a preset', (
    tester,
  ) async {
    final card = NpcCard(name: '骷髅', maximumHitPoints: 13);
    final data = DmData(cards: [card]);
    data.addInstances(card, ['左侧骷髅', '右侧骷髅']);
    final storage = _MemoryDmStorage(initial: data);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(home: DmPage(storage: storage)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('当前遭遇'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, '保存为遭遇预设'));
    await tester.pumpAndSettle();
    expect(find.text('当前遭遇预设'), findsWidgets);

    await tester.tap(find.text('保存并退出'));
    await tester.pumpAndSettle();

    expect(data.presets, hasLength(1));
    expect(data.presets.single.instanceCount, 2);
    expect(data.presets.single.entries.single.instanceNames, ['左侧骷髅', '右侧骷髅']);
    expect(find.text('遭遇预设已保存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preset navigation reflows on large text and landscape widths', (
    tester,
  ) async {
    final card = NpcCard(name: '有较长名称的地下城守卫队长', maximumHitPoints: 35);
    final data = DmData(cards: [card]);
    data.presets.add(
      EncounterPreset(
        name: '地下城入口的混合守卫伏击',
        entries: [EncounterPresetEntry.fromCard(card, count: 3)],
      ),
    );
    final storage = _MemoryDmStorage(initial: data);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: DmPage(storage: storage),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('遭遇预设'));
    await tester.pumpAndSettle();
    expect(find.text('地下城入口的混合守卫伏击'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(700, 390);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('创建当前遭遇'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryDmStorage extends DmStorage {
  DmData data;

  _MemoryDmStorage({DmData? initial}) : data = initial ?? DmData();

  @override
  Future<DmData> load() async => data;

  @override
  Future<File> save(DmData data) async {
    this.data = data;
    return File('memory');
  }
}

class _FakeMarkdownService extends NpcMarkdownService {
  final List<NpcMarkdownImportResult> results;

  _FakeMarkdownService(this.results);

  @override
  Future<List<NpcMarkdownImportResult>?> pickImportFiles() async => results;
}
