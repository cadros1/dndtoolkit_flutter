import 'dart:io';

import 'package:dndtoolkit_flutter/models/dm_models.dart';
import 'package:dndtoolkit_flutter/services/dm_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late DmStorage storage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dndtoolkit_dm_test_');
    storage = DmStorage(directoryProvider: () async => directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('empty storage starts with an empty local DM data set', () async {
    final data = await storage.load();

    expect(data.cards, isEmpty);
    expect(data.categories.single.id, defaultNpcCategoryId);
    expect(data.presets, isEmpty);
    expect(data.encounter.isEmpty, isTrue);
  });

  test('save and load preserve NPC library and current encounter', () async {
    final category = NpcCategory(name: '亡灵');
    final card = NpcCard(
      name: '骷髅',
      categoryId: category.id,
      maximumHitPoints: 13,
    );
    final data = DmData(categories: [category], cards: [card]);
    data.presets.add(
      EncounterPreset(
        name: '墓穴入口',
        entries: [EncounterPresetEntry.fromCard(card, count: 2)],
      ),
    );
    data.addInstances(card, ['骷髅 1']).single.setCurrentHitPoints(6);

    await storage.save(data);
    final restored = await storage.load();

    expect(restored.categories.map((item) => item.name), contains('亡灵'));
    expect(restored.cards.single.name, '骷髅');
    expect(restored.presets.single.name, '墓穴入口');
    expect(restored.presets.single.instanceCount, 2);
    expect(restored.encounter.instances.single.currentHitPoints, 6);
    expect(
      File(
        '${directory.path}${Platform.pathSeparator}dm_data.json',
      ).existsSync(),
      isTrue,
    );
  });

  test('invalid data is reported without being overwritten', () async {
    final file = File('${directory.path}${Platform.pathSeparator}dm_data.json');
    await file.writeAsString('{bad json');

    await expectLater(storage.load(), throwsA(isA<FormatException>()));
    expect(await file.readAsString(), '{bad json');
  });

  test('a newer schema is rejected and preserved for a newer app', () async {
    final file = File('${directory.path}${Platform.pathSeparator}dm_data.json');
    const content = '{"DnDToolkit-DM":4,"FutureField":"keep me"}';
    await file.writeAsString(content);

    await expectLater(storage.load(), throwsA(isA<FormatException>()));
    expect(await file.readAsString(), content);
  });

  test(
    'overlapping saves and load are serialized without partial JSON',
    () async {
      final first = DmData(cards: [NpcCard(name: '第一版')]);
      final second = DmData(cards: [NpcCard(name: '第二版')]);

      final firstSave = storage.save(first);
      final secondSave = storage.save(second);
      final loaded = storage.load();

      await Future.wait([firstSave, secondSave]);
      expect((await loaded).cards.single.name, '第二版');
    },
  );

  test('version 1 data migrates to defaults and derived modifiers', () async {
    final file = File('${directory.path}${Platform.pathSeparator}dm_data.json');
    await file.writeAsString('''
{"DnDToolkit-DM":1,"Categories":[],"NpcCards":[{"Id":"old","Name":"旧卡","CategoryId":null,"Abilities":{"Strength":15,"StrengthModifier":99}}],"CurrentEncounter":{}}
''');

    final restored = await storage.load();

    expect(restored.categories.single.id, defaultNpcCategoryId);
    expect(restored.cards.single.categoryId, defaultNpcCategoryId);
    expect(restored.cards.single.abilities.strengthModifier, 2);
    expect(restored.presets, isEmpty);
  });

  test('version 2 data loads with an empty preset collection', () async {
    final file = File('${directory.path}${Platform.pathSeparator}dm_data.json');
    await file.writeAsString('''
{"DnDToolkit-DM":2,"Categories":[],"NpcCards":[],"CurrentEncounter":{}}
''');

    final restored = await storage.load();

    expect(restored.presets, isEmpty);
    expect(restored.categories.single.id, defaultNpcCategoryId);
  });
}
