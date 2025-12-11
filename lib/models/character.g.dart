// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Weapon _$WeaponFromJson(Map<String, dynamic> json) => Weapon(
  name: json['Name'] as String? ?? "",
  attackBonus: (json['AttackBonus'] as num?)?.toInt() ?? 0,
  damage: json['Damage'] as String? ?? "",
);

Map<String, dynamic> _$WeaponToJson(Weapon instance) => <String, dynamic>{
  'Name': instance.name,
  'AttackBonus': instance.attackBonus,
  'Damage': instance.damage,
};

Inventory _$InventoryFromJson(Map<String, dynamic> json) => Inventory(
  cP: (json['CP'] as num?)?.toInt() ?? 0,
  sP: (json['SP'] as num?)?.toInt() ?? 0,
  eP: (json['EP'] as num?)?.toInt() ?? 0,
  gP: (json['GP'] as num?)?.toInt() ?? 0,
  pP: (json['PP'] as num?)?.toInt() ?? 0,
  equipmentText: json['EquipmentText'] as String? ?? "",
);

Map<String, dynamic> _$InventoryToJson(Inventory instance) => <String, dynamic>{
  'CP': instance.cP,
  'SP': instance.sP,
  'EP': instance.eP,
  'GP': instance.gP,
  'PP': instance.pP,
  'EquipmentText': instance.equipmentText,
};

Attributes _$AttributesFromJson(Map<String, dynamic> json) => Attributes(
  strength: (json['Strength'] as num?)?.toInt() ?? 10,
  dexterity: (json['Dexterity'] as num?)?.toInt() ?? 10,
  constitution: (json['Constitution'] as num?)?.toInt() ?? 10,
  intelligence: (json['Intelligence'] as num?)?.toInt() ?? 10,
  wisdom: (json['Wisdom'] as num?)?.toInt() ?? 10,
  charisma: (json['Charisma'] as num?)?.toInt() ?? 10,
);

Map<String, dynamic> _$AttributesToJson(Attributes instance) =>
    <String, dynamic>{
      'Strength': instance.strength,
      'Dexterity': instance.dexterity,
      'Constitution': instance.constitution,
      'Intelligence': instance.intelligence,
      'Wisdom': instance.wisdom,
      'Charisma': instance.charisma,
    };

Profile _$ProfileFromJson(Map<String, dynamic> json) => Profile(
  characterName: json['CharacterName'] as String? ?? "",
  playerName: json['PlayerName'] as String? ?? "",
  race: json['Race'] as String? ?? "",
  classAndLevel: json['ClassAndLevel'] as String? ?? "",
  background: json['Background'] as String? ?? "",
  alignment: json['Alignment'] as String? ?? "",
  experiencePoints: (json['ExperiencePoints'] as num?)?.toInt() ?? 0,
  inspiration: json['Inspiration'] as String? ?? "",
  proficiencyBonus: (json['ProficiencyBonus'] as num?)?.toInt() ?? 2,
  passivePerception: (json['PassivePerception'] as num?)?.toInt() ?? 10,
  age: json['Age'] as String? ?? "",
  height: json['Height'] as String? ?? "",
  weight: json['Weight'] as String? ?? "",
  eyes: json['Eyes'] as String? ?? "",
  skin: json['Skin'] as String? ?? "",
  hair: json['Hair'] as String? ?? "",
  portraitBase64: json['PortraitBase64'] as String? ?? "",
);

Map<String, dynamic> _$ProfileToJson(Profile instance) => <String, dynamic>{
  'CharacterName': instance.characterName,
  'PlayerName': instance.playerName,
  'Race': instance.race,
  'ClassAndLevel': instance.classAndLevel,
  'Background': instance.background,
  'Alignment': instance.alignment,
  'ExperiencePoints': instance.experiencePoints,
  'Inspiration': instance.inspiration,
  'ProficiencyBonus': instance.proficiencyBonus,
  'PassivePerception': instance.passivePerception,
  'Age': instance.age,
  'Height': instance.height,
  'Weight': instance.weight,
  'Eyes': instance.eyes,
  'Skin': instance.skin,
  'Hair': instance.hair,
  'PortraitBase64': instance.portraitBase64,
};

CombatStats _$CombatStatsFromJson(Map<String, dynamic> json) => CombatStats(
  armorClass: (json['ArmorClass'] as num?)?.toInt() ?? 10,
  initiative: (json['Initiative'] as num?)?.toInt() ?? 0,
  speed: json['Speed'] as String? ?? "",
  hitPointsMax: (json['HitPointsMax'] as num?)?.toInt() ?? 0,
  hitPointsCurrent: (json['HitPointsCurrent'] as num?)?.toInt() ?? 0,
  hitPointsTemp: (json['HitPointsTemp'] as num?)?.toInt() ?? 0,
  hitDiceTotal: json['HitDiceTotal'] as String? ?? "",
  hitDiceCurrent: json['HitDiceCurrent'] as String? ?? "",
  deathSuccess1: json['DeathSuccess1'] as bool? ?? false,
  deathSuccess2: json['DeathSuccess2'] as bool? ?? false,
  deathSuccess3: json['DeathSuccess3'] as bool? ?? false,
  deathFail1: json['DeathFail1'] as bool? ?? false,
  deathFail2: json['DeathFail2'] as bool? ?? false,
  deathFail3: json['DeathFail3'] as bool? ?? false,
  attacksAndSpellcastingNotes:
      json['AttacksAndSpellcastingNotes'] as String? ?? "",
  ability: json['Ability'] as String? ?? "",
);

Map<String, dynamic> _$CombatStatsToJson(CombatStats instance) =>
    <String, dynamic>{
      'ArmorClass': instance.armorClass,
      'Initiative': instance.initiative,
      'Speed': instance.speed,
      'HitPointsMax': instance.hitPointsMax,
      'HitPointsCurrent': instance.hitPointsCurrent,
      'HitPointsTemp': instance.hitPointsTemp,
      'HitDiceTotal': instance.hitDiceTotal,
      'HitDiceCurrent': instance.hitDiceCurrent,
      'DeathSuccess1': instance.deathSuccess1,
      'DeathSuccess2': instance.deathSuccess2,
      'DeathSuccess3': instance.deathSuccess3,
      'DeathFail1': instance.deathFail1,
      'DeathFail2': instance.deathFail2,
      'DeathFail3': instance.deathFail3,
      'AttacksAndSpellcastingNotes': instance.attacksAndSpellcastingNotes,
      'Ability': instance.ability,
    };

Proficiencies _$ProficienciesFromJson(Map<String, dynamic> json) =>
    Proficiencies(
      strengthSave: json['StrengthSave'] as bool? ?? false,
      dexteritySave: json['DexteritySave'] as bool? ?? false,
      constitutionSave: json['ConstitutionSave'] as bool? ?? false,
      intelligenceSave: json['IntelligenceSave'] as bool? ?? false,
      wisdomSave: json['WisdomSave'] as bool? ?? false,
      charismaSave: json['CharismaSave'] as bool? ?? false,
      athletics: json['Athletics'] as bool? ?? false,
      acrobatics: json['Acrobatics'] as bool? ?? false,
      sleightOfHand: json['SleightOfHand'] as bool? ?? false,
      stealth: json['Stealth'] as bool? ?? false,
      arcana: json['Arcana'] as bool? ?? false,
      history: json['History'] as bool? ?? false,
      investigation: json['Investigation'] as bool? ?? false,
      nature: json['Nature'] as bool? ?? false,
      religion: json['Religion'] as bool? ?? false,
      animalHandling: json['AnimalHandling'] as bool? ?? false,
      insight: json['Insight'] as bool? ?? false,
      medicine: json['Medicine'] as bool? ?? false,
      perception: json['Perception'] as bool? ?? false,
      survival: json['Survival'] as bool? ?? false,
      deception: json['Deception'] as bool? ?? false,
      intimidation: json['Intimidation'] as bool? ?? false,
      performance: json['Performance'] as bool? ?? false,
      persuasion: json['Persuasion'] as bool? ?? false,
      otherProficienciesAndLanguages:
          json['OtherProficienciesAndLanguages'] as String? ?? "",
    );

Map<String, dynamic> _$ProficienciesToJson(Proficiencies instance) =>
    <String, dynamic>{
      'StrengthSave': instance.strengthSave,
      'DexteritySave': instance.dexteritySave,
      'ConstitutionSave': instance.constitutionSave,
      'IntelligenceSave': instance.intelligenceSave,
      'WisdomSave': instance.wisdomSave,
      'CharismaSave': instance.charismaSave,
      'Athletics': instance.athletics,
      'Acrobatics': instance.acrobatics,
      'SleightOfHand': instance.sleightOfHand,
      'Stealth': instance.stealth,
      'Arcana': instance.arcana,
      'History': instance.history,
      'Investigation': instance.investigation,
      'Nature': instance.nature,
      'Religion': instance.religion,
      'AnimalHandling': instance.animalHandling,
      'Insight': instance.insight,
      'Medicine': instance.medicine,
      'Perception': instance.perception,
      'Survival': instance.survival,
      'Deception': instance.deception,
      'Intimidation': instance.intimidation,
      'Performance': instance.performance,
      'Persuasion': instance.persuasion,
      'OtherProficienciesAndLanguages': instance.otherProficienciesAndLanguages,
    };

Roleplay _$RoleplayFromJson(Map<String, dynamic> json) => Roleplay(
  personalityTraits: json['PersonalityTraits'] as String? ?? "",
  ideals: json['Ideals'] as String? ?? "",
  bonds: json['Bonds'] as String? ?? "",
  flaws: json['Flaws'] as String? ?? "",
  characterBackstory: json['CharacterBackstory'] as String? ?? "",
  alliesAndOrganizations: json['AlliesAndOrganizations'] as String? ?? "",
  additionalFeaturesAndTraits:
      json['AdditionalFeaturesAndTraits'] as String? ?? "",
  treasure: json['Treasure'] as String? ?? "",
  characterExperience: json['CharacterExperience'] as String? ?? "",
  featuresAndTraits: json['FeaturesAndTraits'] as String? ?? "",
);

Map<String, dynamic> _$RoleplayToJson(Roleplay instance) => <String, dynamic>{
  'PersonalityTraits': instance.personalityTraits,
  'Ideals': instance.ideals,
  'Bonds': instance.bonds,
  'Flaws': instance.flaws,
  'CharacterBackstory': instance.characterBackstory,
  'AlliesAndOrganizations': instance.alliesAndOrganizations,
  'AdditionalFeaturesAndTraits': instance.additionalFeaturesAndTraits,
  'Treasure': instance.treasure,
  'CharacterExperience': instance.characterExperience,
  'FeaturesAndTraits': instance.featuresAndTraits,
};

Spell _$SpellFromJson(Map<String, dynamic> json) => Spell(
  name: json['Name'] as String? ?? "",
  isPrepared: json['IsPrepared'] as bool? ?? false,
);

Map<String, dynamic> _$SpellToJson(Spell instance) => <String, dynamic>{
  'Name': instance.name,
  'IsPrepared': instance.isPrepared,
};

SpellLevelGroup _$SpellLevelGroupFromJson(Map<String, dynamic> json) =>
    SpellLevelGroup(
      level: (json['Level'] as num?)?.toInt() ?? 0,
      totalSlots: (json['TotalSlots'] as num?)?.toInt() ?? 0,
      remainSlots: (json['RemainSlots'] as num?)?.toInt() ?? 0,
      spells: (json['Spells'] as List<dynamic>?)
          ?.map((e) => Spell.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SpellLevelGroupToJson(SpellLevelGroup instance) =>
    <String, dynamic>{
      'Level': instance.level,
      'TotalSlots': instance.totalSlots,
      'RemainSlots': instance.remainSlots,
      'Spells': instance.spells.map((e) => e.toJson()).toList(),
    };

Spellbook _$SpellbookFromJson(Map<String, dynamic> json) => Spellbook(
  spellcastingClass: json['SpellcastingClass'] as String? ?? "",
  spellcastingAbility: json['SpellcastingAbility'] as String? ?? "",
  spellSaveDC: (json['SpellSaveDC'] as num?)?.toInt() ?? 0,
  spellAttackBonus: (json['SpellAttackBonus'] as num?)?.toInt() ?? 0,
  allSpells: (json['AllSpells'] as List<dynamic>?)
      ?.map((e) => SpellLevelGroup.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SpellbookToJson(Spellbook instance) => <String, dynamic>{
  'SpellcastingClass': instance.spellcastingClass,
  'SpellcastingAbility': instance.spellcastingAbility,
  'SpellSaveDC': instance.spellSaveDC,
  'SpellAttackBonus': instance.spellAttackBonus,
  'AllSpells': instance.allSpells.map((e) => e.toJson()).toList(),
};

Character _$CharacterFromJson(Map<String, dynamic> json) => Character(
  id: json['Id'] as String?,
  profile: json['Profile'] == null
      ? null
      : Profile.fromJson(json['Profile'] as Map<String, dynamic>),
  attributes: json['Attributes'] == null
      ? null
      : Attributes.fromJson(json['Attributes'] as Map<String, dynamic>),
  combat: json['Combat'] == null
      ? null
      : CombatStats.fromJson(json['Combat'] as Map<String, dynamic>),
  proficiencies: json['Proficiencies'] == null
      ? null
      : Proficiencies.fromJson(json['Proficiencies'] as Map<String, dynamic>),
  roleplay: json['Roleplay'] == null
      ? null
      : Roleplay.fromJson(json['Roleplay'] as Map<String, dynamic>),
  spellbook: json['Spellbook'] == null
      ? null
      : Spellbook.fromJson(json['Spellbook'] as Map<String, dynamic>),
  weapons: (json['Weapons'] as List<dynamic>?)
      ?.map((e) => Weapon.fromJson(e as Map<String, dynamic>))
      .toList(),
  inventory: json['Inventory'] == null
      ? null
      : Inventory.fromJson(json['Inventory'] as Map<String, dynamic>),
);

Map<String, dynamic> _$CharacterToJson(Character instance) => <String, dynamic>{
  'Id': instance.id,
  'Profile': instance.profile.toJson(),
  'Attributes': instance.attributes.toJson(),
  'Combat': instance.combat.toJson(),
  'Proficiencies': instance.proficiencies.toJson(),
  'Roleplay': instance.roleplay.toJson(),
  'Spellbook': instance.spellbook.toJson(),
  'Weapons': instance.weapons.map((e) => e.toJson()).toList(),
  'Inventory': instance.inventory.toJson(),
};
