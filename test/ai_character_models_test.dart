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

  test('build requirements distinguish description and exact choice modes', () {
    expect(
      const AiBuildRequirements.fromDescription(
        characterDescription: '',
        gameplayPreference: '',
      ).validate(),
      containsAll(['请填写角色描述', '请填写玩法偏好']),
    );
    expect(_exactRequirements.validate(), isEmpty);
    expect(
      const AiBuildRequirements.exactChoices(
        characterName: '',
        classAndSubclass: '游侠',
        raceAndSubrace: '木精灵',
        background: '侍僧',
        alignment: '中立善良',
        gameplayPreference: '远程支援',
      ).validate(),
      contains('请填写姓名'),
    );
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
      final json = _validDraftJson();
      (json['profile']! as Map<String, dynamic>)['characterName'] = '模型改写的姓名';
      final request = AiCharacterBuildRequest(
        configId: 'config',
        totalLevel: 1,
        requirements: _exactRequirements,
        roleplay: _omittedRoleplay,
        abilitySpec: const AiAbilitySpec.standard(),
      );
      final draft = AiCharacterDraft.fromJson(json);
      expect(draft.validate(request), isEmpty);

      final character = draft.toCharacter(request);
      expect(character.attributes.strength, 15);
      expect(character.attributes.dexterity, 16);
      expect(character.attributes.wisdom, 13);
      expect(character.profile.characterName, '莱拉');
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
      requirements: _exactRequirements,
      roleplay: _generatedRoleplay,
      abilitySpec: const AiAbilitySpec.standard(),
    );
    expect(draft.validate(request), contains('AI 改变了用户提供的基础属性数组'));
  });

  test('exact roleplay input overrides AI text without changing mechanics', () {
    final request = AiCharacterBuildRequest(
      configId: 'config',
      totalLevel: 1,
      requirements: _exactRequirements,
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
        requirements: _exactRequirements,
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

  test('四阶段草稿由本地计算最终属性并按字段职责组装角色', () {
    const plan = AiBuildPlan(
      classes: [AiBuildPlanClass(name: '游侠', level: 4, subclass: '猎人')],
      raceAndSubrace: '木精灵',
      background: '侍僧',
      combatRole: '远程物理输出与支援',
      adventureRole: '察觉与荒野探索',
      synergy: '敏捷与感知同时服务于两个定位',
      warnings: '',
    );
    final request = AiCharacterBuildRequest(
      configId: 'config',
      totalLevel: 4,
      requirements: _exactRequirements,
      roleplay: _omittedRoleplay,
      abilitySpec: const AiAbilitySpec.standard(),
    );
    final mechanics = AiMechanicsDraft.fromJson(_validMechanicsJson());
    final derived = AiDerivedDraft.fromJson(_validDerivedJson());

    expect(mechanics.validate(request.abilitySpec), isEmpty);
    expect(mechanics.abilities.finalScores.dexterity, 18);
    final character = AiCharacterAssembly.toCharacter(
      request: request,
      plan: plan,
      mechanics: mechanics,
      derived: derived,
      narrative: AiNarrativeDraft.empty,
    );

    expect(character.profile.classAndLevel, '游侠（猎人） 4');
    expect(character.attributes.dexterity, 18);
    expect(character.combat.ability, contains('察觉专精'));
    expect(character.combat.ability, contains('资源次数：4 次'));
    expect(character.combat.attacksAndSpellcastingNotes, '长弓攻击可配合猎人印记。');
    expect(character.combat.hitPointsCurrent, character.combat.hitPointsMax);
    expect(character.combat.hitDiceCurrent, character.combat.hitDiceTotal);
    expect(character.spellbook.allSpells[1].remainSlots, 3);
    expect(character.roleplay.featuresAndTraits, isEmpty);
  });

  test('衍生数值武器数量必须与机械选择一致', () {
    final mechanics = AiMechanicsDraft.fromJson(_validMechanicsJson());
    final json = _validDerivedJson();
    json['weapons'] = <dynamic>[];
    final derived = AiDerivedDraft.fromJson(json);
    expect(derived.validate(mechanics), contains('武器衍生数值必须与机械选择中的武器数量一致'));
  });

  test('衍生数值会校验组成加法与最终字段', () {
    final mechanics = AiMechanicsDraft.fromJson(_validMechanicsJson());
    final json = _validDerivedJson();
    final checks = json['calculationChecks']! as List<dynamic>;
    (checks.first as Map<String, dynamic>)['finalValue'] = 15;
    final derived = AiDerivedDraft.fromJson(json);
    expect(
      derived.validate(mechanics),
      containsAll([
        'passivePerception 的数值组成加法不一致',
        'passivePerception 的最终值与角色数值不一致',
      ]),
    );
  });

  test('明确输入且无需人物塑造时跳过第四阶段', () {
    final request = AiCharacterBuildRequest(
      configId: 'config',
      totalLevel: 1,
      requirements: _exactRequirements,
      roleplay: _omittedRoleplay,
      abilitySpec: const AiAbilitySpec.standard(),
    );
    expect(needsNarrativeStage(request), isFalse);
  });

  test('自由生成时两组人物塑造都不交给 AI 也跳过第四阶段', () {
    final request = AiCharacterBuildRequest(
      configId: 'config',
      totalLevel: 1,
      requirements: const AiBuildRequirements.fromDescription(
        characterDescription: '可靠的前排战士',
        gameplayPreference: '保护同伴',
      ),
      roleplay: const AiRoleplayInput(
        omit: false,
        appearanceAiDecides: false,
        appearanceTendency: '',
        appearanceValues: {},
        narrativeAiDecides: false,
        narrativeTendency: '',
        narrativeValues: {},
      ),
      abilitySpec: const AiAbilitySpec.standard(),
    );

    expect(needsNarrativeStage(request), isFalse);
  });

  test('人物塑造响应只接受当前生成范围的字段', () {
    final appearance = {
      'schemaVersion': 1,
      for (final key in aiAppearanceKeys) key: '外貌',
    };
    expect(
      AiNarrativeDraft.fromJson(
        appearance,
        AiNarrativeScope.appearance,
      ).values.keys,
      containsAll(aiAppearanceKeys),
    );
    appearance['personalityTraits'] = '不应出现';
    expect(
      () => AiNarrativeDraft.fromJson(appearance, AiNarrativeScope.appearance),
      throwsFormatException,
    );
  });
}

const _exactRequirements = AiBuildRequirements.exactChoices(
  characterName: '莱拉',
  classAndSubclass: '游侠',
  raceAndSubrace: '木精灵',
  background: '侍僧',
  alignment: '中立善良',
  gameplayPreference: '远程支援并探索荒野',
);

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

Map<String, dynamic> _validMechanicsJson() => {
  'schemaVersion': 1,
  'abilities': {
    'baseAbilities': {
      'strength': 13,
      'dexterity': 15,
      'constitution': 14,
      'intelligence': 10,
      'wisdom': 12,
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
      'dexterity': 1,
      'constitution': 0,
      'intelligence': 0,
      'wisdom': 1,
      'charisma': 0,
    },
    'advancementChoices': '游侠 4 级：敏捷 +1、感知 +1',
  },
  'proficiencies': {
    for (final key in _proficiencyKeys) key: false,
    'perception': true,
    'otherProficienciesAndLanguages': '轻甲、中甲、盾牌；通用语、精灵语',
  },
  'specialAbilities': '黑暗视觉；精类血统；察觉专精；战斗风格：箭术',
  'attacksAndSpellcastingNotes': '长弓攻击可配合猎人印记。',
  'spellcasting': {
    'class': '游侠',
    'ability': '感知',
    'groups': [
      {
        'level': 1,
        'spells': [
          {'name': '猎人印记', 'isPrepared': false},
        ],
      },
    ],
  },
  'weapons': [
    {'name': '长弓'},
  ],
  'inventory': {
    'cp': 0,
    'sp': 0,
    'ep': 0,
    'gp': 10,
    'pp': 0,
    'equipmentText': '鳞甲、长弓、探索套组',
  },
};

Map<String, dynamic> _validDerivedJson() => {
  'schemaVersion': 1,
  'experiencePoints': 0,
  'passivePerception': 16,
  'armorClass': 16,
  'initiative': 4,
  'speed': '35 尺',
  'hitPointsMax': 36,
  'hitDiceTotal': '4d10',
  'spellSaveDC': 12,
  'spellAttackBonus': 4,
  'spellSlots': [
    {'level': 1, 'totalSlots': 3},
  ],
  'weapons': [
    {'attackBonus': 8, 'damage': '1d8+4 穿刺'},
  ],
  'specialAbilityNumericNotes': '资源次数：4 次',
  'calculationChecks': [
    {
      'field': 'passivePerception',
      'base': 10,
      'adjustments': [3, 3],
      'finalValue': 16,
    },
    {
      'field': 'armorClass',
      'base': 14,
      'adjustments': [2],
      'finalValue': 16,
    },
    {'field': 'initiative', 'base': 4, 'adjustments': [], 'finalValue': 4},
    {
      'field': 'hitPointsMax',
      'base': 10,
      'adjustments': [26],
      'finalValue': 36,
    },
    {
      'field': 'spellSaveDC',
      'base': 8,
      'adjustments': [2, 2],
      'finalValue': 12,
    },
    {
      'field': 'spellAttackBonus',
      'base': 2,
      'adjustments': [2],
      'finalValue': 4,
    },
    {'field': 'spellSlot:1', 'base': 3, 'adjustments': [], 'finalValue': 3},
    {
      'field': 'weaponAttackBonus:0',
      'base': 4,
      'adjustments': [2, 2],
      'finalValue': 8,
    },
  ],
  'valueExplanations': ['护甲等级：鳞甲 14 + 敏捷上限 2 = 16'],
};
