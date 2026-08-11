import 'dart:convert';
import 'dart:math';

import 'package:dndtoolkit_flutter/models/ai_character_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PointBuyRules', () {
    test('validates exact budgets and standard costs', () {
      expect(PointBuyRules.canSpendExactly(27), isTrue);
      expect(PointBuyRules.canSpendExactly(55), isFalse);
      expect(PointBuyRules.costOf([15, 15, 15, 8, 8, 8]), 27);
      expect(
        () => PointBuyRules.costOf([16, 10, 10, 10, 10, 10]),
        throwsFormatException,
      );
    });
  });

  test('guidance distinguishes hard constraints from AI preferences', () {
    expect(
      const AiGuidanceField(text: '', aiDecides: false).validate('职业'),
      contains('职业'),
    );
    expect(
      const AiGuidanceField(text: '', aiDecides: true).validate('职业'),
      isNull,
    );
    expect(const AiGuidanceField(text: '擅长自然魔法', aiDecides: true).toJson(), {
      'mode': 'preference',
      'text': '擅长自然魔法',
    });
  });

  test('4d6dl1 drops exactly one lowest die for every score', () {
    final roller = AbilityRoller(
      random: _SequenceRandom(
        List.generate(6, (_) => [0, 1, 2, 5]).expand((v) => v).toList(),
      ),
    );
    final groups = roller.rollGroups(1);
    expect(groups.single.values, [11, 11, 11, 11, 11, 11]);
    expect(groups.single.rolls.every((roll) => roll.droppedIndex == 0), isTrue);
  });

  test(
    'draft validates base array and maps only final scores to Character',
    () {
      final request = AiCharacterBuildRequest(
        configId: 'config',
        totalLevel: 1,
        guidance: const {},
        roleplay: _omittedRoleplay,
        abilitySpec: const AiAbilitySpec.standard(),
      );
      final draft = AiCharacterDraft.fromJson(_validDraftJson());
      expect(draft.validate(request), isEmpty);

      final character = draft.toCharacter(request);
      expect(character.attributes.strength, 15);
      expect(character.attributes.dexterity, 16);
      expect(character.attributes.wisdom, 13);
      expect(character.profile.playerName, isEmpty);
      expect(character.profile.portraitBase64, isEmpty);
      expect(character.profile.age, isEmpty);
      expect(character.roleplay.personalityTraits, isEmpty);
      expect(character.roleplay.featuresAndTraits, '黑暗视觉；精灵血统');
      expect(character.combat.hitPointsCurrent, character.combat.hitPointsMax);
      expect(character.combat.deathFail1, isFalse);
      expect(character.profile.proficiencyBonus, 2);
    },
  );

  test('draft rejects changed source array and inconsistent final score', () {
    final json = _validDraftJson();
    final abilities = json['abilities']! as Map<String, dynamic>;
    (abilities['baseAbilities']! as Map<String, dynamic>)['strength'] = 14;
    (abilities['finalAbilities']! as Map<String, dynamic>)['strength'] = 14;
    final draft = AiCharacterDraft.fromJson(json);
    final request = AiCharacterBuildRequest(
      configId: 'config',
      totalLevel: 1,
      guidance: const {},
      roleplay: _generatedRoleplay,
      abilitySpec: const AiAbilitySpec.standard(),
    );
    expect(draft.validate(request), contains('AI 改变了用户提供的基础属性数组'));
  });

  test('exact roleplay input overrides AI text without changing mechanics', () {
    final request = AiCharacterBuildRequest(
      configId: 'config',
      totalLevel: 1,
      guidance: const {},
      roleplay: AiRoleplayInput(
        omit: false,
        appearanceAiDecides: false,
        appearanceTendency: '',
        appearanceValues: {for (final key in aiAppearanceKeys) key: '用户-$key'},
        narrativeAiDecides: false,
        narrativeTendency: '',
        narrativeValues: {for (final key in aiNarrativeKeys) key: '用户-$key'},
      ),
      abilitySpec: const AiAbilitySpec.standard(),
    );
    final character = AiCharacterDraft.fromJson(
      _validDraftJson(),
    ).toCharacter(request);

    expect(character.profile.age, '用户-age');
    expect(character.roleplay.personalityTraits, '用户-personalityTraits');
    expect(character.roleplay.treasure, '用户-treasure');
    expect(character.roleplay.characterExperience, '用户-characterExperience');
    expect(character.roleplay.featuresAndTraits, '黑暗视觉；精灵血统');
  });

  test(
    'character experience stays local and is excluded from the AI contract',
    () {
      const emptyExactRoleplay = AiRoleplayInput(
        omit: false,
        appearanceAiDecides: false,
        appearanceTendency: '',
        appearanceValues: {},
        narrativeAiDecides: false,
        narrativeTendency: '',
        narrativeValues: {},
      );
      expect(emptyExactRoleplay.validate(), isEmpty);

      const playerExperience = '玩家填写的参团原因';
      final exactRequest = AiCharacterBuildRequest(
        configId: 'config',
        totalLevel: 1,
        guidance: const {},
        roleplay: const AiRoleplayInput(
          omit: false,
          appearanceAiDecides: false,
          appearanceTendency: '',
          appearanceValues: {},
          narrativeAiDecides: false,
          narrativeTendency: '',
          narrativeValues: {'characterExperience': playerExperience},
        ),
        abilitySpec: const AiAbilitySpec.standard(),
      );
      expect(
        jsonEncode(exactRequest.toPromptJson()),
        isNot(contains('characterExperience')),
      );

      final character = AiCharacterDraft.fromJson(
        _validDraftJson(),
      ).toCharacter(exactRequest);
      expect(character.roleplay.characterExperience, playerExperience);

      final responseWithUnknownExperience = _validDraftJson();
      (responseWithUnknownExperience['roleplay']!
              as Map<String, dynamic>)['characterExperience'] =
          '模型不应返回的内容';
      expect(
        () => AiCharacterDraft.fromJson(responseWithUnknownExperience),
        throwsFormatException,
      );
    },
  );

  test('ability strategy includes racial and advancement adjustments', () {
    final abilities = AiCharacterDraft.fromJson(_validDraftJson()).abilities;
    expect(formatAbilityStrategy(abilities), contains('敏捷：14+2'));
    expect(formatAbilityStrategy(abilities), contains('感知：10+1+2'));
  });

  test('AI spell entries are padded to the editor fixed slot counts', () {
    final json = _validDraftJson();
    (json['spellbook']! as Map<String, dynamic>)['groups'] = [
      {
        'level': 0,
        'totalSlots': 0,
        'spells': [
          {'name': '法师之手', 'isPrepared': false},
          {'name': '火焰箭', 'isPrepared': false},
        ],
      },
    ];
    final draft = AiCharacterDraft.fromJson(json);

    expect(draft.spellbook.allSpells[0].spells, hasLength(8));
    expect(draft.spellbook.allSpells[0].spells[0].name, '法师之手');
    expect(draft.spellbook.allSpells[0].spells[2].name, isEmpty);
    expect(draft.spellbook.allSpells[1].spells, hasLength(12));
  });
}

const _omittedRoleplay = AiRoleplayInput(
  omit: true,
  appearanceAiDecides: true,
  appearanceTendency: '',
  appearanceValues: {},
  narrativeAiDecides: true,
  narrativeTendency: '',
  narrativeValues: {},
);

const _generatedRoleplay = AiRoleplayInput(
  omit: false,
  appearanceAiDecides: true,
  appearanceTendency: '',
  appearanceValues: {},
  narrativeAiDecides: true,
  narrativeTendency: '',
  narrativeValues: {},
);

class _SequenceRandom implements Random {
  _SequenceRandom(this.values);

  final List<int> values;
  var _index = 0;

  @override
  int nextInt(int max) => values[_index++ % values.length] % max;

  @override
  bool nextBool() => nextInt(2) == 1;

  @override
  double nextDouble() => nextInt(1000000) / 1000000;
}

Map<String, dynamic> _validDraftJson() => {
  'schemaVersion': 1,
  'classes': [
    {'name': '游侠', 'level': 1},
  ],
  'abilities': {
    'baseAbilities': {
      'strength': 15,
      'dexterity': 14,
      'constitution': 13,
      'intelligence': 12,
      'wisdom': 10,
      'charisma': 8,
    },
    'racialBonuses': {
      'strength': 0,
      'dexterity': 2,
      'constitution': 0,
      'intelligence': 0,
      'wisdom': 1,
      'charisma': 0,
    },
    'advancementAdjustments': {
      'strength': 0,
      'dexterity': 0,
      'constitution': 0,
      'intelligence': 0,
      'wisdom': 2,
      'charisma': 0,
    },
    'finalAbilities': {
      'strength': 15,
      'dexterity': 16,
      'constitution': 13,
      'intelligence': 12,
      'wisdom': 13,
      'charisma': 8,
    },
  },
  'profile': {
    'characterName': '莱拉',
    'race': '木精灵',
    'classAndLevel': '游侠 1',
    'background': '侍僧',
    'alignment': '中立善良',
    'experiencePoints': 0,
    'passivePerception': 13,
    'age': '120',
    'height': '170cm',
    'weight': '55kg',
    'eyes': '绿色',
    'skin': '浅褐色',
    'hair': '棕色',
  },
  'combat': {
    'armorClass': 14,
    'initiative': 3,
    'speed': '35 尺',
    'hitPointsMax': 11,
    'hitDiceTotal': '1d10',
    'attacksAndSpellcastingNotes': '',
    'ability': '',
  },
  'proficiencies': {
    for (final key in _proficiencyKeys) key: false,
    'perception': true,
    'otherProficienciesAndLanguages': '通用语、精灵语',
  },
  'roleplay': {
    'personalityTraits': '沉着',
    'ideals': '守护自然',
    'bonds': '故乡森林',
    'flaws': '不信任城市',
    'characterBackstory': '来自森林。',
    'alliesAndOrganizations': '',
    'additionalFeaturesAndTraits': '',
    'treasure': '',
    'featuresAndTraits': '黑暗视觉；精灵血统',
  },
  'spellbook': {
    'spellcastingClass': '',
    'spellcastingAbility': '',
    'spellSaveDC': 0,
    'spellAttackBonus': 0,
    'groups': <dynamic>[],
  },
  'weapons': [
    {'name': '长弓', 'attackBonus': 5, 'damage': '1d8+3 穿刺'},
  ],
  'inventory': {
    'cp': 0,
    'sp': 0,
    'ep': 0,
    'gp': 10,
    'pp': 0,
    'equipmentText': '旅行者服装',
  },
};

const _proficiencyKeys = <String>{
  'strengthSave',
  'dexteritySave',
  'constitutionSave',
  'intelligenceSave',
  'wisdomSave',
  'charismaSave',
  'athletics',
  'acrobatics',
  'sleightOfHand',
  'stealth',
  'arcana',
  'history',
  'investigation',
  'nature',
  'religion',
  'animalHandling',
  'insight',
  'medicine',
  'perception',
  'survival',
  'deception',
  'intimidation',
  'performance',
  'persuasion',
};
