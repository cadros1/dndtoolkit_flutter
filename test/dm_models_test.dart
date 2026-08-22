import 'package:dndtoolkit_flutter/models/dm_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DM model contracts', () {
    test('NPC card keeps all fields through JSON round trip', () {
      final card = NpcCard(
        name: '守卫队长',
        categoryId: 'guards',
        sizeAndType: '中型类人生物',
        maximumHitPoints: 27,
        armorClass: 16,
        speed: '30 尺',
        abilities: NpcAbilityScores(strength: 15, dexterity: 12),
        saves: '力量 +4',
        skills: '察觉 +3',
        damageResistances: '寒冷',
        senses: '被动察觉 13',
        languages: '通用语',
        challengeRating: '1/2',
        traits: [NpcFeatureEntry(name: '警觉', description: '不会被轻易突袭。')],
        actions: [NpcFeatureEntry(name: '长剑', description: '近战攻击。')],
        notes: '夜间值守',
      );

      final restored = NpcCard.fromJson(card.toJson());

      expect(restored.toJson(), card.toJson());
      expect(restored.abilities.strengthModifier, 2);
      expect(restored.actions.single.name, '长剑');
    });

    test(
      'encounter instance owns a snapshot independent from its template',
      () {
        final data = DmData();
        final card = NpcCard(name: '地精', maximumHitPoints: 7, armorClass: 15);
        data.cards.add(card);

        final instance = data.addInstances(card, ['地精 1']).single;
        card
          ..name = '改名后的模板'
          ..maximumHitPoints = 99
          ..armorClass = 20;
        data.cards.clear();

        expect(instance.displayName, '地精 1');
        expect(instance.cardSnapshot.name, '地精');
        expect(instance.maximumHitPoints, 7);
        expect(instance.cardSnapshot.armorClass, 15);
      },
    );

    test('deleting a category moves cards to the default category', () {
      final category = NpcCategory(name: '城镇守卫');
      final card = NpcCard(name: '守卫', categoryId: category.id);
      final data = DmData(categories: [category], cards: [card]);

      data.deleteCategory(category.id);

      expect(data.categories, hasLength(1));
      expect(data.categories.single.isDefault, isTrue);
      expect(card.categoryId, defaultNpcCategoryId);
      expect(data.cards, contains(card));
    });

    test('the default category cannot be deleted and receives new cards', () {
      final data = DmData(cards: [NpcCard(name: '守卫')]);

      data.deleteCategory(defaultNpcCategoryId);

      expect(data.categories.single.id, defaultNpcCategoryId);
      expect(data.cards.single.categoryId, defaultNpcCategoryId);
    });

    test('ability modifiers are derived from scores', () {
      final ability = NpcAbilityScores(strength: 9, dexterity: 15);

      expect(ability.strengthModifier, -1);
      expect(ability.dexterityModifier, 2);
      ability.strength = 20;
      ability.synchronizeModifiers();
      expect(ability.strengthModifier, 5);
    });

    test('HP limits and group transitions follow encounter rules', () {
      final data = DmData();
      final instance = data.addInstances(
        NpcCard(name: '狼', maximumHitPoints: 11),
        ['狼 1'],
      ).single;
      final group = EncounterGroup(name: '狼群', initiative: 14);
      data.encounter.groups.add(group);

      instance
        ..initiative = 12
        ..setCurrentHitPoints(50)
        ..setTemporaryHitPoints(-4);
      data.assignInstancesToGroup([instance.id], group.id);

      expect(instance.currentHitPoints, 11);
      expect(instance.temporaryHitPoints, 0);
      expect(instance.groupId, group.id);
      expect(instance.initiative, isNull);

      data.deleteGroup(group.id, removeMembers: false);
      expect(instance.groupId, isNull);
      expect(instance.initiative, isNull);
      expect(data.encounter.instances, contains(instance));
    });

    test('DM root JSON keeps the current encounter', () {
      final data = DmData();
      final card = NpcCard(name: '骷髅', maximumHitPoints: 13);
      data.cards.add(card);
      final instance = data.addInstances(card, ['骷髅 1']).single;
      instance
        ..initiative = 9
        ..setCurrentHitPoints(4)
        ..setTemporaryHitPoints(2);

      final restored = DmData.fromJson(data.toJson());

      expect(restored.encounter.instances.single.displayName, '骷髅 1');
      expect(restored.encounter.instances.single.currentHitPoints, 4);
      expect(restored.encounter.instances.single.temporaryHitPoints, 2);
      expect(restored.encounter.instances.single.initiative, 9);
    });

    test(
      'encounter preset round trip preserves lineup and group arrangement',
      () {
        final card = NpcCard(name: '哥布林', maximumHitPoints: 7, armorClass: 15);
        final group = EncounterPresetGroup(name: '伏击组');
        final preset = EncounterPreset(
          name: '林间伏击',
          groups: [group],
          entries: [
            EncounterPresetEntry.fromCard(card, count: 2, groupId: group.id)
              ..instanceNames = ['斥候', '弓手'],
          ],
        );

        final restored = EncounterPreset.fromJson(preset.toJson());

        expect(restored.name, '林间伏击');
        expect(restored.instanceCount, 2);
        expect(restored.groups.single.name, '伏击组');
        expect(restored.entries.single.instanceNames, ['斥候', '弓手']);
        expect(restored.entries.single.cardSnapshot.name, '哥布林');
        expect(restored.entries.single.groupId, restored.groups.single.id);
      },
    );

    test('starting a preset creates fresh runtime state from snapshots', () {
      final source = NpcCard(name: '狼', maximumHitPoints: 11, armorClass: 13);
      final group = EncounterPresetGroup(name: '狼群');
      final preset = EncounterPreset(
        name: '狼群突袭',
        groups: [group],
        entries: [
          EncounterPresetEntry.fromCard(source, count: 2, groupId: group.id)
            ..instanceNames = ['灰背', '断耳'],
        ],
      );

      final encounter = preset.createEncounter();

      expect(encounter.groups, hasLength(1));
      expect(encounter.groups.single.initiative, isNull);
      expect(encounter.instances, hasLength(2));
      expect(encounter.instances.map((item) => item.displayName), ['灰背', '断耳']);
      expect(
        encounter.instances.map((item) => item.currentHitPoints),
        everyElement(11),
      );
      expect(
        encounter.instances.map((item) => item.temporaryHitPoints),
        everyElement(0),
      );
      expect(
        encounter.instances.map((item) => item.initiative),
        everyElement(isNull),
      );
      expect(
        encounter.instances.map((item) => item.groupId),
        everyElement(encounter.groups.single.id),
      );

      source
        ..name = '已修改模板'
        ..maximumHitPoints = 99;
      expect(encounter.instances.first.cardSnapshot.name, '狼');
      expect(encounter.instances.first.maximumHitPoints, 11);
    });

    test('preset keeps independent NPC and groups in one top-level order', () {
      final group = EncounterPresetGroup(name: '后排', sortOrder: 1);
      final independent = EncounterPresetEntry.fromCard(
        NpcCard(name: '斥候'),
        sortOrder: 0,
      );
      final member = EncounterPresetEntry.fromCard(
        NpcCard(name: '弓手'),
        groupId: group.id,
        sortOrder: 0,
      );
      final preset = EncounterPreset(
        name: '前后夹击',
        groups: [group],
        entries: [member, independent],
      );

      final restored = EncounterPreset.fromJson(preset.toJson());
      final encounter = restored.createEncounter();
      final restoredIndependent = restored.entries.singleWhere(
        (entry) => entry.groupId == null,
      );

      expect(restoredIndependent.sortOrder, 0);
      expect(restored.groups.single.sortOrder, 1);
      expect(encounter.instances.first.displayName, '斥候');
      expect(encounter.instances.first.groupId, isNull);
      expect(encounter.groups.single.sortOrder, 1);
      expect(
        encounter.instances
            .singleWhere((instance) => instance.displayName == '弓手')
            .groupId,
        encounter.groups.single.id,
      );
    });

    test(
      'current encounter extraction omits HP, temporary HP and initiative',
      () {
        final card = NpcCard(name: '骷髅', maximumHitPoints: 13);
        final data = DmData(cards: [card]);
        final group = EncounterGroup(name: '墓穴守卫', initiative: 17);
        data.encounter.groups.add(group);
        final instances = data.addInstances(card, ['左侧骷髅', '右侧骷髅']);
        data.assignInstancesToGroup(
          instances.map((instance) => instance.id),
          group.id,
        );
        instances.first
          ..setCurrentHitPoints(2)
          ..setTemporaryHitPoints(5);

        final preset = EncounterPreset.fromEncounter(
          data.encounter,
          name: '墓穴入口',
        );
        final created = preset.createEncounter();

        expect(preset.entries.single.count, 2);
        expect(preset.entries.single.instanceNames, ['左侧骷髅', '右侧骷髅']);
        expect(created.groups.single.name, '墓穴守卫');
        expect(created.groups.single.initiative, isNull);
        expect(
          created.instances.map((instance) => instance.currentHitPoints),
          everyElement(13),
        );
        expect(
          created.instances.map((instance) => instance.temporaryHitPoints),
          everyElement(0),
        );
      },
    );

    test(
      'duplicating a preset gives the preset structure fresh identities',
      () {
        final group = EncounterPresetGroup(name: '前排');
        final original = EncounterPreset(
          name: '守门战',
          groups: [group],
          entries: [
            EncounterPresetEntry.fromCard(
              NpcCard(name: '守卫'),
              groupId: group.id,
            ),
          ],
        );

        final duplicate = original.deepCopy(newIdentity: true, name: '守门战（副本）');

        expect(duplicate.id, isNot(original.id));
        expect(duplicate.groups.single.id, isNot(original.groups.single.id));
        expect(duplicate.entries.single.id, isNot(original.entries.single.id));
        expect(duplicate.entries.single.groupId, duplicate.groups.single.id);
        expect(
          duplicate.entries.single.cardSnapshot.id,
          original.entries.single.cardSnapshot.id,
        );
      },
    );
  });
}
