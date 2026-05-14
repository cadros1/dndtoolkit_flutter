import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/character.dart';
import 'snack_bar_service.dart';

class PdfDataService {
  static final List<String> _skills =[
    "运动", "杂技", "巧手", "躲藏", "奥秘", "历史", "调查", "自然", "宗教",
    "驯兽", "洞悉", "医药", "察觉", "生存", "欺瞒", "威吓", "表演", "游说"
  ];

  static final List<String> _saves = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];

  static PdfFont? _cjkFont;

  /// 导入角色卡 PDF
  static Future<Character?> importCharacterPdfAsync() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) return null;

      final File file = File(result.files.single.path!);
      final Uint8List bytes = await file.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final PdfForm form = document.form;

      // 创建去除前后空格的字段映射字典，以匹配 C# 中的 Trim() 逻辑
      final Map<String, PdfField> fieldMap = {};
      for (int i = 0; i < form.fields.count; i++) {
        final field = form.fields[i];
        if (field.name != null) {
          fieldMap[field.name!.trim()] = field;
        }
      }

      final character = Character();
      final p = character.profile;
      final r = character.roleplay;
      final a = character.attributes;
      final c = character.combat;
      final i = character.inventory;
      final s = character.spellbook;
      final pro = character.proficiencies;

      // --- 基础信息 ---
      p.characterName = _getText(fieldMap, "CharacterName");
      p.playerName = _getText(fieldMap, "PlayerName");
      p.race = _getText(fieldMap, "Race"); // C# 中是 "Race "
      p.classAndLevel = _getText(fieldMap, "ClassLevel");
      p.background = _getText(fieldMap, "Background");
      p.alignment = _getText(fieldMap, "Alignment");
      p.experiencePoints = _parseInt(_getText(fieldMap, "XP"));

      p.age = _getText(fieldMap, "Age");
      p.height = _getText(fieldMap, "Height");
      p.weight = _getText(fieldMap, "Weight");
      p.eyes = _getText(fieldMap, "Eyes");
      p.skin = _getText(fieldMap, "Skin");
      p.hair = _getText(fieldMap, "Hair");

      r.personalityTraits = _getText(fieldMap, "PersonalityTraits");
      r.ideals = _getText(fieldMap, "Ideals");
      r.bonds = _getText(fieldMap, "Bonds");
      r.flaws = _getText(fieldMap, "Flaws");
      r.characterExperience = _getText(fieldMap, "角色经历");
      r.characterBackstory = _getText(fieldMap, "Backstory");
      r.alliesAndOrganizations = _getText(fieldMap, "Allies");
      r.treasure = _getText(fieldMap, "Treasure");
      r.featuresAndTraits = _getText(fieldMap, "Feat+Traits");

      // --- 属性 ---
      a.strength = _parseInt(_getText(fieldMap, "STR"));
      a.dexterity = _parseInt(_getText(fieldMap, "DEX"));
      a.constitution = _parseInt(_getText(fieldMap, "CON"));
      a.intelligence = _parseInt(_getText(fieldMap, "INT"));
      a.wisdom = _parseInt(_getText(fieldMap, "WIS"));
      a.charisma = _parseInt(_getText(fieldMap, "CHA"));

      // --- 熟练项 ---
      for (String skill in _skills) {
        _setSkill(pro, skill, _getBool(fieldMap, "Check Box $skill"));
      }
      for (String save in _saves) {
        _setSave(pro, save, _getBool(fieldMap, "Check Box $save"));
      }

      p.proficiencyBonus = _parseInt(_getText(fieldMap, "ProfBonus"));
      p.passivePerception = _parseInt(_getText(fieldMap, "Passive Perception"));
      p.inspiration = _getText(fieldMap, "Inspiration");
      pro.otherProficienciesAndLanguages = _getText(fieldMap, "ProficienciesLang");

      // --- 战斗数据 ---
      c.armorClass = _parseInt(_getText(fieldMap, "AC"));
      c.initiative = _parseInt(_getText(fieldMap, "Initiative"));
      c.speed = _getText(fieldMap, "Speed");
      c.attacksAndSpellcastingNotes = _getText(fieldMap, "AttacksAndSpellcasting");
      c.ability = _getText(fieldMap, "Ability");

      int hpMax = _parseInt(_getText(fieldMap, "HPMax"));
      c.hitPointsMax = hpMax;
      c.hitPointsCurrent = hpMax; // 导入时默认填满
      c.hitPointsTemp = _parseInt(_getText(fieldMap, "HPTemp"));
      c.hitDiceTotal = _getText(fieldMap, "HDTotal");
      c.hitDiceCurrent = _getText(fieldMap, "HDTotal");

      // 钱币
      i.equipmentText = _getText(fieldMap, "Equipment");
      i.cP = _parseInt(_getText(fieldMap, "CP"));
      i.sP = _parseInt(_getText(fieldMap, "SP"));
      i.eP = _parseInt(_getText(fieldMap, "EP"));
      i.gP = _parseInt(_getText(fieldMap, "GP"));
      i.pP = _parseInt(_getText(fieldMap, "PP"));

      // --- 武器 ---
      character.weapons.clear();
      for (int idx = 1; idx <= 3; idx++) {
        String name = _getText(fieldMap, "Wpn Name $idx");
        if (name.trim().isNotEmpty) {
          character.weapons.add(Weapon(
            name: name,
            attackBonus: _parseInt(_getText(fieldMap, "Wpn$idx AtkBonus")),
            damage: _getText(fieldMap, "Wpn$idx Damage"),
          ));
        }
      }
      // 补齐 3 个槽位
      while (character.weapons.length < 3) {
        character.weapons.add(Weapon());
      }

      // --- 法术 ---
      s.spellcastingClass = _getText(fieldMap, "Spellcasting Class");
      s.spellcastingAbility = _getText(fieldMap, "SpellcastingAbility");
      s.spellSaveDC = _parseInt(_getText(fieldMap, "SpellSaveDC"));
      s.spellAttackBonus = _parseInt(_getText(fieldMap, "SpellAtkBonus"));

      for (int level = 0; level <= 9; level++) {
        var group = s.allSpells[level];
        if (level > 0) {
          int totalSlots = _parseInt(_getText(fieldMap, "SlotsTotal $level"));
          group.totalSlots = totalSlots;
          group.remainSlots = totalSlots;
        }

        for (int k = 0; k < group.spells.length; k++) {
          int pdfIndex = k + 1;
          String suffix = '$level${pdfIndex.toString().padLeft(2, '0')}';

          String spellName = _getText(fieldMap, "Spells $suffix");
          bool prepared = _getBool(fieldMap, "Check Box S$suffix");

          if (spellName.trim().isNotEmpty) {
            group.spells[k].name = spellName;
            group.spells[k].isPrepared = prepared;
          }
        }
      }

      document.dispose();
      return character;
    } catch (e) {
      throw Exception("读取 PDF 失败: $e");
    }
  }

  /// 导出角色卡 PDF
  static Future<void> exportCharacterPdfAsync(Character character) async {
    final ByteData fontData = await rootBundle.load('assets/fonts/simsun.ttc'); // 替换为你实际的字体文件名
    _cjkFont = PdfTrueTypeFont(fontData.buffer.asUint8List(), 12);
    
    final ByteData templateData = await rootBundle.load('assets/Character.pdf');
    final PdfDocument document = PdfDocument(inputBytes: templateData.buffer.asUint8List());
    final PdfForm form = document.form;

    final Map<String, PdfField> fieldMap = {};
    for (int i = 0; i < form.fields.count; i++) {
      final field = form.fields[i];
      if (field.name != null) fieldMap[field.name!.trim()] = field;
    }

    final p = character.profile;
    final r = character.roleplay;
    final a = character.attributes;
    final c = character.combat;
    final i = character.inventory;
    final s = character.spellbook;
    final pro = character.proficiencies;

    _setText(fieldMap, "CharacterName", p.characterName);
    _setText(fieldMap, "CharacterName 2", p.characterName);
    _setText(fieldMap, "Character Image Name", p.characterName);
    _setText(fieldMap, "PlayerName", p.playerName);
    _setText(fieldMap, "Race", p.race);
    _setText(fieldMap, "ClassLevel", p.classAndLevel);
    _setText(fieldMap, "Background", p.background);
    _setText(fieldMap, "Alignment", p.alignment);
    _setText(fieldMap, "XP", p.experiencePoints.toString());

    _setText(fieldMap, "Age", p.age);
    _setText(fieldMap, "Height", p.height);
    _setText(fieldMap, "Weight", p.weight);
    _setText(fieldMap, "Eyes", p.eyes);
    _setText(fieldMap, "Skin", p.skin);
    _setText(fieldMap, "Hair", p.hair);

    _setText(fieldMap, "PersonalityTraits", r.personalityTraits);
    _setText(fieldMap, "Ideals", r.ideals);
    _setText(fieldMap, "Bonds", r.bonds);
    _setText(fieldMap, "Flaws", r.flaws);
    _setText(fieldMap, "角色经历", r.characterExperience);
    _setText(fieldMap, "Backstory", r.characterBackstory);
    _setText(fieldMap, "Allies", r.alliesAndOrganizations);
    _setText(fieldMap, "Treasure", r.treasure);
    _setText(fieldMap, "Feat+Traits", r.featuresAndTraits);

    _setText(fieldMap, "STR", a.strength.toString());
    _setText(fieldMap, "STRmod", a.strengthMod.toString());
    _setText(fieldMap, "DEX", a.dexterity.toString());
    _setText(fieldMap, "DEXmod", a.dexterityMod.toString());
    _setText(fieldMap, "CON", a.constitution.toString());
    _setText(fieldMap, "CONmod", a.constitutionMod.toString());
    _setText(fieldMap, "INT", a.intelligence.toString());
    _setText(fieldMap, "INTmod", a.intelligenceMod.toString());
    _setText(fieldMap, "WIS", a.wisdom.toString());
    _setText(fieldMap, "WISmod", a.wisdomMod.toString());
    _setText(fieldMap, "CHA", a.charisma.toString());
    _setText(fieldMap, "CHAmod", a.charismaMod.toString());

    for (String skill in _skills) {
      _setCheck(fieldMap, "Check Box $skill", _getSkill(pro, skill));
    }
    for (String save in _saves) {
      _setCheck(fieldMap, "Check Box $save", _getSave(pro, save));
    }

    _setText(fieldMap, "ProfBonus", p.proficiencyBonus.toString());
    _setText(fieldMap, "Passive Perception", p.passivePerception.toString());
    _setText(fieldMap, "Inspiration", p.inspiration);
    _setText(fieldMap, "ProficienciesLang", pro.otherProficienciesAndLanguages);

    _setText(fieldMap, "AC", c.armorClass.toString());
    _setText(fieldMap, "Initiative", c.initiative.toString());
    _setText(fieldMap, "Speed", c.speed);

    _setText(fieldMap, "HPMax", c.hitPointsMax.toString());
    _setText(fieldMap, "HPCurrent", c.hitPointsMax.toString());
    _setText(fieldMap, "HDTotal", c.hitDiceTotal);
    _setText(fieldMap, "HDCurrent", c.hitDiceTotal);

    _setText(fieldMap, "AttacksAndSpellcasting", c.attacksAndSpellcastingNotes);
    _setText(fieldMap, "Ability", c.ability);

    _setText(fieldMap, "Equipment", i.equipmentText);
    _setText(fieldMap, "CP", i.cP.toString());
    _setText(fieldMap, "SP", i.sP.toString());
    _setText(fieldMap, "EP", i.eP.toString());
    _setText(fieldMap, "GP", i.gP.toString());
    _setText(fieldMap, "PP", i.pP.toString());

    for (int idx = 0; idx < min(3, character.weapons.length); idx++) {
      int id = idx + 1;
      var wpn = character.weapons[idx];
      _setText(fieldMap, "Wpn Name $id", wpn.name);
      _setText(fieldMap, "Wpn$id AtkBonus", wpn.attackBonus.toString());
      _setText(fieldMap, "Wpn$id Damage", wpn.damage);
    }

    _setText(fieldMap, "Spellcasting Class", s.spellcastingClass);
    _setText(fieldMap, "SpellcastingAbility", s.spellcastingAbility);
    _setText(fieldMap, "SpellSaveDC", s.spellSaveDC.toString());
    _setText(fieldMap, "SpellAtkBonus", s.spellAttackBonus.toString());

    for (int level = 0; level <= 9; level++) {
      var group = s.allSpells[level];
      if (level > 0) {
        _setText(fieldMap, "SlotsTotal $level", group.totalSlots.toString());
        _setText(fieldMap, "SlotsRemaining $level", group.totalSlots.toString());
      }

      for (int k = 0; k < group.spells.length; k++) {
        var spell = group.spells[k];
        int pdfIndex = k + 1;
        String suffix = '$level${pdfIndex.toString().padLeft(2, '0')}';

        if (spell.name.trim().isNotEmpty) {
          _setText(fieldMap, "Spells $suffix", spell.name);
          _setCheck(fieldMap, "Check Box S$suffix", spell.isPrepared);
        }
      }
    }

    final List<int> outputBytes = await document.save();
    document.dispose();

    final String safeName = p.characterName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final String fileName = safeName.isEmpty ? 'Unnamed_Character' : safeName;

    if (Platform.isAndroid || Platform.isIOS) {
      // 移动端：写临时文件 + 系统分享
      final Directory tempDir = await getTemporaryDirectory();
      final File outputFile = File('${tempDir.path}/$fileName.pdf');
      await outputFile.writeAsBytes(outputBytes, flush: true);
      await Share.shareXFiles([XFile(outputFile.path)], text: '分享角色卡: $fileName.pdf');
    } else {
      // 桌面端：弹出原生保存文件对话框
      final String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: '保存角色卡',
        fileName: '$fileName.pdf',
        allowedExtensions: ['pdf'],
      );
      if (savePath == null) {
        throw Exception('用户取消了保存');
      }
      await File(savePath).writeAsBytes(outputBytes, flush: true);
      SnackBarService.showSuccess('角色卡已保存到: $fileName.pdf');
    }
  }

  // ==================== 辅助方法 ====================

  static String _getText(Map<String, PdfField> map, String key) {
    final field = map[key.trim()];
    if (field is PdfTextBoxField) return field.text;
    return "";
  }

  static bool _getBool(Map<String, PdfField> map, String key) {
    final field = map[key.trim()];
    if (field is PdfCheckBoxField) return field.isChecked;
    return false;
  }

  static void _setText(Map<String, PdfField> map, String key, String value) {
    final field = map[key.trim()];
    if (field is PdfTextBoxField) {
      if (_cjkFont != null) {
        field.font = _cjkFont!;
      }
      field.text = value;
    }
  }

  static void _setCheck(Map<String, PdfField> map, String key, bool isChecked) {
    final field = map[key.trim()];
    if (field is PdfCheckBoxField) field.isChecked = isChecked;
  }

  static int _parseInt(String val) => int.tryParse(val) ?? 0;

  static void _setSkill(Proficiencies p, String skill, bool value) {
    switch (skill) {
      case "运动": p.athletics = value; break;
      case "杂技": p.acrobatics = value; break;
      case "巧手": p.sleightOfHand = value; break;
      case "躲藏": p.stealth = value; break;
      case "奥秘": p.arcana = value; break;
      case "历史": p.history = value; break;
      case "调查": p.investigation = value; break;
      case "自然": p.nature = value; break;
      case "宗教": p.religion = value; break;
      case "驯兽": p.animalHandling = value; break;
      case "洞悉": p.insight = value; break;
      case "医药": p.medicine = value; break;
      case "察觉": p.perception = value; break;
      case "生存": p.survival = value; break;
      case "欺瞒": p.deception = value; break;
      case "威吓": p.intimidation = value; break;
      case "表演": p.performance = value; break;
      case "游说": p.persuasion = value; break;
    }
  }

  static bool _getSkill(Proficiencies p, String skill) {
    switch (skill) {
      case "运动": return p.athletics;
      case "杂技": return p.acrobatics;
      case "巧手": return p.sleightOfHand;
      case "躲藏": return p.stealth;
      case "奥秘": return p.arcana;
      case "历史": return p.history;
      case "调查": return p.investigation;
      case "自然": return p.nature;
      case "宗教": return p.religion;
      case "驯兽": return p.animalHandling;
      case "洞悉": return p.insight;
      case "医药": return p.medicine;
      case "察觉": return p.perception;
      case "生存": return p.survival;
      case "欺瞒": return p.deception;
      case "威吓": return p.intimidation;
      case "表演": return p.performance;
      case "游说": return p.persuasion;
      default: return false;
    }
  }

  static void _setSave(Proficiencies p, String save, bool value) {
    switch (save) {
      case "STR": p.strengthSave = value; break;
      case "DEX": p.dexteritySave = value; break;
      case "CON": p.constitutionSave = value; break;
      case "INT": p.intelligenceSave = value; break;
      case "WIS": p.wisdomSave = value; break;
      case "CHA": p.charismaSave = value; break;
    }
  }

  static bool _getSave(Proficiencies p, String save) {
    switch (save) {
      case "STR": return p.strengthSave;
      case "DEX": return p.dexteritySave;
      case "CON": return p.constitutionSave;
      case "INT": return p.intelligenceSave;
      case "WIS": return p.wisdomSave;
      case "CHA": return p.charismaSave;
      default: return false;
    }
  }
}