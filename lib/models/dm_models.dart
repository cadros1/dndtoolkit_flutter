import 'dart:math';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const defaultNpcCategoryId = 'default';
const defaultNpcCategoryName = '默认分类';

int _readInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _readNullableInt(Object? value) {
  if (value == null || value == '') return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String _readString(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

List<T> _readList<T>(Object? value, T Function(Map<String, dynamic>) read) {
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((item) => read(Map<String, dynamic>.from(item)))
      .toList();
}

class NpcCategory {
  String id;
  String name;
  int sortOrder;

  NpcCategory({String? id, this.name = '', this.sortOrder = 0})
    : id = id ?? _uuid.v4();

  factory NpcCategory.defaultCategory() => NpcCategory(
    id: defaultNpcCategoryId,
    name: defaultNpcCategoryName,
    sortOrder: 0,
  );

  bool get isDefault => id == defaultNpcCategoryId;

  factory NpcCategory.fromJson(Map<String, dynamic> json) => NpcCategory(
    id: _readString(json['Id'], _uuid.v4()),
    name: _readString(json['Name']),
    sortOrder: _readInt(json['SortOrder']),
  );

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Name': name,
    'SortOrder': sortOrder,
  };
}

class NpcAbilityScores {
  int strength;
  int dexterity;
  int constitution;
  int intelligence;
  int wisdom;
  int charisma;
  int strengthModifier;
  int dexterityModifier;
  int constitutionModifier;
  int intelligenceModifier;
  int wisdomModifier;
  int charismaModifier;

  NpcAbilityScores({
    this.strength = 10,
    this.dexterity = 10,
    this.constitution = 10,
    this.intelligence = 10,
    this.wisdom = 10,
    this.charisma = 10,
  }) : strengthModifier = modifierFor(strength),
       dexterityModifier = modifierFor(dexterity),
       constitutionModifier = modifierFor(constitution),
       intelligenceModifier = modifierFor(intelligence),
       wisdomModifier = modifierFor(wisdom),
       charismaModifier = modifierFor(charisma);

  static int modifierFor(int score) => ((score - 10) / 2).floor();

  void synchronizeModifiers() {
    strengthModifier = modifierFor(strength);
    dexterityModifier = modifierFor(dexterity);
    constitutionModifier = modifierFor(constitution);
    intelligenceModifier = modifierFor(intelligence);
    wisdomModifier = modifierFor(wisdom);
    charismaModifier = modifierFor(charisma);
  }

  factory NpcAbilityScores.fromJson(Map<String, dynamic> json) =>
      NpcAbilityScores(
        strength: _readInt(json['Strength'], 10),
        dexterity: _readInt(json['Dexterity'], 10),
        constitution: _readInt(json['Constitution'], 10),
        intelligence: _readInt(json['Intelligence'], 10),
        wisdom: _readInt(json['Wisdom'], 10),
        charisma: _readInt(json['Charisma'], 10),
      );

  Map<String, dynamic> toJson() => {
    'Strength': strength,
    'Dexterity': dexterity,
    'Constitution': constitution,
    'Intelligence': intelligence,
    'Wisdom': wisdom,
    'Charisma': charisma,
    'StrengthModifier': strengthModifier,
    'DexterityModifier': dexterityModifier,
    'ConstitutionModifier': constitutionModifier,
    'IntelligenceModifier': intelligenceModifier,
    'WisdomModifier': wisdomModifier,
    'CharismaModifier': charismaModifier,
  };
}

class NpcFeatureEntry {
  String id;
  String name;
  String description;

  NpcFeatureEntry({String? id, this.name = '', this.description = ''})
    : id = id ?? _uuid.v4();

  factory NpcFeatureEntry.fromJson(Map<String, dynamic> json) =>
      NpcFeatureEntry(
        id: _readString(json['Id'], _uuid.v4()),
        name: _readString(json['Name']),
        description: _readString(json['Description']),
      );

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Name': name,
    'Description': description,
  };
}

class NpcCard {
  String id;
  String name;
  String? categoryId;
  String sizeAndType;
  int maximumHitPoints;
  int armorClass;
  String speed;
  NpcAbilityScores abilities;
  String saves;
  String skills;
  String damageVulnerabilities;
  String damageResistances;
  String damageImmunities;
  String conditionImmunities;
  String senses;
  String languages;
  String challengeRating;
  List<NpcFeatureEntry> traits;
  List<NpcFeatureEntry> actions;
  List<NpcFeatureEntry> bonusActions;
  List<NpcFeatureEntry> reactions;
  List<NpcFeatureEntry> legendaryActions;
  String notes;

  NpcCard({
    String? id,
    this.name = '',
    String? categoryId,
    this.sizeAndType = '',
    this.maximumHitPoints = 0,
    this.armorClass = 10,
    this.speed = '',
    NpcAbilityScores? abilities,
    this.saves = '',
    this.skills = '',
    this.damageVulnerabilities = '',
    this.damageResistances = '',
    this.damageImmunities = '',
    this.conditionImmunities = '',
    this.senses = '',
    this.languages = '',
    this.challengeRating = '',
    List<NpcFeatureEntry>? traits,
    List<NpcFeatureEntry>? actions,
    List<NpcFeatureEntry>? bonusActions,
    List<NpcFeatureEntry>? reactions,
    List<NpcFeatureEntry>? legendaryActions,
    this.notes = '',
  }) : id = id ?? _uuid.v4(),
       categoryId = categoryId == null || categoryId.isEmpty
           ? defaultNpcCategoryId
           : categoryId,
       abilities = abilities ?? NpcAbilityScores(),
       traits = traits ?? [],
       actions = actions ?? [],
       bonusActions = bonusActions ?? [],
       reactions = reactions ?? [],
       legendaryActions = legendaryActions ?? [];

  factory NpcCard.fromJson(Map<String, dynamic> json) => NpcCard(
    id: _readString(json['Id'], _uuid.v4()),
    name: _readString(json['Name']),
    categoryId: json['CategoryId'] is String
        ? json['CategoryId'] as String
        : null,
    sizeAndType: _readString(json['SizeAndType']),
    maximumHitPoints: max(0, _readInt(json['MaximumHitPoints'])),
    armorClass: max(0, _readInt(json['ArmorClass'], 10)),
    speed: _readString(json['Speed']),
    abilities: json['Abilities'] is Map
        ? NpcAbilityScores.fromJson(
            Map<String, dynamic>.from(json['Abilities'] as Map),
          )
        : NpcAbilityScores(),
    saves: _readString(json['Saves']),
    skills: _readString(json['Skills']),
    damageVulnerabilities: _readString(json['DamageVulnerabilities']),
    damageResistances: _readString(json['DamageResistances']),
    damageImmunities: _readString(json['DamageImmunities']),
    conditionImmunities: _readString(json['ConditionImmunities']),
    senses: _readString(json['Senses']),
    languages: _readString(json['Languages']),
    challengeRating: _readString(json['ChallengeRating']),
    traits: _readList(json['Traits'], NpcFeatureEntry.fromJson),
    actions: _readList(json['Actions'], NpcFeatureEntry.fromJson),
    bonusActions: _readList(json['BonusActions'], NpcFeatureEntry.fromJson),
    reactions: _readList(json['Reactions'], NpcFeatureEntry.fromJson),
    legendaryActions: _readList(
      json['LegendaryActions'],
      NpcFeatureEntry.fromJson,
    ),
    notes: _readString(json['Notes']),
  );

  NpcCard deepCopy({bool newIdentity = false, String? name}) {
    final copy = NpcCard.fromJson(toJson());
    if (newIdentity) copy.id = _uuid.v4();
    if (name != null) copy.name = name;
    if (newIdentity) {
      for (final entry in [
        ...copy.traits,
        ...copy.actions,
        ...copy.bonusActions,
        ...copy.reactions,
        ...copy.legendaryActions,
      ]) {
        entry.id = _uuid.v4();
      }
    }
    return copy;
  }

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Name': name,
    'CategoryId': categoryId,
    'SizeAndType': sizeAndType,
    'MaximumHitPoints': max(0, maximumHitPoints),
    'ArmorClass': max(0, armorClass),
    'Speed': speed,
    'Abilities': abilities.toJson(),
    'Saves': saves,
    'Skills': skills,
    'DamageVulnerabilities': damageVulnerabilities,
    'DamageResistances': damageResistances,
    'DamageImmunities': damageImmunities,
    'ConditionImmunities': conditionImmunities,
    'Senses': senses,
    'Languages': languages,
    'ChallengeRating': challengeRating,
    'Traits': traits.map((entry) => entry.toJson()).toList(),
    'Actions': actions.map((entry) => entry.toJson()).toList(),
    'BonusActions': bonusActions.map((entry) => entry.toJson()).toList(),
    'Reactions': reactions.map((entry) => entry.toJson()).toList(),
    'LegendaryActions': legendaryActions
        .map((entry) => entry.toJson())
        .toList(),
    'Notes': notes,
  };
}

class NpcInstance {
  String id;
  String? sourceCardId;
  NpcCard cardSnapshot;
  String displayName;
  int currentHitPoints;
  int temporaryHitPoints;
  int? initiative;
  String? groupId;
  int sortOrder;
  String notes;

  NpcInstance({
    String? id,
    this.sourceCardId,
    required this.cardSnapshot,
    this.displayName = '',
    int? currentHitPoints,
    this.temporaryHitPoints = 0,
    this.initiative,
    this.groupId,
    this.sortOrder = 0,
    this.notes = '',
  }) : id = id ?? _uuid.v4(),
       currentHitPoints = (currentHitPoints ?? cardSnapshot.maximumHitPoints)
           .clamp(0, max(0, cardSnapshot.maximumHitPoints));

  factory NpcInstance.fromCard(
    NpcCard card, {
    required String displayName,
    int sortOrder = 0,
  }) => NpcInstance(
    sourceCardId: card.id,
    cardSnapshot: card.deepCopy(),
    displayName: displayName,
    currentHitPoints: card.maximumHitPoints,
    sortOrder: sortOrder,
  );

  factory NpcInstance.fromJson(Map<String, dynamic> json) {
    final snapshot = json['CardSnapshot'] is Map
        ? NpcCard.fromJson(
            Map<String, dynamic>.from(json['CardSnapshot'] as Map),
          )
        : NpcCard();
    return NpcInstance(
      id: _readString(json['Id'], _uuid.v4()),
      sourceCardId: json['SourceCardId'] is String
          ? json['SourceCardId'] as String
          : null,
      cardSnapshot: snapshot,
      displayName: _readString(json['DisplayName'], snapshot.name),
      currentHitPoints: _readInt(
        json['CurrentHitPoints'],
        snapshot.maximumHitPoints,
      ),
      temporaryHitPoints: max(0, _readInt(json['TemporaryHitPoints'])),
      initiative: _readNullableInt(json['Initiative']),
      groupId: json['GroupId'] is String ? json['GroupId'] as String : null,
      sortOrder: _readInt(json['SortOrder']),
      notes: _readString(json['Notes']),
    );
  }

  int get maximumHitPoints => cardSnapshot.maximumHitPoints;

  void setCurrentHitPoints(int value) {
    currentHitPoints = value.clamp(0, max(0, maximumHitPoints));
  }

  void setTemporaryHitPoints(int value) {
    temporaryHitPoints = max(0, value);
  }

  NpcInstance duplicate({required String name, required int order}) {
    final copy = NpcInstance.fromJson(toJson());
    copy
      ..id = _uuid.v4()
      ..displayName = name
      ..sortOrder = order;
    return copy;
  }

  Map<String, dynamic> toJson() => {
    'Id': id,
    'SourceCardId': sourceCardId,
    'CardSnapshot': cardSnapshot.toJson(),
    'DisplayName': displayName,
    'CurrentHitPoints': currentHitPoints.clamp(0, max(0, maximumHitPoints)),
    'TemporaryHitPoints': max(0, temporaryHitPoints),
    'Initiative': initiative,
    'GroupId': groupId,
    'SortOrder': sortOrder,
    'Notes': notes,
  };
}

class EncounterGroup {
  String id;
  String name;
  int? initiative;
  int sortOrder;

  EncounterGroup({
    String? id,
    this.name = '',
    this.initiative,
    this.sortOrder = 0,
  }) : id = id ?? _uuid.v4();

  factory EncounterGroup.fromJson(Map<String, dynamic> json) => EncounterGroup(
    id: _readString(json['Id'], _uuid.v4()),
    name: _readString(json['Name']),
    initiative: _readNullableInt(json['Initiative']),
    sortOrder: _readInt(json['SortOrder']),
  );

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Name': name,
    'Initiative': initiative,
    'SortOrder': sortOrder,
  };
}

class CurrentEncounter {
  List<NpcInstance> instances;
  List<EncounterGroup> groups;

  CurrentEncounter({List<NpcInstance>? instances, List<EncounterGroup>? groups})
    : instances = instances ?? [],
      groups = groups ?? [];

  factory CurrentEncounter.fromJson(Map<String, dynamic> json) =>
      CurrentEncounter(
        instances: _readList(json['Instances'], NpcInstance.fromJson),
        groups: _readList(json['Groups'], EncounterGroup.fromJson),
      );

  bool get isEmpty => instances.isEmpty && groups.isEmpty;

  int get nextSortOrder {
    final orders = [
      ...instances
          .where((item) => item.groupId == null)
          .map((e) => e.sortOrder),
      ...groups.map((e) => e.sortOrder),
    ];
    return orders.isEmpty ? 0 : orders.reduce(max) + 1;
  }

  List<NpcInstance> membersOf(String groupId) =>
      instances.where((instance) => instance.groupId == groupId).toList();

  Map<String, dynamic> toJson() => {
    'Instances': instances.map((instance) => instance.toJson()).toList(),
    'Groups': groups.map((group) => group.toJson()).toList(),
  };
}

class DmData {
  static const schemaVersion = 2;

  List<NpcCategory> categories;
  List<NpcCard> cards;
  CurrentEncounter encounter;

  DmData({
    List<NpcCategory>? categories,
    List<NpcCard>? cards,
    CurrentEncounter? encounter,
  }) : categories = categories ?? [],
       cards = cards ?? [],
       encounter = encounter ?? CurrentEncounter() {
    ensureDefaultCategory();
  }

  factory DmData.fromJson(Map<String, dynamic> json) => DmData(
    categories: _readList(json['Categories'], NpcCategory.fromJson),
    cards: _readList(json['NpcCards'], NpcCard.fromJson),
    encounter: json['CurrentEncounter'] is Map
        ? CurrentEncounter.fromJson(
            Map<String, dynamic>.from(json['CurrentEncounter'] as Map),
          )
        : CurrentEncounter(),
  );

  List<NpcCategory> get sortedCategories =>
      [...categories]
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));

  void ensureDefaultCategory() {
    final existing = categories
        .where((category) => category.isDefault)
        .firstOrNull;
    if (existing == null) {
      categories.add(NpcCategory.defaultCategory());
    } else {
      existing
        ..name = existing.name.trim().isEmpty
            ? defaultNpcCategoryName
            : existing.name
        ..sortOrder = 0;
    }
    for (final card in cards) {
      final categoryExists = categories.any(
        (category) => category.id == card.categoryId,
      );
      if (!categoryExists) card.categoryId = defaultNpcCategoryId;
    }
    normalizeCategoryOrder();
  }

  void normalizeCategoryOrder() {
    final sorted = [...categories]
      ..sort((left, right) {
        if (left.isDefault != right.isDefault) return left.isDefault ? -1 : 1;
        return left.sortOrder.compareTo(right.sortOrder);
      });
    for (var index = 0; index < sorted.length; index++) {
      sorted[index].sortOrder = index;
    }
    categories = sorted;
  }

  void deleteCategory(String categoryId) {
    if (categoryId == defaultNpcCategoryId) return;
    categories.removeWhere((category) => category.id == categoryId);
    for (final card in cards.where((card) => card.categoryId == categoryId)) {
      card.categoryId = defaultNpcCategoryId;
    }
    normalizeCategoryOrder();
  }

  List<NpcInstance> addInstances(NpcCard card, List<String> names) {
    final created = <NpcInstance>[];
    for (final rawName in names) {
      final fallback = card.name.trim().isEmpty ? '未命名 NPC' : card.name.trim();
      final instance = NpcInstance.fromCard(
        card,
        displayName: rawName.trim().isEmpty ? fallback : rawName.trim(),
        sortOrder: encounter.nextSortOrder,
      );
      encounter.instances.add(instance);
      created.add(instance);
    }
    return created;
  }

  void assignInstancesToGroup(Iterable<String> instanceIds, String groupId) {
    final ids = instanceIds.toSet();
    for (final instance in encounter.instances.where(
      (instance) => ids.contains(instance.id),
    )) {
      instance
        ..groupId = groupId
        ..initiative = null;
    }
  }

  void moveInstanceOutOfGroup(String instanceId) {
    final instance = encounter.instances
        .where((item) => item.id == instanceId)
        .firstOrNull;
    if (instance == null) return;
    instance
      ..groupId = null
      ..initiative = null
      ..sortOrder = encounter.nextSortOrder;
  }

  void deleteGroup(String groupId, {required bool removeMembers}) {
    final memberIds = encounter
        .membersOf(groupId)
        .map((member) => member.id)
        .toSet();
    encounter.groups.removeWhere((group) => group.id == groupId);
    if (removeMembers) {
      encounter.instances.removeWhere((item) => memberIds.contains(item.id));
    } else {
      for (final id in memberIds) {
        moveInstanceOutOfGroup(id);
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'DnDToolkit-DM': schemaVersion,
    'Categories': categories.map((category) => category.toJson()).toList(),
    'NpcCards': cards.map((card) => card.toJson()).toList(),
    'CurrentEncounter': encounter.toJson(),
  };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
