import 'dart:math';

import 'character.dart';

const aiCharacterMinLevel = 1;
const aiCharacterMaxLevel = 5;

const abilityKeys = <String>[
  'strength',
  'dexterity',
  'constitution',
  'intelligence',
  'wisdom',
  'charisma',
];

enum AiBuildRequirementMode { fromDescription, exactChoices }

class AiBuildRequirements {
  const AiBuildRequirements.fromDescription({
    required this.characterDescription,
    required this.gameplayPreference,
  }) : mode = AiBuildRequirementMode.fromDescription,
       characterName = '',
       classAndSubclass = '',
       raceAndSubrace = '',
       background = '',
       alignment = '';

  const AiBuildRequirements.exactChoices({
    required this.characterName,
    required this.classAndSubclass,
    required this.raceAndSubrace,
    required this.background,
    required this.alignment,
    required this.gameplayPreference,
  }) : mode = AiBuildRequirementMode.exactChoices,
       characterDescription = '';

  final AiBuildRequirementMode mode;
  final String characterDescription;
  final String characterName;
  final String classAndSubclass;
  final String raceAndSubrace;
  final String background;
  final String alignment;
  final String gameplayPreference;

  List<String> validate() {
    final errors = <String>[];
    if (gameplayPreference.trim().isEmpty) errors.add('请填写玩法偏好');
    switch (mode) {
      case AiBuildRequirementMode.fromDescription:
        if (characterDescription.trim().isEmpty) errors.add('请填写角色描述');
        break;
      case AiBuildRequirementMode.exactChoices:
        if (characterName.trim().isEmpty) errors.add('请填写姓名');
        if (classAndSubclass.trim().isEmpty) errors.add('请填写职业');
        if (raceAndSubrace.trim().isEmpty) errors.add('请填写种族');
        if (background.trim().isEmpty) errors.add('请填写背景');
        if (alignment.trim().isEmpty) errors.add('请填写阵营');
        break;
    }
    return errors;
  }
}

const aiAppearanceKeys = <String>[
  'age',
  'height',
  'weight',
  'eyes',
  'skin',
  'hair',
  'additionalFeaturesAndTraits',
];

const aiNarrativeKeys = <String>[
  'personalityTraits',
  'ideals',
  'bonds',
  'flaws',
  'alliesAndOrganizations',
  'treasure',
  'characterExperience',
  'characterBackstory',
];

class AiRoleplayInput {
  const AiRoleplayInput({
    required this.omit,
    required this.appearanceAiDecides,
    required this.appearanceTendency,
    required this.appearanceValues,
    required this.narrativeAiDecides,
    required this.narrativeTendency,
    required this.narrativeValues,
  });

  final bool omit;
  final bool appearanceAiDecides;
  final String appearanceTendency;
  final Map<String, String> appearanceValues;
  final bool narrativeAiDecides;
  final String narrativeTendency;
  final Map<String, String> narrativeValues;

  List<String> validate() => const [];

  String appearanceValue(String key) => (appearanceValues[key] ?? '').trim();

  String narrativeValue(String key) => (narrativeValues[key] ?? '').trim();
}

enum AiAbilityMethod { pointBuy, rolled, providedArray, standardArray }

extension AiAbilityMethodDisplay on AiAbilityMethod {
  String get label => switch (this) {
    AiAbilityMethod.pointBuy => '购点法',
    AiAbilityMethod.rolled => '掷骰法',
    AiAbilityMethod.providedArray => '给定点数组',
    AiAbilityMethod.standardArray => '标准点数组',
  };
}

class DiceRollDetail {
  const DiceRollDetail({required this.dice, required this.droppedIndex});

  final List<int> dice;
  final int droppedIndex;

  int get score {
    var total = 0;
    for (var index = 0; index < dice.length; index++) {
      if (index != droppedIndex) total += dice[index];
    }
    return total;
  }
}

class AbilityRollGroup {
  const AbilityRollGroup(this.rolls);

  final List<DiceRollDetail> rolls;
  List<int> get values =>
      rolls.map((roll) => roll.score).toList(growable: false);
}

class AbilityRoller {
  AbilityRoller({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  List<AbilityRollGroup> rollGroups(int count) {
    if (count < 1 || count > 10) throw RangeError.range(count, 1, 10, 'count');
    return List.generate(count, (_) {
      return AbilityRollGroup(List.generate(6, (_) => _roll4d6DropLowest()));
    });
  }

  DiceRollDetail _roll4d6DropLowest() {
    final dice = List.generate(4, (_) => _random.nextInt(6) + 1);
    var droppedIndex = 0;
    for (var index = 1; index < dice.length; index++) {
      if (dice[index] < dice[droppedIndex]) droppedIndex = index;
    }
    return DiceRollDetail(dice: dice, droppedIndex: droppedIndex);
  }
}

class PointBuyRules {
  static const costs = <int, int>{
    8: 0,
    9: 1,
    10: 2,
    11: 3,
    12: 4,
    13: 5,
    14: 7,
    15: 9,
  };

  static bool canSpendExactly(int budget) {
    if (budget < 0 || budget > 54) return false;
    var reachable = <int>{0};
    for (var ability = 0; ability < 6; ability++) {
      reachable = {
        for (final current in reachable)
          for (final cost in costs.values)
            if (current + cost <= budget) current + cost,
      };
    }
    return reachable.contains(budget);
  }

  static int costOf(Iterable<int> scores) {
    var total = 0;
    for (final score in scores) {
      final cost = costs[score];
      if (cost == null) throw const FormatException('购点法基础属性必须在 8–15 之间');
      total += cost;
    }
    return total;
  }
}

class AiAbilitySpec {
  const AiAbilitySpec._({required this.method, this.budget, this.values});

  const AiAbilitySpec.pointBuy(int budget)
    : this._(method: AiAbilityMethod.pointBuy, budget: budget);

  const AiAbilitySpec.rolled(List<int> values)
    : this._(method: AiAbilityMethod.rolled, values: values);

  const AiAbilitySpec.provided(List<int> values)
    : this._(method: AiAbilityMethod.providedArray, values: values);

  const AiAbilitySpec.standard()
    : this._(
        method: AiAbilityMethod.standardArray,
        values: const [15, 14, 13, 12, 10, 8],
      );

  final AiAbilityMethod method;
  final int? budget;
  final List<int>? values;

  String? validate() {
    switch (method) {
      case AiAbilityMethod.pointBuy:
        final value = budget;
        if (value == null || value < 0 || value > 54) return '购点预算必须在 0–54 之间';
        if (!PointBuyRules.canSpendExactly(value)) return '该预算无法用标准费用表恰好用完';
        break;
      case AiAbilityMethod.rolled:
      case AiAbilityMethod.providedArray:
      case AiAbilityMethod.standardArray:
        final array = values;
        if (array == null || array.length != 6) return '属性数组必须包含 6 个点数';
        if (method == AiAbilityMethod.providedArray &&
            array.any((value) => value < 3 || value > 18)) {
          return '给定点数组中的每个点数必须在 3–18 之间';
        }
        break;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'method': method.name,
    if (budget != null) 'budget': budget,
    if (values != null) 'values': values,
  };
}

class AiCharacterBuildRequest {
  const AiCharacterBuildRequest({
    required this.configId,
    required this.totalLevel,
    required this.requirements,
    required this.roleplay,
    required this.abilitySpec,
  });

  final String configId;
  final int totalLevel;
  final AiBuildRequirements requirements;
  final AiRoleplayInput roleplay;
  final AiAbilitySpec abilitySpec;

  List<String> validate() {
    final errors = <String>[];
    if (totalLevel < aiCharacterMinLevel || totalLevel > aiCharacterMaxLevel) {
      errors.add('角色总等级必须在 1–5 之间');
    }
    errors.addAll(requirements.validate());
    errors.addAll(roleplay.validate());
    final abilityError = abilitySpec.validate();
    if (abilityError != null) errors.add(abilityError);
    return errors;
  }
}

class AbilityScores {
  const AbilityScores({
    required this.strength,
    required this.dexterity,
    required this.constitution,
    required this.intelligence,
    required this.wisdom,
    required this.charisma,
  });

  final int strength;
  final int dexterity;
  final int constitution;
  final int intelligence;
  final int wisdom;
  final int charisma;

  List<int> get values => [
    strength,
    dexterity,
    constitution,
    intelligence,
    wisdom,
    charisma,
  ];

  int operator [](String key) => switch (key) {
    'strength' => strength,
    'dexterity' => dexterity,
    'constitution' => constitution,
    'intelligence' => intelligence,
    'wisdom' => wisdom,
    'charisma' => charisma,
    _ => throw ArgumentError.value(key, 'key'),
  };

  factory AbilityScores.fromJson(Map<String, dynamic> json, String path) {
    _checkKeys(json, abilityKeys.toSet(), path);
    return AbilityScores(
      strength: _int(json, 'strength', path),
      dexterity: _int(json, 'dexterity', path),
      constitution: _int(json, 'constitution', path),
      intelligence: _int(json, 'intelligence', path),
      wisdom: _int(json, 'wisdom', path),
      charisma: _int(json, 'charisma', path),
    );
  }
}

class AiAbilityBreakdown {
  const AiAbilityBreakdown({
    required this.base,
    required this.racialBonuses,
    required this.advancementAdjustments,
    required this.finalScores,
  });

  final AbilityScores base;
  final AbilityScores racialBonuses;
  final AbilityScores advancementAdjustments;
  final AbilityScores finalScores;

  factory AiAbilityBreakdown.fromJson(Map<String, dynamic> json) {
    _checkKeys(json, const {
      'baseAbilities',
      'racialBonuses',
      'advancementAdjustments',
      'finalAbilities',
    }, 'abilities');
    return AiAbilityBreakdown(
      base: AbilityScores.fromJson(
        _map(json, 'baseAbilities', 'abilities'),
        'abilities.baseAbilities',
      ),
      racialBonuses: AbilityScores.fromJson(
        _map(json, 'racialBonuses', 'abilities'),
        'abilities.racialBonuses',
      ),
      advancementAdjustments: AbilityScores.fromJson(
        _map(json, 'advancementAdjustments', 'abilities'),
        'abilities.advancementAdjustments',
      ),
      finalScores: AbilityScores.fromJson(
        _map(json, 'finalAbilities', 'abilities'),
        'abilities.finalAbilities',
      ),
    );
  }

  List<String> validate(AiAbilitySpec spec) {
    final errors = <String>[];
    for (final key in abilityKeys) {
      final expected =
          base[key] + racialBonuses[key] + advancementAdjustments[key];
      if (finalScores[key] != expected) {
        errors.add('$key 的最终值加法不一致');
      }
      if (finalScores[key] < 1 || finalScores[key] > 30) {
        errors.add('$key 的最终值超出 1–30');
      }
    }

    if (spec.method == AiAbilityMethod.pointBuy) {
      try {
        if (PointBuyRules.costOf(base.values) != spec.budget) {
          errors.add('基础属性没有恰好用完购点预算');
        }
      } on FormatException catch (error) {
        errors.add(error.message);
      }
    } else if (!_sameMultiset(base.values, spec.values!)) {
      errors.add('AI 改变了用户提供的基础属性数组');
    }
    return errors;
  }
}

String formatAbilityStrategy(AiAbilityBreakdown abilities) {
  const labels = <String, String>{
    'strength': '力量',
    'dexterity': '敏捷',
    'constitution': '体质',
    'intelligence': '智力',
    'wisdom': '感知',
    'charisma': '魅力',
  };
  final lines = <String>['模型采取的六维加点策略：'];
  for (final key in abilityKeys) {
    final racial = abilities.racialBonuses[key];
    final advancement = abilities.advancementAdjustments[key];
    final buffer = StringBuffer('${labels[key]}：${abilities.base[key]}');
    if (racial != 0) buffer.write(racial > 0 ? '+$racial' : '$racial');
    if (advancement != 0) {
      buffer.write(advancement > 0 ? '+$advancement' : '$advancement');
    }
    lines.add(buffer.toString());
  }
  return lines.join('\n');
}

class AiClassLevel {
  const AiClassLevel({required this.name, required this.level});

  final String name;
  final int level;

  factory AiClassLevel.fromJson(Map<String, dynamic> json, String path) {
    _checkKeys(json, const {'name', 'level'}, path);
    return AiClassLevel(
      name: _nonEmptyString(json, 'name', path),
      level: _int(json, 'level', path),
    );
  }
}

class AiCharacterDraft {
  const AiCharacterDraft({
    required this.classes,
    required this.abilities,
    required this.profile,
    required this.combat,
    required this.proficiencies,
    required this.roleplay,
    required this.spellbook,
    required this.weapons,
    required this.inventory,
  });

  final List<AiClassLevel> classes;
  final AiAbilityBreakdown abilities;
  final Profile profile;
  final CombatStats combat;
  final Proficiencies proficiencies;
  final Roleplay roleplay;
  final Spellbook spellbook;
  final List<Weapon> weapons;
  final Inventory inventory;

  factory AiCharacterDraft.fromJson(Map<String, dynamic> json) {
    _checkKeys(json, const {
      'schemaVersion',
      'classes',
      'abilities',
      'profile',
      'combat',
      'proficiencies',
      'roleplay',
      'spellbook',
      'weapons',
      'inventory',
    }, 'root');
    if (_int(json, 'schemaVersion', 'root') != 1) {
      throw const FormatException('不支持的 AI 建卡响应版本');
    }
    final classesRaw = _list(json, 'classes', 'root');
    if (classesRaw.isEmpty || classesRaw.length > 4) {
      throw const FormatException('职业组成必须包含 1–4 项');
    }
    final classes = <AiClassLevel>[];
    for (var index = 0; index < classesRaw.length; index++) {
      classes.add(
        AiClassLevel.fromJson(
          _asMap(classesRaw[index], 'classes[$index]'),
          'classes[$index]',
        ),
      );
    }

    return AiCharacterDraft(
      classes: classes,
      abilities: AiAbilityBreakdown.fromJson(_map(json, 'abilities', 'root')),
      profile: _parseProfile(_map(json, 'profile', 'root')),
      combat: _parseCombat(_map(json, 'combat', 'root')),
      proficiencies: _parseProficiencies(_map(json, 'proficiencies', 'root')),
      roleplay: _parseRoleplay(_map(json, 'roleplay', 'root')),
      spellbook: _parseSpellbook(_map(json, 'spellbook', 'root')),
      weapons: _parseWeapons(_list(json, 'weapons', 'root')),
      inventory: _parseInventory(_map(json, 'inventory', 'root')),
    );
  }

  List<String> validate(AiCharacterBuildRequest request) {
    final errors = <String>[];
    final totalClassLevel = classes.fold<int>(
      0,
      (total, item) => total + item.level,
    );
    if (classes.any((item) => item.level < 1 || item.level > 20) ||
        totalClassLevel != request.totalLevel) {
      errors.add('职业等级之和必须等于 ${request.totalLevel}');
    }
    errors.addAll(abilities.validate(request.abilitySpec));
    final resolvedCharacterName =
        request.requirements.mode == AiBuildRequirementMode.exactChoices
        ? request.requirements.characterName
        : profile.characterName;
    if (resolvedCharacterName.trim().isEmpty) errors.add('角色姓名不能为空');
    if (profile.race.trim().isEmpty) errors.add('角色种族不能为空');
    if (profile.classAndLevel.trim().isEmpty) errors.add('职业与等级不能为空');
    if (combat.hitPointsMax < 1) errors.add('最大生命值必须大于 0');
    if (weapons.length > 20) errors.add('武器数量不能超过 20');
    return errors;
  }

  Character toCharacter(AiCharacterBuildRequest request) {
    final errors = validate(request);
    if (errors.isNotEmpty) throw AiDraftValidationException(errors);

    final normalizedProfile = Profile(
      characterName:
          request.requirements.mode == AiBuildRequirementMode.exactChoices
          ? request.requirements.characterName.trim()
          : profile.characterName,
      playerName: '',
      race: profile.race,
      classAndLevel: profile.classAndLevel,
      background: profile.background,
      alignment: profile.alignment,
      experiencePoints: profile.experiencePoints,
      inspiration: '',
      proficiencyBonus: 2 + ((request.totalLevel - 1) ~/ 4),
      passivePerception: profile.passivePerception,
      age: _appearanceValue(request, 'age', profile.age),
      height: _appearanceValue(request, 'height', profile.height),
      weight: _appearanceValue(request, 'weight', profile.weight),
      eyes: _appearanceValue(request, 'eyes', profile.eyes),
      skin: _appearanceValue(request, 'skin', profile.skin),
      hair: _appearanceValue(request, 'hair', profile.hair),
      portraitBase64: '',
    );
    final normalizedCombat = CombatStats(
      armorClass: combat.armorClass,
      initiative: combat.initiative,
      speed: combat.speed,
      hitPointsMax: combat.hitPointsMax,
      hitPointsCurrent: combat.hitPointsMax,
      hitPointsTemp: 0,
      hitDiceTotal: combat.hitDiceTotal,
      hitDiceCurrent: combat.hitDiceTotal,
      attacksAndSpellcastingNotes: combat.attacksAndSpellcastingNotes,
      ability: combat.ability,
    );
    final normalizedRoleplay = Roleplay(
      personalityTraits: _narrativeValue(
        request,
        'personalityTraits',
        roleplay.personalityTraits,
      ),
      ideals: _narrativeValue(request, 'ideals', roleplay.ideals),
      bonds: _narrativeValue(request, 'bonds', roleplay.bonds),
      flaws: _narrativeValue(request, 'flaws', roleplay.flaws),
      characterBackstory: _narrativeValue(
        request,
        'characterBackstory',
        roleplay.characterBackstory,
      ),
      alliesAndOrganizations: _narrativeValue(
        request,
        'alliesAndOrganizations',
        roleplay.alliesAndOrganizations,
      ),
      additionalFeaturesAndTraits: _appearanceValue(
        request,
        'additionalFeaturesAndTraits',
        roleplay.additionalFeaturesAndTraits,
      ),
      treasure: _narrativeValue(request, 'treasure', roleplay.treasure),
      characterExperience: _narrativeValue(request, 'characterExperience', ''),
    );
    final normalizedSpellbook = Spellbook(
      spellcastingClass: spellbook.spellcastingClass,
      spellcastingAbility: spellbook.spellcastingAbility,
      spellSaveDC: spellbook.spellSaveDC,
      spellAttackBonus: spellbook.spellAttackBonus,
      allSpells: spellbook.allSpells
          .map((group) {
            return SpellLevelGroup(
              level: group.level,
              totalSlots: group.totalSlots,
              remainSlots: group.totalSlots,
              spells: group.spells,
            );
          })
          .toList(growable: false),
    );

    return Character(
      profile: normalizedProfile,
      attributes: Attributes(
        strength: abilities.finalScores.strength,
        dexterity: abilities.finalScores.dexterity,
        constitution: abilities.finalScores.constitution,
        intelligence: abilities.finalScores.intelligence,
        wisdom: abilities.finalScores.wisdom,
        charisma: abilities.finalScores.charisma,
      ),
      combat: normalizedCombat,
      proficiencies: proficiencies,
      roleplay: normalizedRoleplay,
      spellbook: normalizedSpellbook,
      weapons: weapons.isEmpty ? [Weapon(), Weapon(), Weapon()] : weapons,
      inventory: inventory,
    );
  }
}

class AiDraftValidationException implements Exception {
  const AiDraftValidationException(this.errors);

  final List<String> errors;

  @override
  String toString() => errors.join('；');
}

String _appearanceValue(
  AiCharacterBuildRequest request,
  String key,
  String generated,
) {
  if (request.roleplay.omit) return '';
  return request.roleplay.appearanceAiDecides
      ? generated
      : request.roleplay.appearanceValue(key);
}

String _narrativeValue(
  AiCharacterBuildRequest request,
  String key,
  String generated,
) {
  if (request.roleplay.omit) return '';
  if (key == 'characterExperience' && request.roleplay.narrativeAiDecides) {
    return '';
  }
  return request.roleplay.narrativeAiDecides
      ? generated
      : request.roleplay.narrativeValue(key);
}

Profile _parseProfile(Map<String, dynamic> json) {
  const keys = {
    'characterName',
    'race',
    'classAndLevel',
    'background',
    'alignment',
    'experiencePoints',
    'passivePerception',
    'age',
    'height',
    'weight',
    'eyes',
    'skin',
    'hair',
  };
  _checkKeys(json, keys, 'profile');
  return Profile(
    characterName: _string(json, 'characterName', 'profile'),
    race: _string(json, 'race', 'profile'),
    classAndLevel: _string(json, 'classAndLevel', 'profile'),
    background: _string(json, 'background', 'profile'),
    alignment: _string(json, 'alignment', 'profile'),
    experiencePoints: _int(json, 'experiencePoints', 'profile'),
    passivePerception: _int(json, 'passivePerception', 'profile'),
    age: _string(json, 'age', 'profile'),
    height: _string(json, 'height', 'profile'),
    weight: _string(json, 'weight', 'profile'),
    eyes: _string(json, 'eyes', 'profile'),
    skin: _string(json, 'skin', 'profile'),
    hair: _string(json, 'hair', 'profile'),
  );
}

CombatStats _parseCombat(Map<String, dynamic> json) {
  const keys = {
    'armorClass',
    'initiative',
    'speed',
    'hitPointsMax',
    'hitDiceTotal',
    'attacksAndSpellcastingNotes',
    'ability',
  };
  _checkKeys(json, keys, 'combat');
  return CombatStats(
    armorClass: _int(json, 'armorClass', 'combat'),
    initiative: _int(json, 'initiative', 'combat'),
    speed: _string(json, 'speed', 'combat'),
    hitPointsMax: _int(json, 'hitPointsMax', 'combat'),
    hitDiceTotal: _string(json, 'hitDiceTotal', 'combat'),
    attacksAndSpellcastingNotes: _string(
      json,
      'attacksAndSpellcastingNotes',
      'combat',
    ),
    ability: _string(json, 'ability', 'combat'),
  );
}

Proficiencies _parseProficiencies(Map<String, dynamic> json) {
  const boolKeys = {
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
  _checkKeys(json, {
    ...boolKeys,
    'otherProficienciesAndLanguages',
  }, 'proficiencies');
  bool flag(String key) => _bool(json, key, 'proficiencies');
  return Proficiencies(
    strengthSave: flag('strengthSave'),
    dexteritySave: flag('dexteritySave'),
    constitutionSave: flag('constitutionSave'),
    intelligenceSave: flag('intelligenceSave'),
    wisdomSave: flag('wisdomSave'),
    charismaSave: flag('charismaSave'),
    athletics: flag('athletics'),
    acrobatics: flag('acrobatics'),
    sleightOfHand: flag('sleightOfHand'),
    stealth: flag('stealth'),
    arcana: flag('arcana'),
    history: flag('history'),
    investigation: flag('investigation'),
    nature: flag('nature'),
    religion: flag('religion'),
    animalHandling: flag('animalHandling'),
    insight: flag('insight'),
    medicine: flag('medicine'),
    perception: flag('perception'),
    survival: flag('survival'),
    deception: flag('deception'),
    intimidation: flag('intimidation'),
    performance: flag('performance'),
    persuasion: flag('persuasion'),
    otherProficienciesAndLanguages: _string(
      json,
      'otherProficienciesAndLanguages',
      'proficiencies',
    ),
  );
}

Roleplay _parseRoleplay(Map<String, dynamic> json) {
  if (json.containsKey('characterExperience')) {
    throw const FormatException('roleplay 包含不属于 AI 响应契约的字段');
  }
  const keys = {
    'personalityTraits',
    'ideals',
    'bonds',
    'flaws',
    'characterBackstory',
    'alliesAndOrganizations',
    'additionalFeaturesAndTraits',
    'treasure',
  };
  _checkKeys(json, keys, 'roleplay');
  String value(String key) => _string(json, key, 'roleplay');
  return Roleplay(
    personalityTraits: value('personalityTraits'),
    ideals: value('ideals'),
    bonds: value('bonds'),
    flaws: value('flaws'),
    characterBackstory: value('characterBackstory'),
    alliesAndOrganizations: value('alliesAndOrganizations'),
    additionalFeaturesAndTraits: value('additionalFeaturesAndTraits'),
    treasure: value('treasure'),
  );
}

Spellbook _parseSpellbook(Map<String, dynamic> json) {
  const keys = {
    'spellcastingClass',
    'spellcastingAbility',
    'spellSaveDC',
    'spellAttackBonus',
    'groups',
  };
  _checkKeys(json, keys, 'spellbook');
  final groups = <int, SpellLevelGroup>{};
  final rawGroups = _list(json, 'groups', 'spellbook');
  if (rawGroups.length > 10) throw const FormatException('法术环级分组不能超过 10 组');
  for (var index = 0; index < rawGroups.length; index++) {
    final path = 'spellbook.groups[$index]';
    final map = _asMap(rawGroups[index], path);
    _checkKeys(map, const {'level', 'totalSlots', 'spells'}, path);
    final level = _int(map, 'level', path);
    if (level < 0 || level > 9 || groups.containsKey(level)) {
      throw FormatException('$path 的环级无效或重复');
    }
    final spellsRaw = _list(map, 'spells', path);
    final defaultGroup = SpellLevelGroup.initDefault(level);
    if (spellsRaw.length > defaultGroup.spells.length) {
      throw FormatException('$path 的法术数量超过编辑器固定空位数');
    }
    final spells = <Spell>[];
    for (var spellIndex = 0; spellIndex < spellsRaw.length; spellIndex++) {
      final spellPath = '$path.spells[$spellIndex]';
      final spellMap = _asMap(spellsRaw[spellIndex], spellPath);
      _checkKeys(spellMap, const {'name', 'isPrepared'}, spellPath);
      spells.add(
        Spell(
          name: _string(spellMap, 'name', spellPath),
          isPrepared: _bool(spellMap, 'isPrepared', spellPath),
        ),
      );
    }
    final totalSlots = _int(map, 'totalSlots', path);
    if (totalSlots < 0 || totalSlots > 20) {
      throw FormatException('$path 的法术位数量无效');
    }
    groups[level] = SpellLevelGroup(
      level: level,
      totalSlots: totalSlots,
      remainSlots: totalSlots,
      spells: [
        ...spells,
        ...List.generate(
          defaultGroup.spells.length - spells.length,
          (_) => Spell(),
        ),
      ],
    );
  }
  return Spellbook(
    spellcastingClass: _string(json, 'spellcastingClass', 'spellbook'),
    spellcastingAbility: _string(json, 'spellcastingAbility', 'spellbook'),
    spellSaveDC: _int(json, 'spellSaveDC', 'spellbook'),
    spellAttackBonus: _int(json, 'spellAttackBonus', 'spellbook'),
    allSpells: List.generate(
      10,
      (level) => groups[level] ?? SpellLevelGroup.initDefault(level),
    ),
  );
}

List<Weapon> _parseWeapons(List<dynamic> raw) {
  if (raw.length > 20) throw const FormatException('武器数量不能超过 20');
  return List.generate(raw.length, (index) {
    final path = 'weapons[$index]';
    final map = _asMap(raw[index], path);
    _checkKeys(map, const {'name', 'attackBonus', 'damage'}, path);
    return Weapon(
      name: _string(map, 'name', path),
      attackBonus: _int(map, 'attackBonus', path),
      damage: _string(map, 'damage', path),
    );
  });
}

Inventory _parseInventory(Map<String, dynamic> json) {
  const keys = {'cp', 'sp', 'ep', 'gp', 'pp', 'equipmentText'};
  _checkKeys(json, keys, 'inventory');
  return Inventory(
    cP: _int(json, 'cp', 'inventory'),
    sP: _int(json, 'sp', 'inventory'),
    eP: _int(json, 'ep', 'inventory'),
    gP: _int(json, 'gp', 'inventory'),
    pP: _int(json, 'pp', 'inventory'),
    equipmentText: _string(json, 'equipmentText', 'inventory'),
  );
}

bool _sameMultiset(List<int> left, List<int> right) {
  final a = [...left]..sort();
  final b = [...right]..sort();
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

void _checkKeys(Map<String, dynamic> json, Set<String> allowed, String path) {
  final unknown = json.keys.where((key) => !allowed.contains(key)).toList();
  if (unknown.isNotEmpty) {
    throw FormatException('$path 包含未知字段：${unknown.join(', ')}');
  }
  final missing = allowed.where((key) => !json.containsKey(key)).toList();
  if (missing.isNotEmpty) {
    throw FormatException('$path 缺少字段：${missing.join(', ')}');
  }
}

Map<String, dynamic> _map(Map<String, dynamic> json, String key, String path) =>
    _asMap(json[key], '$path.$key');

Map<String, dynamic> _asMap(Object? value, String path) {
  if (value is! Map) throw FormatException('$path 必须是对象');
  return Map<String, dynamic>.from(value);
}

List<dynamic> _list(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! List) throw FormatException('$path.$key 必须是数组');
  return value;
}

String _string(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! String) throw FormatException('$path.$key 必须是字符串');
  return value.trim();
}

String _nonEmptyString(Map<String, dynamic> json, String key, String path) {
  final value = _string(json, key, path);
  if (value.isEmpty) throw FormatException('$path.$key 不能为空');
  return value;
}

int _int(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! int) throw FormatException('$path.$key 必须是整数');
  return value;
}

bool _bool(Map<String, dynamic> json, String key, String path) {
  final value = json[key];
  if (value is! bool) throw FormatException('$path.$key 必须是布尔值');
  return value;
}

enum AiGenerationStage { plan, mechanics, derived, narrative }

extension AiGenerationStageLabel on AiGenerationStage {
  String get label => switch (this) {
    AiGenerationStage.plan => '设计构筑方案',
    AiGenerationStage.mechanics => '细化构筑方案',
    AiGenerationStage.derived => '计算衍生数值',
    AiGenerationStage.narrative => '塑造人物',
  };

  int get number => index + 1;
}

class AiBuildPlanClass {
  const AiBuildPlanClass({
    required this.name,
    required this.level,
    required this.subclass,
  });

  final String name;
  final int level;
  final String subclass;

  factory AiBuildPlanClass.fromJson(Map<String, dynamic> json, String path) {
    _checkKeys(json, const {'name', 'level', 'subclass'}, path);
    return AiBuildPlanClass(
      name: _nonEmptyString(json, 'name', path),
      level: _int(json, 'level', path),
      subclass: _string(json, 'subclass', path),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'level': level,
    'subclass': subclass,
  };
}

class AiBuildPlan {
  const AiBuildPlan({
    this.characterName = '',
    this.alignment = '',
    required this.classes,
    required this.raceAndSubrace,
    required this.background,
    required this.combatRole,
    required this.adventureRole,
    required this.synergy,
    required this.warnings,
  });

  final String characterName;
  final String alignment;
  final List<AiBuildPlanClass> classes;
  final String raceAndSubrace;
  final String background;
  final String combatRole;
  final String adventureRole;
  final String synergy;
  final String warnings;

  factory AiBuildPlan.fromJson(
    Map<String, dynamic> json, {
    bool includesIdentity = false,
  }) {
    _checkKeys(json, {
      'schemaVersion',
      if (includesIdentity) 'characterName',
      if (includesIdentity) 'alignment',
      'classes',
      'raceAndSubrace',
      'background',
      'combatRole',
      'adventureRole',
      'synergy',
      'warnings',
    }, 'plan');
    if (_int(json, 'schemaVersion', 'plan') != 1) {
      throw const FormatException('不支持的构筑方案响应版本');
    }
    final rawClasses = _list(json, 'classes', 'plan');
    if (rawClasses.isEmpty || rawClasses.length > 4) {
      throw const FormatException('构筑方案必须包含 1–4 个职业');
    }
    return AiBuildPlan(
      characterName: includesIdentity
          ? _nonEmptyString(json, 'characterName', 'plan')
          : '',
      alignment: includesIdentity
          ? _nonEmptyString(json, 'alignment', 'plan')
          : '',
      classes: List.generate(
        rawClasses.length,
        (index) => AiBuildPlanClass.fromJson(
          _asMap(rawClasses[index], 'plan.classes[$index]'),
          'plan.classes[$index]',
        ),
      ),
      raceAndSubrace: _nonEmptyString(json, 'raceAndSubrace', 'plan'),
      background: _nonEmptyString(json, 'background', 'plan'),
      combatRole: _nonEmptyString(json, 'combatRole', 'plan'),
      adventureRole: _nonEmptyString(json, 'adventureRole', 'plan'),
      synergy: _string(json, 'synergy', 'plan'),
      warnings: _string(json, 'warnings', 'plan'),
    );
  }

  List<String> validate(int totalLevel, {bool requireIdentity = false}) {
    final errors = <String>[];
    if (requireIdentity && characterName.trim().isEmpty) errors.add('角色姓名不能为空');
    if (requireIdentity && alignment.trim().isEmpty) errors.add('阵营不能为空');
    if (classes.isEmpty || classes.length > 4) errors.add('职业组成必须包含 1–4 项');
    if (classes.any((item) => item.name.trim().isEmpty)) errors.add('职业名称不能为空');
    if (classes.any((item) => item.level < 1 || item.level > 20) ||
        classes.fold<int>(0, (sum, item) => sum + item.level) != totalLevel) {
      errors.add('职业等级之和必须等于 $totalLevel');
    }
    if (raceAndSubrace.trim().isEmpty) errors.add('种族不能为空');
    if (background.trim().isEmpty) errors.add('背景不能为空');
    if (combatRole.trim().isEmpty) errors.add('战斗定位不能为空');
    if (adventureRole.trim().isEmpty) errors.add('冒险定位不能为空');
    return errors;
  }

  String get classAndLevel => classes
      .map((item) {
        final subclass = item.subclass.trim().isEmpty
            ? ''
            : '（${item.subclass.trim()}）';
        return '${item.name.trim()}$subclass ${item.level}';
      })
      .join(' / ');

  Map<String, dynamic> toJson() => {
    'classes': classes.map((item) => item.toJson()).toList(),
    'raceAndSubrace': raceAndSubrace,
    'background': background,
    'combatRole': combatRole,
    'adventureRole': adventureRole,
    'synergy': synergy,
    'warnings': warnings,
  };

  Map<String, dynamic> toNarrativePromptJson() => {
    ...toJson(),
    'alignment': alignment,
  };
}

class AiMechanicSpellGroup {
  const AiMechanicSpellGroup({required this.level, required this.spells});

  final int level;
  final List<Spell> spells;
}

class AiMechanicsDraft {
  const AiMechanicsDraft({
    required this.abilities,
    required this.advancementChoices,
    required this.proficiencies,
    required this.specialAbilities,
    required this.attacksAndSpellcastingNotes,
    required this.spellcastingClass,
    required this.spellcastingAbility,
    required this.spellGroups,
    required this.weaponNames,
    required this.inventory,
  });

  final AiAbilityBreakdown abilities;
  final String advancementChoices;
  final Proficiencies proficiencies;
  final String specialAbilities;
  final String attacksAndSpellcastingNotes;
  final String spellcastingClass;
  final String spellcastingAbility;
  final List<AiMechanicSpellGroup> spellGroups;
  final List<String> weaponNames;
  final Inventory inventory;

  factory AiMechanicsDraft.fromJson(Map<String, dynamic> json) {
    _checkKeys(json, const {
      'schemaVersion',
      'abilities',
      'proficiencies',
      'specialAbilities',
      'attacksAndSpellcastingNotes',
      'spellcasting',
      'weapons',
      'inventory',
    }, 'mechanics');
    if (_int(json, 'schemaVersion', 'mechanics') != 1) {
      throw const FormatException('不支持的机械选择响应版本');
    }
    final abilitiesJson = _map(json, 'abilities', 'mechanics');
    _checkKeys(abilitiesJson, const {
      'baseAbilities',
      'racialBonuses',
      'advancementAdjustments',
      'advancementChoices',
    }, 'mechanics.abilities');
    final base = AbilityScores.fromJson(
      _map(abilitiesJson, 'baseAbilities', 'mechanics.abilities'),
      'mechanics.abilities.baseAbilities',
    );
    final racial = AbilityScores.fromJson(
      _map(abilitiesJson, 'racialBonuses', 'mechanics.abilities'),
      'mechanics.abilities.racialBonuses',
    );
    final advancement = AbilityScores.fromJson(
      _map(abilitiesJson, 'advancementAdjustments', 'mechanics.abilities'),
      'mechanics.abilities.advancementAdjustments',
    );
    final finalScores = AbilityScores(
      strength: base.strength + racial.strength + advancement.strength,
      dexterity: base.dexterity + racial.dexterity + advancement.dexterity,
      constitution:
          base.constitution + racial.constitution + advancement.constitution,
      intelligence:
          base.intelligence + racial.intelligence + advancement.intelligence,
      wisdom: base.wisdom + racial.wisdom + advancement.wisdom,
      charisma: base.charisma + racial.charisma + advancement.charisma,
    );
    final spellcasting = _map(json, 'spellcasting', 'mechanics');
    _checkKeys(spellcasting, const {
      'class',
      'ability',
      'groups',
    }, 'mechanics.spellcasting');
    final rawGroups = _list(spellcasting, 'groups', 'mechanics.spellcasting');
    if (rawGroups.length > 10) throw const FormatException('法术环级分组不能超过 10 组');
    final seenLevels = <int>{};
    final groups = <AiMechanicSpellGroup>[];
    for (var index = 0; index < rawGroups.length; index++) {
      final path = 'mechanics.spellcasting.groups[$index]';
      final group = _asMap(rawGroups[index], path);
      _checkKeys(group, const {'level', 'spells'}, path);
      final level = _int(group, 'level', path);
      if (level < 0 || level > 9 || !seenLevels.add(level)) {
        throw FormatException('$path 的环级无效或重复');
      }
      final rawSpells = _list(group, 'spells', path);
      final capacity = SpellLevelGroup.initDefault(level).spells.length;
      if (rawSpells.length > capacity) {
        throw FormatException('$path 的法术数量超过编辑器容量');
      }
      groups.add(
        AiMechanicSpellGroup(
          level: level,
          spells: List.generate(rawSpells.length, (spellIndex) {
            final spellPath = '$path.spells[$spellIndex]';
            final spell = _asMap(rawSpells[spellIndex], spellPath);
            _checkKeys(spell, const {'name', 'isPrepared'}, spellPath);
            return Spell(
              name: _nonEmptyString(spell, 'name', spellPath),
              isPrepared: _bool(spell, 'isPrepared', spellPath),
            );
          }),
        ),
      );
    }
    final rawWeapons = _list(json, 'weapons', 'mechanics');
    if (rawWeapons.length > 20) throw const FormatException('武器数量不能超过 20');
    return AiMechanicsDraft(
      abilities: AiAbilityBreakdown(
        base: base,
        racialBonuses: racial,
        advancementAdjustments: advancement,
        finalScores: finalScores,
      ),
      advancementChoices: _string(
        abilitiesJson,
        'advancementChoices',
        'mechanics.abilities',
      ),
      proficiencies: _parseProficiencies(
        _map(json, 'proficiencies', 'mechanics'),
      ),
      specialAbilities: _string(json, 'specialAbilities', 'mechanics'),
      attacksAndSpellcastingNotes: _string(
        json,
        'attacksAndSpellcastingNotes',
        'mechanics',
      ),
      spellcastingClass: _string(
        spellcasting,
        'class',
        'mechanics.spellcasting',
      ),
      spellcastingAbility: _string(
        spellcasting,
        'ability',
        'mechanics.spellcasting',
      ),
      spellGroups: groups,
      weaponNames: List.generate(rawWeapons.length, (index) {
        final path = 'mechanics.weapons[$index]';
        final weapon = _asMap(rawWeapons[index], path);
        _checkKeys(weapon, const {'name'}, path);
        return _nonEmptyString(weapon, 'name', path);
      }),
      inventory: _parseInventory(_map(json, 'inventory', 'mechanics')),
    );
  }

  List<String> validate(AiAbilitySpec spec) => abilities.validate(spec);

  Map<String, dynamic> toPromptJson() => {
    'abilities': {
      'baseAbilities': _scoresJson(abilities.base),
      'racialBonuses': _scoresJson(abilities.racialBonuses),
      'advancementAdjustments': _scoresJson(abilities.advancementAdjustments),
      'finalAbilities': _scoresJson(abilities.finalScores),
      'advancementChoices': advancementChoices,
    },
    'proficiencies': _proficienciesJson(proficiencies),
    'specialAbilities': specialAbilities,
    'attacksAndSpellcastingNotes': attacksAndSpellcastingNotes,
    'spellcasting': {
      'class': spellcastingClass,
      'ability': spellcastingAbility,
      'groups': spellGroups
          .map(
            (group) => {
              'level': group.level,
              'spells': group.spells
                  .map(
                    (spell) => {
                      'name': spell.name,
                      'isPrepared': spell.isPrepared,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    },
    'weapons': weaponNames,
    'inventory': {
      'cp': inventory.cP,
      'sp': inventory.sP,
      'ep': inventory.eP,
      'gp': inventory.gP,
      'pp': inventory.pP,
      'equipmentText': inventory.equipmentText,
    },
  };
}

class AiDerivedWeapon {
  const AiDerivedWeapon({required this.attackBonus, required this.damage});
  final int attackBonus;
  final String damage;
}

class AiDerivedCalculationCheck {
  const AiDerivedCalculationCheck({
    required this.field,
    required this.base,
    required this.adjustments,
    required this.finalValue,
  });

  final String field;
  final int base;
  final List<int> adjustments;
  final int finalValue;

  factory AiDerivedCalculationCheck.fromJson(
    Map<String, dynamic> json,
    String path,
  ) {
    _checkKeys(json, const {
      'field',
      'base',
      'adjustments',
      'finalValue',
    }, path);
    final rawAdjustments = _list(json, 'adjustments', path);
    return AiDerivedCalculationCheck(
      field: _nonEmptyString(json, 'field', path),
      base: _int(json, 'base', path),
      adjustments: List.generate(rawAdjustments.length, (index) {
        final value = rawAdjustments[index];
        if (value is! int) {
          throw FormatException('$path.adjustments[$index] 必须是整数');
        }
        return value;
      }),
      finalValue: _int(json, 'finalValue', path),
    );
  }

  bool get sumIsConsistent =>
      base + adjustments.fold<int>(0, (sum, value) => sum + value) ==
      finalValue;
}

class AiDerivedDraft {
  const AiDerivedDraft({
    required this.experiencePoints,
    required this.passivePerception,
    required this.armorClass,
    required this.initiative,
    required this.speed,
    required this.hitPointsMax,
    required this.hitDiceTotal,
    required this.spellSaveDC,
    required this.spellAttackBonus,
    required this.spellSlots,
    required this.weapons,
    required this.specialAbilityNumericNotes,
    required this.calculationChecks,
    required this.valueExplanations,
  });

  final int experiencePoints;
  final int passivePerception;
  final int armorClass;
  final int initiative;
  final String speed;
  final int hitPointsMax;
  final String hitDiceTotal;
  final int spellSaveDC;
  final int spellAttackBonus;
  final Map<int, int> spellSlots;
  final List<AiDerivedWeapon> weapons;
  final String specialAbilityNumericNotes;
  final List<AiDerivedCalculationCheck> calculationChecks;
  final List<String> valueExplanations;

  factory AiDerivedDraft.fromJson(Map<String, dynamic> json) {
    _checkKeys(json, const {
      'schemaVersion',
      'experiencePoints',
      'passivePerception',
      'armorClass',
      'initiative',
      'speed',
      'hitPointsMax',
      'hitDiceTotal',
      'spellSaveDC',
      'spellAttackBonus',
      'spellSlots',
      'weapons',
      'specialAbilityNumericNotes',
      'calculationChecks',
      'valueExplanations',
    }, 'derived');
    if (_int(json, 'schemaVersion', 'derived') != 1) {
      throw const FormatException('不支持的衍生数值响应版本');
    }
    final slots = <int, int>{};
    final rawSlots = _list(json, 'spellSlots', 'derived');
    for (var index = 0; index < rawSlots.length; index++) {
      final path = 'derived.spellSlots[$index]';
      final slot = _asMap(rawSlots[index], path);
      _checkKeys(slot, const {'level', 'totalSlots'}, path);
      final level = _int(slot, 'level', path);
      final total = _int(slot, 'totalSlots', path);
      if (level < 1 || level > 9 || slots.containsKey(level)) {
        throw FormatException('$path 的环级无效或重复');
      }
      if (total < 0 || total > 20) throw FormatException('$path 的法术位数量无效');
      slots[level] = total;
    }
    final rawWeapons = _list(json, 'weapons', 'derived');
    final rawChecks = _list(json, 'calculationChecks', 'derived');
    final rawExplanations = _list(json, 'valueExplanations', 'derived');
    return AiDerivedDraft(
      experiencePoints: _int(json, 'experiencePoints', 'derived'),
      passivePerception: _int(json, 'passivePerception', 'derived'),
      armorClass: _int(json, 'armorClass', 'derived'),
      initiative: _int(json, 'initiative', 'derived'),
      speed: _string(json, 'speed', 'derived'),
      hitPointsMax: _int(json, 'hitPointsMax', 'derived'),
      hitDiceTotal: _nonEmptyString(json, 'hitDiceTotal', 'derived'),
      spellSaveDC: _int(json, 'spellSaveDC', 'derived'),
      spellAttackBonus: _int(json, 'spellAttackBonus', 'derived'),
      spellSlots: slots,
      weapons: List.generate(rawWeapons.length, (index) {
        final path = 'derived.weapons[$index]';
        final weapon = _asMap(rawWeapons[index], path);
        _checkKeys(weapon, const {'attackBonus', 'damage'}, path);
        return AiDerivedWeapon(
          attackBonus: _int(weapon, 'attackBonus', path),
          damage: _nonEmptyString(weapon, 'damage', path),
        );
      }),
      specialAbilityNumericNotes: _string(
        json,
        'specialAbilityNumericNotes',
        'derived',
      ),
      calculationChecks: List.generate(
        rawChecks.length,
        (index) => AiDerivedCalculationCheck.fromJson(
          _asMap(rawChecks[index], 'derived.calculationChecks[$index]'),
          'derived.calculationChecks[$index]',
        ),
      ),
      valueExplanations: List.generate(rawExplanations.length, (index) {
        final value = rawExplanations[index];
        if (value is! String) {
          throw FormatException('derived.valueExplanations[$index] 必须是字符串');
        }
        return value.trim();
      }),
    );
  }

  List<String> validate(AiMechanicsDraft mechanics) {
    final errors = <String>[];
    if (hitPointsMax < 1) errors.add('最大生命值必须大于 0');
    if (experiencePoints < 0) errors.add('经验值不能为负数');
    if (weapons.length != mechanics.weaponNames.length) {
      errors.add('武器衍生数值必须与机械选择中的武器数量一致');
    }
    final expected = <String, int>{
      'passivePerception': passivePerception,
      'armorClass': armorClass,
      'initiative': initiative,
      'hitPointsMax': hitPointsMax,
      'spellSaveDC': spellSaveDC,
      'spellAttackBonus': spellAttackBonus,
      for (final entry in spellSlots.entries)
        'spellSlot:${entry.key}': entry.value,
      for (var index = 0; index < weapons.length; index++)
        'weaponAttackBonus:$index': weapons[index].attackBonus,
    };
    final seen = <String>{};
    for (final check in calculationChecks) {
      final finalValue = expected[check.field];
      if (finalValue == null) {
        errors.add('数值组成包含未知字段 ${check.field}');
      } else if (!seen.add(check.field)) {
        errors.add('数值组成重复了 ${check.field}');
      } else {
        if (!check.sumIsConsistent) {
          errors.add('${check.field} 的数值组成加法不一致');
        }
        if (check.finalValue != finalValue) {
          errors.add('${check.field} 的最终值与角色数值不一致');
        }
      }
    }
    final missing = expected.keys.where((key) => !seen.contains(key));
    if (missing.isNotEmpty) {
      errors.add('数值组成缺少：${missing.join('、')}');
    }
    return errors;
  }
}

enum AiNarrativeScope { appearance, personalityAndBackground, all }

class AiNarrativeDraft {
  const AiNarrativeDraft({required this.values});

  final Map<String, String> values;

  factory AiNarrativeDraft.fromJson(
    Map<String, dynamic> json,
    AiNarrativeScope scope,
  ) {
    final fields = switch (scope) {
      AiNarrativeScope.appearance => aiAppearanceKeys.toSet(),
      AiNarrativeScope.personalityAndBackground => aiNarrativeKeys.toSet(),
      AiNarrativeScope.all => {...aiAppearanceKeys, ...aiNarrativeKeys},
    };
    _checkKeys(json, {'schemaVersion', ...fields}, 'narrative');
    if (_int(json, 'schemaVersion', 'narrative') != 1) {
      throw const FormatException('不支持的人物塑造响应版本');
    }
    return AiNarrativeDraft(
      values: {for (final key in fields) key: _string(json, key, 'narrative')},
    );
  }

  static const empty = AiNarrativeDraft(values: {});
}

class AiCharacterAssembly {
  static Character toCharacter({
    required AiCharacterBuildRequest request,
    required AiBuildPlan plan,
    required AiMechanicsDraft mechanics,
    required AiDerivedDraft derived,
    required AiNarrativeDraft narrative,
  }) {
    final mechanicalErrors = mechanics.validate(request.abilitySpec);
    final derivedErrors = derived.validate(mechanics);
    final planErrors = plan.validate(request.totalLevel);
    final errors = [...planErrors, ...mechanicalErrors, ...derivedErrors];
    if (errors.isNotEmpty) throw AiDraftValidationException(errors);

    String appearance(String key) {
      if (request.roleplay.omit) return '';
      return request.roleplay.appearanceAiDecides
          ? (narrative.values[key] ?? '')
          : request.roleplay.appearanceValue(key);
    }

    String roleplay(String key) {
      if (request.roleplay.omit) return '';
      return request.roleplay.narrativeAiDecides
          ? (narrative.values[key] ?? '')
          : request.roleplay.narrativeValue(key);
    }

    final generatedName =
        request.requirements.mode == AiBuildRequirementMode.exactChoices
        ? request.requirements.characterName.trim()
        : plan.characterName.trim();
    final generatedAlignment =
        request.requirements.mode == AiBuildRequirementMode.exactChoices
        ? request.requirements.alignment.trim()
        : plan.alignment.trim();
    if (generatedName.isEmpty) {
      throw const AiDraftValidationException(['角色姓名不能为空']);
    }

    final ability = [
      mechanics.specialAbilities.trim(),
      derived.specialAbilityNumericNotes.trim(),
    ].where((value) => value.isNotEmpty).join('\n\n');
    final groupsByLevel = {
      for (final group in mechanics.spellGroups) group.level: group,
    };
    final spellGroups = List.generate(10, (level) {
      final defaultGroup = SpellLevelGroup.initDefault(level);
      final chosen = groupsByLevel[level]?.spells ?? const <Spell>[];
      return SpellLevelGroup(
        level: level,
        totalSlots: derived.spellSlots[level] ?? 0,
        remainSlots: derived.spellSlots[level] ?? 0,
        spells: [
          ...chosen,
          ...List.generate(
            defaultGroup.spells.length - chosen.length,
            (_) => Spell(),
          ),
        ],
      );
    });
    final weapons = List.generate(mechanics.weaponNames.length, (index) {
      final values = derived.weapons[index];
      return Weapon(
        name: mechanics.weaponNames[index],
        attackBonus: values.attackBonus,
        damage: values.damage,
      );
    });

    return Character(
      profile: Profile(
        characterName: generatedName,
        playerName: '',
        race: plan.raceAndSubrace,
        classAndLevel: plan.classAndLevel,
        background: plan.background,
        alignment: generatedAlignment,
        experiencePoints: derived.experiencePoints,
        inspiration: '',
        proficiencyBonus: 2 + ((request.totalLevel - 1) ~/ 4),
        passivePerception: derived.passivePerception,
        age: appearance('age'),
        height: appearance('height'),
        weight: appearance('weight'),
        eyes: appearance('eyes'),
        skin: appearance('skin'),
        hair: appearance('hair'),
        portraitBase64: '',
      ),
      attributes: Attributes(
        strength: mechanics.abilities.finalScores.strength,
        dexterity: mechanics.abilities.finalScores.dexterity,
        constitution: mechanics.abilities.finalScores.constitution,
        intelligence: mechanics.abilities.finalScores.intelligence,
        wisdom: mechanics.abilities.finalScores.wisdom,
        charisma: mechanics.abilities.finalScores.charisma,
      ),
      combat: CombatStats(
        armorClass: derived.armorClass,
        initiative: derived.initiative,
        speed: derived.speed,
        hitPointsMax: derived.hitPointsMax,
        hitPointsCurrent: derived.hitPointsMax,
        hitPointsTemp: 0,
        hitDiceTotal: derived.hitDiceTotal,
        hitDiceCurrent: derived.hitDiceTotal,
        attacksAndSpellcastingNotes: mechanics.attacksAndSpellcastingNotes,
        ability: ability,
      ),
      proficiencies: mechanics.proficiencies,
      roleplay: Roleplay(
        personalityTraits: roleplay('personalityTraits'),
        ideals: roleplay('ideals'),
        bonds: roleplay('bonds'),
        flaws: roleplay('flaws'),
        characterBackstory: roleplay('characterBackstory'),
        alliesAndOrganizations: roleplay('alliesAndOrganizations'),
        additionalFeaturesAndTraits: appearance('additionalFeaturesAndTraits'),
        treasure: roleplay('treasure'),
        characterExperience: roleplay('characterExperience'),
      ),
      spellbook: Spellbook(
        spellcastingClass: mechanics.spellcastingClass,
        spellcastingAbility: mechanics.spellcastingAbility,
        spellSaveDC: derived.spellSaveDC,
        spellAttackBonus: derived.spellAttackBonus,
        allSpells: spellGroups,
      ),
      weapons: weapons.isEmpty ? [Weapon(), Weapon(), Weapon()] : weapons,
      inventory: mechanics.inventory,
    );
  }
}

bool needsNarrativeStage(AiCharacterBuildRequest request) {
  if (request.roleplay.omit) return false;
  return request.roleplay.appearanceAiDecides ||
      request.roleplay.narrativeAiDecides;
}

AiNarrativeScope narrativeScopeFor(AiRoleplayInput input) {
  if (input.omit || (!input.appearanceAiDecides && !input.narrativeAiDecides)) {
    throw ArgumentError('没有需要 AI 生成的人物塑造字段');
  }
  if (input.appearanceAiDecides && input.narrativeAiDecides) {
    return AiNarrativeScope.all;
  }
  return input.appearanceAiDecides
      ? AiNarrativeScope.appearance
      : AiNarrativeScope.personalityAndBackground;
}

Map<String, int> _scoresJson(AbilityScores scores) => {
  'strength': scores.strength,
  'dexterity': scores.dexterity,
  'constitution': scores.constitution,
  'intelligence': scores.intelligence,
  'wisdom': scores.wisdom,
  'charisma': scores.charisma,
};

Map<String, dynamic> _proficienciesJson(Proficiencies value) => {
  'strengthSave': value.strengthSave,
  'dexteritySave': value.dexteritySave,
  'constitutionSave': value.constitutionSave,
  'intelligenceSave': value.intelligenceSave,
  'wisdomSave': value.wisdomSave,
  'charismaSave': value.charismaSave,
  'athletics': value.athletics,
  'acrobatics': value.acrobatics,
  'sleightOfHand': value.sleightOfHand,
  'stealth': value.stealth,
  'arcana': value.arcana,
  'history': value.history,
  'investigation': value.investigation,
  'nature': value.nature,
  'religion': value.religion,
  'animalHandling': value.animalHandling,
  'insight': value.insight,
  'medicine': value.medicine,
  'perception': value.perception,
  'survival': value.survival,
  'deception': value.deception,
  'intimidation': value.intimidation,
  'performance': value.performance,
  'persuasion': value.persuasion,
  'otherProficienciesAndLanguages': value.otherProficienciesAndLanguages,
};
