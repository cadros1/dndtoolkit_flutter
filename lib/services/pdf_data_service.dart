// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/graphics/images/pdf_image.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/io/pdf_constants.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/io/pdf_cross_table.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_array.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_dictionary.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_name.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_number.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_reference_holder.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_stream.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/interfaces/pdf_interface.dart';
import '../models/character.dart';
import 'snack_bar_service.dart';

class PdfDataService {
  static final List<String> _skills =[
    "运动", "杂技", "巧手", "躲藏", "奥秘", "历史", "调查", "自然", "宗教",
    "驯兽", "洞悉", "医药", "察觉", "生存", "欺瞒", "威吓", "表演", "游说"
  ];

  static final List<String> _saves = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];

  static Uint8List? _cjkFontData;
  static final Map<int, PdfTrueTypeFont> _cjkFonts = {};

  static const String characterImageFieldName = 'Character Image';
  static const String additionalFeaturesAndTraitsFieldName = 'Feat+Traits';
  static const int _maxPortraitImageBytes = 8 * 1024 * 1024;
  static const int _maxPortraitImageDimension = 8192;
  static const double _singleLineMaxFontSize = 12;
  static const double _multilineMaxFontSize = 8;
  static const double _minimumReadableFontSize = 4;
  static const int _fontSizeStepsPerPoint = 4;
  static const int _doNotScrollFieldFlag = 1 << 23;
  static const String _mobileShareDirectoryName = 'dndtoolkit_pdf_share';

  static Uint8List? extractButtonIconImageBytes(
    List<int> pdfBytes, {
    String fieldName = characterImageFieldName,
  }) {
    final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
    try {
      final field = _findField(document.form, fieldName);
      if (field is! PdfButtonField) return null;

      final fieldDictionary = _getFieldDictionary(field);
      if (fieldDictionary == null) return null;

      return _extractImageBytesFromButtonIcon(fieldDictionary) ??
          _extractImageBytesFromButtonAppearance(fieldDictionary);
    } catch (_) {
      return null;
    } finally {
      document.dispose();
    }
  }

  static List<int>? setButtonIconImageBytes(
    List<int> pdfBytes,
    List<int> imageBytes, {
    String fieldName = characterImageFieldName,
  }) {
    final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
    try {
      final field = _findField(document.form, fieldName);
      if (field is! PdfButtonField) return null;

      final fieldDictionary = _getFieldDictionary(field);
      if (fieldDictionary == null) return null;

      final image = PdfBitmap(imageBytes);
      PdfImageHelper.save(image);
      final imageStream = PdfImageHelper.getImageStream(image);
      if (imageStream == null) return null;

      final geometry = _buildIconGeometry(image, field);
      final iconForm = _createIconFormStream(imageStream, geometry);

      _setButtonIcon(fieldDictionary, iconForm);
      _setButtonAppearance(fieldDictionary, iconForm, geometry);

      return document.saveSync();
    } catch (_) {
      return null;
    } finally {
      document.dispose();
    }
  }

  /// 将 PDF 按钮画像导入角色；图片不可用时保留原画像并返回 false。
  static bool importPortraitFromPdfBytes(
    Character character,
    List<int> pdfBytes,
  ) {
    try {
      final imageBytes = extractButtonIconImageBytes(pdfBytes);
      if (imageBytes == null || !_isUsablePortraitImage(imageBytes)) {
        return false;
      }

      character.profile.portraitBase64 = base64Encode(imageBytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 将角色画像写入 PDF 按钮；图片不可用时返回未修改的 PDF 字节。
  static List<int> exportPortraitToPdfBytes(
    Character character,
    List<int> pdfBytes,
  ) {
    final encodedPortrait = character.profile.portraitBase64.trim();
    if (encodedPortrait.isEmpty ||
        encodedPortrait.length > ((_maxPortraitImageBytes + 2) ~/ 3) * 4) {
      return pdfBytes;
    }

    try {
      final imageBytes = base64Decode(encodedPortrait);
      if (!_isUsablePortraitImage(imageBytes)) return pdfBytes;

      return setButtonIconImageBytes(pdfBytes, imageBytes) ?? pdfBytes;
    } catch (_) {
      return pdfBytes;
    }
  }

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
      readAdditionalFeaturesAndTraitsFromForm(form, r);

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

      importPortraitFromPdfBytes(character, bytes);
      document.dispose();
      return character;
    } catch (e) {
      throw Exception("读取 PDF 失败: $e");
    }
  }

  /// 导出角色卡 PDF
  static Future<void> exportCharacterPdfAsync(Character character) async {
    final ByteData fontData = await rootBundle.load('assets/fonts/simsun.ttc');
    final ByteData templateData = await rootBundle.load('assets/Character.pdf');
    final List<int> outputBytes = buildCharacterPdfBytes(
      character,
      templateData.buffer.asUint8List(),
      fontData.buffer.asUint8List(),
    );

    final p = character.profile;
    final String safeName = p.characterName.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
    final String fileName = safeName.isEmpty ? 'Unnamed_Character' : safeName;

    if (Platform.isAndroid || Platform.isIOS) {
      // 移动端：写临时文件 + 系统分享
      final Directory tempDir = await getTemporaryDirectory();
      await shareMobilePdfBytes(outputBytes, tempDir, fileName);
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

  @visibleForTesting
  static Future<void> shareMobilePdfBytes(
    List<int> pdfBytes,
    Directory tempDirectory,
    String baseName, {
    DateTime? exportedAt,
    Future<void> Function(XFile file, String text)? shareFile,
  }) async {
    final Directory shareDir = Directory(
      '${tempDirectory.path}/$_mobileShareDirectoryName',
    );
    await shareDir.create(recursive: true);
    final String shareFileName = buildMobileShareFileName(
      baseName,
      exportedAt ?? DateTime.now(),
    );
    final File outputFile = File('${shareDir.path}/$shareFileName');
    try {
      await outputFile.writeAsBytes(pdfBytes, flush: true);
      final XFile sharedFile = XFile(
        outputFile.path,
        mimeType: 'application/pdf',
      );
      if (shareFile != null) {
        await shareFile(sharedFile, '分享角色卡: $shareFileName');
      } else {
        await Share.shareXFiles(
          [sharedFile],
          text: '分享角色卡: $shareFileName',
        );
      }
    } finally {
      try {
        if (await outputFile.exists()) await outputFile.delete();
      } catch (_) {
        // 临时文件会由操作系统缓存清理；清理失败不应掩盖分享结果。
      }
    }
  }

  @visibleForTesting
  static String buildMobileShareFileName(String baseName, DateTime exportedAt) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    String threeDigits(int value) => value.toString().padLeft(3, '0');

    final String timestamp = '${exportedAt.year.toString().padLeft(4, '0')}'
        '${twoDigits(exportedAt.month)}${twoDigits(exportedAt.day)}_'
        '${twoDigits(exportedAt.hour)}${twoDigits(exportedAt.minute)}'
        '${twoDigits(exportedAt.second)}_'
        '${threeDigits(exportedAt.millisecond)}'
        '${threeDigits(exportedAt.microsecond)}';
    return '${baseName}_$timestamp.pdf';
  }

  @visibleForTesting
  static List<int> buildCharacterPdfBytes(
    Character character,
    List<int> templateBytes,
    List<int> cjkFontBytes,
  ) {
    _cjkFontData = Uint8List.fromList(cjkFontBytes);
    _cjkFonts.clear();

    final PdfDocument document = PdfDocument(inputBytes: templateBytes);
    late final List<int> outputBytes;
    try {
      _writeCharacterToForm(document.form, character);
      outputBytes = document.saveSync();
    } finally {
      document.dispose();
    }

    return exportPortraitToPdfBytes(character, outputBytes);
  }

  static void _writeCharacterToForm(PdfForm form, Character character) {
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
    writeAdditionalFeaturesAndTraitsToForm(form, r);

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
  }

  // ==================== 辅助方法 ====================

  static bool _isUsablePortraitImage(List<int> imageBytes) {
    if (imageBytes.isEmpty || imageBytes.length > _maxPortraitImageBytes) {
      return false;
    }

    try {
      final image = PdfBitmap(imageBytes);
      return image.width > 0 &&
          image.height > 0 &&
          image.width <= _maxPortraitImageDimension &&
          image.height <= _maxPortraitImageDimension;
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  static void readAdditionalFeaturesAndTraitsFromForm(
    PdfForm form,
    Roleplay roleplay,
  ) {
    final field = _findField(form, additionalFeaturesAndTraitsFieldName);
    if (field is PdfTextBoxField) {
      roleplay.additionalFeaturesAndTraits = field.text
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n');
    }
  }

  @visibleForTesting
  static void writeAdditionalFeaturesAndTraitsToForm(
    PdfForm form,
    Roleplay roleplay,
  ) {
    final field = _findField(form, additionalFeaturesAndTraitsFieldName);
    if (field is! PdfTextBoxField) return;
    _writeTextBox(field, roleplay.additionalFeaturesAndTraits);
  }

  static PdfField? _findField(PdfForm form, String fieldName) {
    final trimmedName = fieldName.trim();
    for (int i = 0; i < form.fields.count; i++) {
      final field = form.fields[i];
      if (field.name?.trim() == trimmedName) {
        return field;
      }
    }
    return null;
  }

  static PdfDictionary? _getFieldDictionary(PdfField field) {
    final element = IPdfWrapper.getElement(field);
    return _asDictionary(element);
  }

  static Uint8List? _extractImageBytesFromButtonIcon(
    PdfDictionary fieldDictionary,
  ) {
    final mk = _asDictionary(fieldDictionary[PdfDictionaryProperties.mk]);
    if (mk == null) return null;

    final icon = _asDictionary(mk[PdfDictionaryProperties.i]);
    if (icon == null) return null;

    return _extractFirstSupportedImageBytes(icon);
  }

  static Uint8List? _extractImageBytesFromButtonAppearance(
    PdfDictionary fieldDictionary,
  ) {
    final appearance = _asDictionary(
      fieldDictionary[PdfDictionaryProperties.ap],
    );
    if (appearance == null) return null;

    final normalAppearance = _asDictionary(
      appearance[PdfDictionaryProperties.n],
    );
    if (normalAppearance == null) return null;

    return _extractFirstSupportedImageBytes(normalAppearance);
  }

  static Uint8List? _extractFirstSupportedImageBytes(PdfDictionary object) {
    final stream = _asStream(object);
    if (stream != null && _isImageStream(stream)) {
      return _readSupportedImageStreamBytes(stream);
    }

    final resources = _asDictionary(object[PdfDictionaryProperties.resources]);
    final xObjects = _asDictionary(resources?[PdfDictionaryProperties.xObject]);
    final items = xObjects?.items;
    if (items == null) return null;

    for (final value in items.values) {
      final child = _asDictionary(value);
      if (child == null) continue;

      final imageBytes = _extractFirstSupportedImageBytes(child);
      if (imageBytes != null) return imageBytes;
    }

    return null;
  }

  static Uint8List? _readSupportedImageStreamBytes(PdfStream stream) {
    final data = stream.dataStream;
    if (data == null || data.length < 4) return null;

    if (_hasFilter(stream, PdfDictionaryProperties.dctDecode)) {
      return Uint8List.fromList(data);
    }

    if (_hasFilter(stream, PdfDictionaryProperties.flateDecode) ||
        stream[PdfDictionaryProperties.filter] == null) {
      return _wrapPdfImageStreamAsPng(stream);
    }

    return null;
  }

  static bool _isImageStream(PdfStream stream) {
    final subtype = _dereference(stream[PdfDictionaryProperties.subtype]);
    return subtype is PdfName && subtype.name == PdfDictionaryProperties.image;
  }

  static bool _hasFilter(PdfStream stream, String filterName) {
    final filter = _dereference(stream[PdfDictionaryProperties.filter]);
    if (filter is PdfName) {
      return filter.name == filterName;
    }

    if (filter is PdfArray) {
      for (final value in filter.elements) {
        final item = _dereference(value);
        if (item is PdfName && item.name == filterName) {
          return true;
        }
      }
    }

    return false;
  }

  static Uint8List? _wrapPdfImageStreamAsPng(PdfStream stream) {
    final width = _getDictionaryInt(stream, PdfDictionaryProperties.width);
    final height = _getDictionaryInt(stream, PdfDictionaryProperties.height);
    final bitsPerComponent = _getDictionaryInt(
      stream,
      PdfDictionaryProperties.bitsPerComponent,
    );
    if (width == null ||
        height == null ||
        bitsPerComponent != 8 ||
        width <= 0 ||
        height <= 0) {
      return null;
    }

    final colorSpace = _dereference(stream[PdfDictionaryProperties.colorSpace]);
    final int colorChannels;
    final int pngColorType;
    if (colorSpace is PdfName &&
        colorSpace.name == PdfDictionaryProperties.deviceRGB) {
      colorChannels = 3;
      pngColorType = 2;
    } else if (colorSpace is PdfName &&
        colorSpace.name == PdfDictionaryProperties.deviceGray) {
      colorChannels = 1;
      pngColorType = 0;
    } else {
      return null;
    }

    final imageData = _readPossiblyFlateDecodedData(stream);
    if (imageData == null) return null;

    final pixelCount = width * height;
    final expectedColorLength = pixelCount * colorChannels;
    if (imageData.length < expectedColorLength) return null;

    final alphaData = _readAlphaMaskData(stream, pixelCount);
    final rawPngRows = alphaData == null
        ? _createPngRows(imageData, width, height, colorChannels, colorChannels)
        : _createRgbaPngRows(
            imageData,
            alphaData,
            width,
            height,
            colorChannels,
          );
    final colorType = alphaData == null ? pngColorType : 6;

    return Uint8List.fromList(
      _createPngBytes(
        width: width,
        height: height,
        bitDepth: 8,
        colorType: colorType,
        rawRows: rawPngRows,
      ),
    );
  }

  static List<int>? _readAlphaMaskData(PdfStream stream, int pixelCount) {
    final maskStream = _asStream(stream[PdfDictionaryProperties.sMask]);
    if (maskStream == null) return null;

    final bitsPerComponent = _getDictionaryInt(
      maskStream,
      PdfDictionaryProperties.bitsPerComponent,
    );
    if (bitsPerComponent != 8) return null;

    final maskData = _readPossiblyFlateDecodedData(maskStream);
    if (maskData == null || maskData.length < pixelCount) return null;

    return maskData;
  }

  static List<int>? _readPossiblyFlateDecodedData(PdfStream stream) {
    final data = stream.dataStream;
    if (data == null) return null;

    if (!_hasFilter(stream, PdfDictionaryProperties.flateDecode)) {
      return List<int>.from(data);
    }

    final copiedStream = PdfStream(PdfDictionary(stream), List<int>.from(data));
    copiedStream.decompress();
    return copiedStream.dataStream == null
        ? null
        : List<int>.from(copiedStream.dataStream!);
  }

  static List<int> _createPngRows(
    List<int> imageData,
    int width,
    int height,
    int sourceChannels,
    int targetChannels,
  ) {
    final rowLength = width * targetChannels;
    final rows = <int>[];
    for (int y = 0; y < height; y++) {
      rows.add(0);
      final sourceRowStart = y * width * sourceChannels;
      rows.addAll(
        imageData.sublist(sourceRowStart, sourceRowStart + rowLength),
      );
    }
    return rows;
  }

  static List<int> _createRgbaPngRows(
    List<int> imageData,
    List<int> alphaData,
    int width,
    int height,
    int sourceChannels,
  ) {
    final rows = <int>[];
    for (int y = 0; y < height; y++) {
      rows.add(0);
      for (int x = 0; x < width; x++) {
        final pixelIndex = y * width + x;
        final colorIndex = pixelIndex * sourceChannels;
        if (sourceChannels == 1) {
          final gray = imageData[colorIndex];
          rows.add(gray);
          rows.add(gray);
          rows.add(gray);
        } else {
          rows.add(imageData[colorIndex]);
          rows.add(imageData[colorIndex + 1]);
          rows.add(imageData[colorIndex + 2]);
        }
        rows.add(alphaData[pixelIndex]);
      }
    }
    return rows;
  }

  static List<int> _createPngBytes({
    required int width,
    required int height,
    required int bitDepth,
    required int colorType,
    required List<int> rawRows,
  }) {
    final bytes = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    _addPngChunk(bytes, 'IHDR', <int>[
      ..._uint32Bytes(width),
      ..._uint32Bytes(height),
      bitDepth,
      colorType,
      0,
      0,
      0,
    ]);
    _addPngChunk(bytes, 'IDAT', ZLibEncoder().convert(rawRows));
    _addPngChunk(bytes, 'IEND', const <int>[]);
    return bytes;
  }

  static void _addPngChunk(List<int> output, String type, List<int> data) {
    final typeBytes = type.codeUnits;
    output.addAll(_uint32Bytes(data.length));
    output.addAll(typeBytes);
    output.addAll(data);
    output.addAll(_uint32Bytes(_crc32(<int>[...typeBytes, ...data])));
  }

  static List<int> _uint32Bytes(int value) {
    return <int>[
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
  }

  static int _crc32(List<int> data) {
    int crc = 0xffffffff;
    for (final byte in data) {
      crc ^= byte;
      for (int i = 0; i < 8; i++) {
        if ((crc & 1) == 1) {
          crc = 0xedb88320 ^ (crc >> 1);
        } else {
          crc >>= 1;
        }
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }

  static int? _getDictionaryInt(PdfDictionary dictionary, String key) {
    final value = _dereference(dictionary[key]);
    return value is PdfNumber ? value.value?.toInt() : null;
  }

  static _ButtonIconGeometry _buildIconGeometry(
    PdfBitmap image,
    PdfButtonField field,
  ) {
    final bounds = field.bounds;
    final buttonWidth = max(1.0, bounds.width);
    final buttonHeight = max(1.0, bounds.height);
    final imageWidth = max(1.0, image.width * 0.24);
    final imageHeight = max(1.0, image.height * 0.24);
    final clipWidth = max(1.0, buttonWidth - 4);
    final clipHeight = max(1.0, buttonHeight - 4);
    final scale = min(clipWidth / imageWidth, clipHeight / imageHeight);
    final drawnWidth = imageWidth * scale;
    final drawnHeight = imageHeight * scale;

    return _ButtonIconGeometry(
      buttonWidth: buttonWidth,
      buttonHeight: buttonHeight,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      appearanceClipWidth: clipWidth,
      appearanceClipHeight: clipHeight,
      appearanceScale: scale,
      appearanceOffsetX: 2 + (clipWidth - drawnWidth) / 2,
      appearanceOffsetY: 2 + (clipHeight - drawnHeight) / 2,
    );
  }

  static PdfStream _createIconFormStream(
    PdfStream imageStream,
    _ButtonIconGeometry geometry,
  ) {
    final iconForm = PdfStream();
    iconForm[PdfDictionaryProperties.type] = PdfName(
      PdfDictionaryProperties.xObject,
    );
    iconForm[PdfDictionaryProperties.subtype] = PdfName(
      PdfDictionaryProperties.form,
    );
    iconForm[PdfDictionaryProperties.bBox] = PdfArray(<double>[
      0,
      0,
      geometry.imageWidth,
      geometry.imageHeight,
    ]);
    iconForm[PdfDictionaryProperties.matrix] = PdfArray(<double>[
      1,
      0,
      0,
      1,
      0,
      0,
    ]);
    iconForm[PdfDictionaryProperties.resources] = _createResourcesDictionary(
      'Im0',
      imageStream,
      includeImageProcSet: true,
    );
    iconForm.compress = false;
    iconForm.write(
      'q\n'
      '${_pdfNumber(geometry.imageWidth)} 0 0 '
      '${_pdfNumber(geometry.imageHeight)} 0 0 cm\n'
      '/Im0 Do\n'
      'Q\n',
    );

    return iconForm;
  }

  static void _setButtonIcon(
    PdfDictionary fieldDictionary,
    PdfStream iconForm,
  ) {
    final mk =
        _asDictionary(fieldDictionary[PdfDictionaryProperties.mk]) ??
        PdfDictionary();
    mk[PdfDictionaryProperties.i] = PdfReferenceHolder(iconForm);
    if (!mk.containsKey('IF')) {
      mk['IF'] = PdfDictionary();
    }
    if (!mk.containsKey('TP')) {
      mk['TP'] = PdfNumber(1);
    }
    fieldDictionary[PdfDictionaryProperties.mk] = mk;
  }

  static void _setButtonAppearance(
    PdfDictionary fieldDictionary,
    PdfStream iconForm,
    _ButtonIconGeometry geometry,
  ) {
    final appearance =
        _asDictionary(fieldDictionary[PdfDictionaryProperties.ap]) ??
        PdfDictionary();
    appearance[PdfDictionaryProperties.n] = PdfReferenceHolder(
      _createNormalAppearanceStream(iconForm, geometry),
    );
    fieldDictionary[PdfDictionaryProperties.ap] = appearance;
  }

  static PdfStream _createNormalAppearanceStream(
    PdfStream iconForm,
    _ButtonIconGeometry geometry,
  ) {
    final appearance = PdfStream();
    appearance[PdfDictionaryProperties.type] = PdfName(
      PdfDictionaryProperties.xObject,
    );
    appearance[PdfDictionaryProperties.subtype] = PdfName(
      PdfDictionaryProperties.form,
    );
    appearance[PdfDictionaryProperties.bBox] = PdfArray(<double>[
      0,
      0,
      geometry.buttonWidth,
      geometry.buttonHeight,
    ]);
    appearance[PdfDictionaryProperties.matrix] = PdfArray(<double>[
      1,
      0,
      0,
      1,
      0,
      0,
    ]);
    appearance[PdfDictionaryProperties.resources] = _createResourcesDictionary(
      'FRM',
      iconForm,
      includeImageProcSet: false,
    );
    appearance.compress = false;
    appearance.write(
      'q\n'
      '1 1 ${_pdfNumber(geometry.appearanceClipWidth)} '
      '${_pdfNumber(geometry.appearanceClipHeight)} re\n'
      'W\n'
      'n\n'
      'q\n'
      '${_pdfNumber(geometry.appearanceScale)} 0 0 '
      '${_pdfNumber(geometry.appearanceScale)} '
      '${_pdfNumber(geometry.appearanceOffsetX)} '
      '${_pdfNumber(geometry.appearanceOffsetY)} cm\n'
      '/FRM Do\n'
      'Q\n'
      'Q\n',
    );

    return appearance;
  }

  static PdfDictionary _createResourcesDictionary(
    String objectName,
    IPdfPrimitive object, {
    required bool includeImageProcSet,
  }) {
    final xObjects = PdfDictionary();
    xObjects[objectName] = PdfReferenceHolder(object);

    final resources = PdfDictionary();
    resources[PdfDictionaryProperties.xObject] = xObjects;
    if (includeImageProcSet) {
      resources[PdfDictionaryProperties.procSet] = PdfArray(<PdfName>[
        PdfName(PdfDictionaryProperties.pdf),
        PdfName('ImageC'),
      ]);
    }
    return resources;
  }

  static IPdfPrimitive? _dereference(IPdfPrimitive? object) {
    if (object == null) return null;
    return PdfCrossTable.dereference(object);
  }

  static PdfDictionary? _asDictionary(IPdfPrimitive? object) {
    final dereferenced = _dereference(object);
    return dereferenced is PdfDictionary ? dereferenced : null;
  }

  static PdfStream? _asStream(IPdfPrimitive? object) {
    final dereferenced = _dereference(object);
    return dereferenced is PdfStream ? dereferenced : null;
  }

  static String _pdfNumber(double value) {
    var text = value.toStringAsFixed(4);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    if (text == '-0' || text.isEmpty) return '0';
    return text;
  }

  static String _getText(Map<String, PdfField> map, String key) {
    final field = map[key.trim()];
    if (field is PdfTextBoxField) {
      String rawText = field.text;
      return rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    }
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
      _writeTextBox(field, value);
    }
  }

  static void _writeTextBox(PdfTextBoxField field, String value) {
    if (_cjkFontData != null) {
      field.font = _findFittingFont(field, value);
    }
    _enableTextScrolling(field);
    field.text = value;
  }

  static PdfTrueTypeFont _findFittingFont(PdfTextBoxField field, String value) {
    final double maximumSize = field.multiline
        ? _multilineMaxFontSize
        : _singleLineMaxFontSize;
    final int maximumStep = (maximumSize * _fontSizeStepsPerPoint).round();
    final int minimumStep = (_minimumReadableFontSize * _fontSizeStepsPerPoint)
        .round();

    for (int step = maximumStep; step >= minimumStep; step--) {
      final font = _fontAtStep(step);
      if (_textFitsField(field, value, font)) return font;
    }
    return _fontAtStep(minimumStep);
  }

  static PdfTrueTypeFont _fontAtStep(int step) {
    return _cjkFonts.putIfAbsent(
      step,
      () => PdfTrueTypeFont(_cjkFontData!, step / _fontSizeStepsPerPoint),
    );
  }

  static bool _textFitsField(
    PdfTextBoxField field,
    String value,
    PdfFont font,
  ) {
    if (value.isEmpty) return true;

    final double horizontalPadding = 4.0 * max(1, field.borderWidth);
    final double verticalPadding = 4.0 * max(1, field.borderWidth);
    final double availableWidth = max(
      1,
      field.bounds.width - horizontalPadding,
    );
    final double availableHeight = max(
      1,
      field.bounds.height - verticalPadding,
    );

    if (!field.multiline) {
      final Size measured = font.measureString(value);
      return measured.width <= availableWidth &&
          measured.height <= availableHeight;
    }

    final format = PdfStringFormat(alignment: field.textAlignment)
      ..lineLimit = false;
    final Size measured = font.measureString(
      value,
      layoutArea: Size(availableWidth, 1000000),
      format: format,
    );
    return measured.width <= availableWidth &&
        measured.height <= availableHeight;
  }

  static void _enableTextScrolling(PdfTextBoxField field) {
    // Syncfusion 24.2.9 的 loaded-field scrollable setter 错误地依赖
    // spellCheck 状态，因此直接清除 PDF 规范中的 DoNotScroll 位。
    final dictionary = _getFieldDictionary(field);
    if (dictionary == null) return;

    final flagsValue = _dereference(dictionary['Ff']);
    final int flags = flagsValue is PdfNumber
        ? flagsValue.value?.toInt() ?? 0
        : 0;
    dictionary['Ff'] = PdfNumber(flags & ~_doNotScrollFieldFlag);
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

class _ButtonIconGeometry {
  const _ButtonIconGeometry({
    required this.buttonWidth,
    required this.buttonHeight,
    required this.imageWidth,
    required this.imageHeight,
    required this.appearanceClipWidth,
    required this.appearanceClipHeight,
    required this.appearanceScale,
    required this.appearanceOffsetX,
    required this.appearanceOffsetY,
  });

  final double buttonWidth;
  final double buttonHeight;
  final double imageWidth;
  final double imageHeight;
  final double appearanceClipWidth;
  final double appearanceClipHeight;
  final double appearanceScale;
  final double appearanceOffsetX;
  final double appearanceOffsetY;
}
