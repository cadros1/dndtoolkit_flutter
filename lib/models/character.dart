import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

// 这是代码生成器需要的部分，文件名必须与当前文件名一致
part 'character.g.dart';

/// ----------------------------------------------------------------------------
/// 武器
/// ----------------------------------------------------------------------------
@JsonSerializable(fieldRename: FieldRename.pascal)
class Weapon {
  String name;
  int attackBonus;
  String damage;

  Weapon({
    this.name = "",
    this.attackBonus = 0,
    this.damage = "",
  });

  factory Weapon.fromJson(Map<String, dynamic> json) => _$WeaponFromJson(json);
  Map<String, dynamic> toJson() => _$WeaponToJson(this);
}

/// ----------------------------------------------------------------------------
/// 物品与金钱
/// ----------------------------------------------------------------------------
@JsonSerializable(fieldRename: FieldRename.pascal)
class Inventory {
  // 货币
  int cP;
  int sP;
  int eP;
  int gP;
  int pP;

  // 装备文本
  String equipmentText;

  Inventory({
    this.cP = 0,
    this.sP = 0,
    this.eP = 0,
    this.gP = 0,
    this.pP = 0,
    this.equipmentText = "",
  });

  factory Inventory.fromJson(Map<String, dynamic> json) => _$InventoryFromJson(json);
  Map<String, dynamic> toJson() => _$InventoryToJson(this);
}

/// ----------------------------------------------------------------------------
/// 属性
/// ----------------------------------------------------------------------------
@JsonSerializable(fieldRename: FieldRename.pascal)
class Attributes {
  int strength;
  int dexterity;
  int constitution;
  int intelligence;
  int wisdom;
  int charisma;

  Attributes({
    this.strength = 10,
    this.dexterity = 10,
    this.constitution = 10,
    this.intelligence = 10,
    this.wisdom = 10,
    this.charisma = 10,
  });

  // 私有静态计算方法，对应 C# 的 CalcMod
  static int _calcMod(int score) => ((score - 10) / 2).floor();

  // 使用 Dart getter 对应 C# 的只读属性
  int get strengthMod => _calcMod(strength);
  int get dexterityMod => _calcMod(dexterity);
  int get constitutionMod => _calcMod(constitution);
  int get intelligenceMod => _calcMod(intelligence);
  int get wisdomMod => _calcMod(wisdom);
  int get charismaMod => _calcMod(charisma);

  factory Attributes.fromJson(Map<String, dynamic> json) => _$AttributesFromJson(json);
  Map<String, dynamic> toJson() => _$AttributesToJson(this);
}

/// ----------------------------------------------------------------------------
/// 基础信息&外观
/// ----------------------------------------------------------------------------
@JsonSerializable(fieldRename: FieldRename.pascal)
class Profile {
  String characterName;
  String playerName;
  String race;
  String classAndLevel;
  String background;
  String alignment;
  int experiencePoints;
  String inspiration;
  int proficiencyBonus;

  // P1 左下角
  int passivePerception;

  // 外观
  String age;
  String height;
  String weight;
  String eyes;
  String skin;
  String hair;

  String portraitBase64;

  Profile({
    this.characterName = "",
    this.playerName = "",
    this.race = "",
    this.classAndLevel = "",
    this.background = "",
    this.alignment = "",
    this.experiencePoints = 0,
    this.inspiration = "",
    this.proficiencyBonus = 2,
    this.passivePerception = 10,
    this.age = "",
    this.height = "",
    this.weight = "",
    this.eyes = "",
    this.skin = "",
    this.hair = "",
    this.portraitBase64 = "",
  });

  factory Profile.fromJson(Map<String, dynamic> json) => _$ProfileFromJson(json);
  Map<String, dynamic> toJson() => _$ProfileToJson(this);
}

/// ----------------------------------------------------------------------------
/// 战斗数据
/// ----------------------------------------------------------------------------
@JsonSerializable(fieldRename: FieldRename.pascal)
class CombatStats {
  int armorClass; 
  int initiative;
  String speed;

  // 生命值
  int hitPointsMax;
  int hitPointsCurrent;
  int hitPointsTemp;

  // 生命骰
  String hitDiceTotal;
  String hitDiceCurrent;

  // 死亡豁免
  bool deathSuccess1;
  bool deathSuccess2;
  bool deathSuccess3;

  bool deathFail1;
  bool deathFail2;
  bool deathFail3;

  String attacksAndSpellcastingNotes;
  String ability;

  CombatStats({
    this.armorClass = 10,
    this.initiative = 0,
    this.speed = "",
    this.hitPointsMax = 0,
    this.hitPointsCurrent = 0,
    this.hitPointsTemp = 0,
    this.hitDiceTotal = "",
    this.hitDiceCurrent = "",
    this.deathSuccess1 = false,
    this.deathSuccess2 = false,
    this.deathSuccess3 = false,
    this.deathFail1 = false,
    this.deathFail2 = false,
    this.deathFail3 = false,
    this.attacksAndSpellcastingNotes = "",
    this.ability = "",
  });

  factory CombatStats.fromJson(Map<String, dynamic> json) => _$CombatStatsFromJson(json);
  Map<String, dynamic> toJson() => _$CombatStatsToJson(this);
}

/// ----------------------------------------------------------------------------
/// 熟练项
/// ----------------------------------------------------------------------------
@JsonSerializable(fieldRename: FieldRename.pascal)
class Proficiencies {
  // 豁免
  bool strengthSave;
  bool dexteritySave;
  bool constitutionSave;
  bool intelligenceSave;
  bool wisdomSave;
  bool charismaSave;

  // 技能
  bool athletics;
  bool acrobatics;
  bool sleightOfHand;
  bool stealth;
  bool arcana;
  bool history;
  bool investigation;
  bool nature;
  bool religion;
  bool animalHandling;
  bool insight;
  bool medicine;
  bool perception;
  bool survival;
  bool deception;
  bool intimidation;
  bool performance;
  bool persuasion;

  String otherProficienciesAndLanguages;

  Proficiencies({
    this.strengthSave = false,
    this.dexteritySave = false,
    this.constitutionSave = false,
    this.intelligenceSave = false,
    this.wisdomSave = false,
    this.charismaSave = false,
    this.athletics = false,
    this.acrobatics = false,
    this.sleightOfHand = false,
    this.stealth = false,
    this.arcana = false,
    this.history = false,
    this.investigation = false,
    this.nature = false,
    this.religion = false,
    this.animalHandling = false,
    this.insight = false,
    this.medicine = false,
    this.perception = false,
    this.survival = false,
    this.deception = false,
    this.intimidation = false,
    this.performance = false,
    this.persuasion = false,
    this.otherProficienciesAndLanguages = "",
  });

  factory Proficiencies.fromJson(Map<String, dynamic> json) => _$ProficienciesFromJson(json);
  Map<String, dynamic> toJson() => _$ProficienciesToJson(this);
}

/// ----------------------------------------------------------------------------
/// 角色扮演信息
/// ----------------------------------------------------------------------------
@JsonSerializable(fieldRename: FieldRename.pascal)
class Roleplay {
  String personalityTraits;
  String ideals;
  String bonds;
  String flaws;

  String characterBackstory;
  String alliesAndOrganizations;
  String additionalFeaturesAndTraits;
  String treasure;
  String characterExperience;
  String featuresAndTraits;

  Roleplay({
    this.personalityTraits = "",
    this.ideals = "",
    this.bonds = "",
    this.flaws = "",
    this.characterBackstory = "",
    this.alliesAndOrganizations = "",
    this.additionalFeaturesAndTraits = "",
    this.treasure = "",
    this.characterExperience = "",
    this.featuresAndTraits = "",
  });

  factory Roleplay.fromJson(Map<String, dynamic> json) => _$RoleplayFromJson(json);
  Map<String, dynamic> toJson() => _$RoleplayToJson(this);
}

/// ----------------------------------------------------------------------------
/// 施法
/// ----------------------------------------------------------------------------
@JsonSerializable(fieldRename: FieldRename.pascal)
class Spell {
  String name;
  bool isPrepared;

  Spell({
    this.name = "",
    this.isPrepared = false,
  });

  factory Spell.fromJson(Map<String, dynamic> json) => _$SpellFromJson(json);
  Map<String, dynamic> toJson() => _$SpellToJson(this);
}

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.pascal)
class SpellLevelGroup {
  int level;
  int totalSlots;
  int remainSlots;
  List<Spell> spells;

  // Getter 用于 UI
  String get levelLabel => level == 0 ? "戏法" : "$level环法术";

  SpellLevelGroup({
    this.level = 0,
    this.totalSlots = 0,
    this.remainSlots = 0,
    List<Spell>? spells,
  }) : spells = spells ?? [];

  /// 对应 C# 构造函数中的初始化逻辑
  factory SpellLevelGroup.initDefault(int level) {
    const defaultSpellCounts = [8, 12, 13, 13, 13, 9, 9, 9, 7, 7];
    // 保护性检查，防止越界
    int count = level < defaultSpellCounts.length ? defaultSpellCounts[level] : 0;
    
    return SpellLevelGroup(
      level: level,
      spells: List.generate(count, (_) => Spell()),
    );
  }

  factory SpellLevelGroup.fromJson(Map<String, dynamic> json) => _$SpellLevelGroupFromJson(json);
  Map<String, dynamic> toJson() => _$SpellLevelGroupToJson(this);
}

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.pascal)
class Spellbook {
  String spellcastingClass;
  String spellcastingAbility;
  int spellSaveDC;
  int spellAttackBonus;
  List<SpellLevelGroup> allSpells;

  Spellbook({
    this.spellcastingClass = "",
    this.spellcastingAbility = "",
    this.spellSaveDC = 0,
    this.spellAttackBonus = 0,
    List<SpellLevelGroup>? allSpells,
  }) : allSpells = allSpells ?? [];

  /// 对应 C# Spellbook 构造函数：初始化 0-9 环
  factory Spellbook.createDefault() {
    return Spellbook(
      allSpells: List.generate(10, (index) => SpellLevelGroup.initDefault(index)),
    );
  }

  factory Spellbook.fromJson(Map<String, dynamic> json) => _$SpellbookFromJson(json);
  Map<String, dynamic> toJson() => _$SpellbookToJson(this);
}

/// ----------------------------------------------------------------------------
/// Character (根节点)
/// ----------------------------------------------------------------------------
@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.pascal)
class Character {
  // Dart 中通常将 Guid 存储为 String
  String id;

  // JsonKey ignore 对应 C# [JsonIgnore]
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? filePath;

  Profile profile;
  Attributes attributes;
  CombatStats combat;
  Proficiencies proficiencies;
  Roleplay roleplay;
  Spellbook spellbook;

  List<Weapon> weapons;
  Inventory inventory;

  Character({
    String? id,
    this.filePath,
    Profile? profile,
    Attributes? attributes,
    CombatStats? combat,
    Proficiencies? proficiencies,
    Roleplay? roleplay,
    Spellbook? spellbook,
    List<Weapon>? weapons,
    Inventory? inventory,
  })  : id = id ?? const Uuid().v4(), // 对应 Guid.NewGuid()
        profile = profile ?? Profile(),
        attributes = attributes ?? Attributes(),
        combat = combat ?? CombatStats(),
        proficiencies = proficiencies ?? Proficiencies(),
        roleplay = roleplay ?? Roleplay(),
        spellbook = spellbook ?? Spellbook.createDefault(), // 使用带默认初始化的工厂
        weapons = weapons ?? [Weapon(), Weapon(), Weapon()], // 对应 C# 构造函数默认3个武器
        inventory = inventory ?? Inventory();

  factory Character.fromJson(Map<String, dynamic> json) => _$CharacterFromJson(json);
  Map<String, dynamic> toJson() => _$CharacterToJson(this);
}