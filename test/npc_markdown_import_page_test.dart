import 'package:dndtoolkit_flutter/models/dm_models.dart';
import 'package:dndtoolkit_flutter/pages/dm/npc_markdown_import_page.dart';
import 'package:dndtoolkit_flutter/services/npc_markdown_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows every file and returns confirmed category decisions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final valid = NpcMarkdownCodec.parse(
      '月影狼.md',
      NpcMarkdownCodec.exportCard(
        NpcCard(name: '月影狼', maximumHitPoints: 27, armorClass: 14),
        categoryName: '荒野',
      ),
    );
    final invalid = NpcMarkdownCodec.parse('空文件.md', '  ');
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final resultFuture = navigator.push<List<NpcMarkdownImportSelection>>(
      MaterialPageRoute(
        builder: (_) => NpcMarkdownImportPage(
          results: [valid, invalid],
          categories: [NpcCategory.defaultCategory()],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('月影狼.md'), findsOneWidget);
    expect(find.text('空文件.md'), findsOneWidget);
    expect(find.text('校验一致'), findsOneWidget);
    expect(find.text('无法导入'), findsOneWidget);
    expect(find.text('创建“荒野”'), findsOneWidget);
    expect(find.text('导入所选 1 张'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('导入所选 1 张'));
    await tester.pumpAndSettle();
    final selections = await resultFuture;

    expect(selections, hasLength(1));
    expect(selections!.single.result.card!.name, '月影狼');
    expect(selections.single.categoryId, isNull);
    expect(selections.single.categoryNameToCreate, '荒野');
  });

  testWidgets('can deselect all importable files', (tester) async {
    final arbitrary = NpcMarkdownCodec.parse(
      '任意.md',
      '# 骷髅\n护甲等级：13\n最大生命值：13\n',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NpcMarkdownImportPage(
          results: [arbitrary],
          categories: [NpcCategory.defaultCategory()],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('尽力识别'), findsOneWidget);
    await tester.tap(find.text('取消全选'));
    await tester.pump();

    expect(find.text('导入所选 0 张'), findsOneWidget);
    await tester.tap(find.text('导入所选 0 张'));
    await tester.pump();
    expect(find.text('导入 NPC Markdown'), findsOneWidget);
  });
}
