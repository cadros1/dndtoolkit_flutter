// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Weapon _$WeaponFromJson(Map<String, dynamic> json) => Weapon(
  name: json['name'] as String? ?? "",
  attackBonus: (json['attackBonus'] as num?)?.toInt() ?? 0,
  damage: json['damage'] as String? ?? "",
);

Map<String, dynamic> _$WeaponToJson(Weapon instance) => <String, dynamic>{
  'name': instance.name,
  'attackBonus': instance.attackBonus,
  'damage': instance.damage,
};

Inventory _$InventoryFromJson(Map<String, dynamic> json) => Inventory(
  cP: (json['cP'] as num?)?.toInt() ?? 0,
  sP: (json['sP'] as num?)?.toInt() ?? 0,
  eP: (json['eP'] as num?)?.toInt() ?? 0,
  gP: (json['gP'] as num?)?.toInt() ?? 0,
  pP: (json['pP'] as num?)?.toInt() ?? 0,
  equipmentText: json['equipmentText'] as String? ?? "",
);

Map<String, dynamic> _$InventoryToJson(Inventory instance) => <String, dynamic>{
  'cP': instance.cP,
  'sP': instance.sP,
  'eP': instance.eP,
  'gP': instance.gP,
  'pP': instance.pP,
  'equipmentText': instance.equipmentText,
};

Attributes _$AttributesFromJson(Map<String, dynamic> json) => Attributes(
  strength: (json['strength'] as num?)?.toInt() ?? 10,
  dexterity: (json['dexterity'] as num?)?.toInt() ?? 10,
  constitution: (json['constitution'] as num?)?.toInt() ?? 10,
  intelligence: (json['intelligence'] as num?)?.toInt() ?? 10,
  wisdom: (json['wisdom'] as num?)?.toInt() ?? 10,
  charisma: (json['charisma'] as num?)?.toInt() ?? 10,
);

Map<String, dynamic> _$AttributesToJson(Attributes instance) =>
    <String, dynamic>{
      'strength': instance.strength,
      'dexterity': instance.dexterity,
      'constitution': instance.constitution,
      'intelligence': instance.intelligence,
      'wisdom': instance.wisdom,
      'charisma': instance.charisma,
    };

Profile _$ProfileFromJson(Map<String, dynamic> json) => Profile(
  characterName: json['characterName'] as String? ?? "",
  playerName: json['playerName'] as String? ?? "",
  race: json['race'] as String? ?? "",
  classAndLevel: json['classAndLevel'] as String? ?? "",
  background: json['background'] as String? ?? "",
  alignment: json['alignment'] as String? ?? "",
  experiencePoints: (json['experiencePoints'] as num?)?.toInt() ?? 0,
  inspiration: json['inspiration'] as String? ?? "",
  proficiencyBonus: (json['proficiencyBonus'] as num?)?.toInt() ?? 2,
  passivePerception: (json['passivePerception'] as num?)?.toInt() ?? 10,
  age: json['age'] as String? ?? "",
  height: json['height'] as String? ?? "",
  weight: json['weight'] as String? ?? "",
  eyes: json['eyes'] as String? ?? "",
  skin: json['skin'] as String? ?? "",
  hair: json['hair'] as String? ?? "",
  portraitBase64: json['portraitBase64'] as String? ?? "",
);

Map<String, dynamic> _$ProfileToJson(Profile instance) => <String, dynamic>{
  'characterName': instance.characterName,
  'playerName': instance.playerName,
  'race': instance.race,
  'classAndLevel': instance.classAndLevel,
  'background': instance.background,
  'alignment': instance.alignment,
  'experiencePoints': instance.experiencePoints,
  'inspiration': instance.inspiration,
  'proficiencyBonus': instance.proficiencyBonus,
  'passivePerception': instance.passivePerception,
  'age': instance.age,
  'height': instance.height,
  'weight': instance.weight,
  'eyes': instance.eyes,
  'skin': instance.skin,
  'hair': instance.hair,
  'portraitBase64': instance.portraitBase64,
};

CombatStats _$CombatStatsFromJson(Map<String, dynamic> json) => CombatStats(
  armorClass: (json['armorClass'] as num?)?.toInt() ?? 10,
  initiative: (json['initiative'] as num?)?.toInt() ?? 0,
  speed: json['speed'] as String? ?? "",
  hitPointsMax: (json['hitPointsMax'] as num?)?.toInt() ?? 0,
  hitPointsCurrent: (json['hitPointsCurrent'] as num?)?.toInt() ?? 0,
  hitPointsTemp: (json['hitPointsTemp'] as num?)?.toInt() ?? 0,
  hitDiceTotal: json['hitDiceTotal'] as String? ?? "",
  hitDiceCurrent: json['hitDiceCurrent'] as String? ?? "",
  deathSuccess1: json['deathSuccess1'] as bool? ?? false,
  deathSuccess2: json['deathSuccess2'] as bool? ?? false,
  deathSuccess3: json['deathSuccess3'] as bool? ?? false,
  deathFail1: json['deathFail1'] as bool? ?? false,
  deathFail2: json['deathFail2'] as bool? ?? false,
  deathFail3: json['deathFail3'] as bool? ?? false,
  attacksAndSpellcastingNotes:
      json['attacksAndSpellcastingNotes'] as String? ?? "",
  ability: json['ability'] as String? ?? "",
);

Map<String, dynamic> _$CombatStatsToJson(CombatStats instance) =>
    <String, dynamic>{
      'armorClass': instance.armorClass,
      'initiative': instance.initiative,
      'speed': instance.speed,
      'hitPointsMax': instance.hitPointsMax,
      'hitPointsCurrent': instance.hitPointsCurrent,
      'hitPointsTemp': instance.hitPointsTemp,
      'hitDiceTotal': instance.hitDiceTotal,
      'hitDiceCurrent': instance.hitDiceCurrent,
      'deathSuccess1': instance.deathSuccess1,
      'deathSuccess2': instance.deathSuccess2,
      'deathSuccess3': instance.deathSuccess3,
      'deathFail1': instance.deathFail1,
      'deathFail2': instance.deathFail2,
      'deathFail3': instance.deathFail3,
      'attacksAndSpellcastingNotes': instance.attacksAndSpellcastingNotes,
      'ability': instance.ability,
    };

Proficiencies _$ProficienciesFromJson(Map<String, dynamic> json) =>
    Proficiencies(
      strengthSave: json['strengthSave'] as bool? ?? false,
      dexteritySave: json['dexteritySave'] as bool? ?? false,
      constitutionSave: json['constitutionSave'] as bool? ?? false,
      intelligenceSave: json['intelligenceSave'] as bool? ?? false,
      wisdomSave: json['wisdomSave'] as bool? ?? false,
      charismaSave: json['charismaSave'] as bool? ?? false,
      athletics: json['athletics'] as bool? ?? false,
      acrobatics: json['acrobatics'] as bool? ?? false,
      sleightOfHand: json['sleightOfHand'] as bool? ?? false,
      stealth: json['stealth'] as bool? ?? false,
      arcana: json['arcana'] as bool? ?? false,
      history: json['history'] as bool? ?? false,
      investigation: json['investigation'] as bool? ?? false,
      nature: json['nature'] as bool? ?? false,
      religion: json['religion'] as bool? ?? false,
      animalHandling: json['animalHandling'] as bool? ?? false,
      insight: json['insight'] as bool? ?? false,
      medicine: json['medicine'] as bool? ?? false,
      perception: json['perception'] as bool? ?? false,
      survival: json['survival'] as bool? ?? false,
      deception: json['deception'] as bool? ?? false,
      intimidation: json['intimidation'] as bool? ?? false,
      performance: json['performance'] as bool? ?? false,
      persuasion: json['persuasion'] as bool? ?? false,
      otherProficienciesAndLanguages:
          json['otherProficienciesAndLanguages'] as String? ?? "",
    );

Map<String, dynamic> _$ProficienciesToJson(Proficiencies instance) =>
    <String, dynamic>{
      'strengthSave': instance.strengthSave,
      'dexteritySave': instance.dexteritySave,
      'constitutionSave': instance.constitutionSave,
      'intelligenceSave': instance.intelligenceSave,
      'wisdomSave': instance.wisdomSave,
      'charismaSave': instance.charismaSave,
      'athletics': instance.athletics,
      'acrobatics': instance.acrobatics,
      'sleightOfHand': instance.sleightOfHand,
      'stealth': instance.stealth,
      'arcana': instance.arcana,
      'history': instance.history,
      'investigation': instance.investigation,
      'nature': instance.nature,
      'religion': instance.religion,
      'animalHandling': instance.animalHandling,
      'insight': instance.insight,
      'medicine': instance.medicine,
      'perception': instance.perception,
      'survival': instance.survival,
      'deception': instance.deception,
      'intimidation': instance.intimidation,
      'performance': instance.performance,
      'persuasion': instance.persuasion,
      'otherProficienciesAndLanguages': instance.otherProficienciesAndLanguages,
    };

Roleplay _$RoleplayFromJson(Map<String, dynamic> json) => Roleplay(
  personalityTraits: json['personalityTraits'] as String? ?? "",
  ideals: json['ideals'] as String? ?? "",
  bonds: json['bonds'] as String? ?? "",
  flaws: json['flaws'] as String? ?? "",
  characterBackstory: json['characterBackstory'] as String? ?? "",
  alliesAndOrganizations: json['alliesAndOrganizations'] as String? ?? "",
  additionalFeaturesAndTraits:
      json['additionalFeaturesAndTraits'] as String? ?? "",
  treasure: json['treasure'] as String? ?? "",
  characterExperience: json['characterExperience'] as String? ?? "",
  featuresAndTraits: json['featuresAndTraits'] as String? ?? "",
);

Map<String, dynamic> _$RoleplayToJson(Roleplay instance) => <String, dynamic>{
  'personalityTraits': instance.personalityTraits,
  'ideals': instance.ideals,
  'bonds': instance.bonds,
  'flaws': instance.flaws,
  'characterBackstory': instance.characterBackstory,
  'alliesAndOrganizations': instance.alliesAndOrganizations,
  'additionalFeaturesAndTraits': instance.additionalFeaturesAndTraits,
  'treasure': instance.treasure,
  'characterExperience': instance.characterExperience,
  'featuresAndTraits': instance.featuresAndTraits,
};

Spell _$SpellFromJson(Map<String, dynamic> json) => Spell(
  name: json['name'] as String? ?? "",
  isPrepared: json['isPrepared'] as bool? ?? false,
);

Map<String, dynamic> _$SpellToJson(Spell instance) => <String, dynamic>{
  'name': instance.name,
  'isPrepared': instance.isPrepared,
};

SpellLevelGroup _$SpellLevelGroupFromJson(Map<String, dynamic> json) =>
    SpellLevelGroup(
      level: (json['level'] as num?)?.toInt() ?? 0,
      totalSlots: (json['totalSlots'] as num?)?.toInt() ?? 0,
      remainSlots: (json['remainSlots'] as num?)?.toInt() ?? 0,
      spells: (json['spells'] as List<dynamic>?)
          ?.map((e) => Spell.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SpellLevelGroupToJson(SpellLevelGroup instance) =>
    <String, dynamic>{
      'level': instance.level,
      'totalSlots': instance.totalSlots,
      'remainSlots': instance.remainSlots,
      'spells': instance.spells.map((e) => e.toJson()).toList(),
    };

Spellbook _$SpellbookFromJson(Map<String, dynamic> json) => Spellbook(
  spellcastingClass: json['spellcastingClass'] as String? ?? "",
  spellcastingAbility: json['spellcastingAbility'] as String? ?? "",
  spellSaveDC: (json['spellSaveDC'] as num?)?.toInt() ?? 0,
  spellAttackBonus: (json['spellAttackBonus'] as num?)?.toInt() ?? 0,
  allSpells: (json['allSpells'] as List<dynamic>?)
      ?.map((e) => SpellLevelGroup.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SpellbookToJson(Spellbook instance) => <String, dynamic>{
  'spellcastingClass': instance.spellcastingClass,
  'spellcastingAbility': instance.spellcastingAbility,
  'spellSaveDC': instance.spellSaveDC,
  'spellAttackBonus': instance.spellAttackBonus,
  'allSpells': instance.allSpells.map((e) => e.toJson()).toList(),
};

Character _$CharacterFromJson(Map<String, dynamic> json) => Character(
  id: json['id'] as String?,
  profile: json['profile'] == null
      ? null
      : Profile.fromJson(json['profile'] as Map<String, dynamic>),
  attributes: json['attributes'] == null
      ? null
      : Attributes.fromJson(json['attributes'] as Map<String, dynamic>),
  combat: json['combat'] == null
      ? null
      : CombatStats.fromJson(json['combat'] as Map<String, dynamic>),
  proficiencies: json['proficiencies'] == null
      ? null
      : Proficiencies.fromJson(json['proficiencies'] as Map<String, dynamic>),
  roleplay: json['roleplay'] == null
      ? null
      : Roleplay.fromJson(json['roleplay'] as Map<String, dynamic>),
  spellbook: json['spellbook'] == null
      ? null
      : Spellbook.fromJson(json['spellbook'] as Map<String, dynamic>),
  weapons: (json['weapons'] as List<dynamic>?)
      ?.map((e) => Weapon.fromJson(e as Map<String, dynamic>))
      .toList(),
  inventory: json['inventory'] == null
      ? null
      : Inventory.fromJson(json['inventory'] as Map<String, dynamic>),
);

Map<String, dynamic> _$CharacterToJson(Character instance) => <String, dynamic>{
  'id': instance.id,
  'profile': instance.profile.toJson(),
  'attributes': instance.attributes.toJson(),
  'combat': instance.combat.toJson(),
  'proficiencies': instance.proficiencies.toJson(),
  'roleplay': instance.roleplay.toJson(),
  'spellbook': instance.spellbook.toJson(),
  'weapons': instance.weapons.map((e) => e.toJson()).toList(),
  'inventory': instance.inventory.toJson(),
};
