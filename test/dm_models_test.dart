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
  });
}
