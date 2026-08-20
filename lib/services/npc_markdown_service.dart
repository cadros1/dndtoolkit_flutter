import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/dm_models.dart';

enum NpcMarkdownImportStatus {
  verified,
  modified,
  arbitrary,
  unsupported,
  invalid,
}

class NpcMarkdownImportResult {
  final String fileName;
  final NpcCard? card;
  final String categoryName;
  final NpcMarkdownImportStatus status;
  final String? recordedChecksum;
  final String? calculatedChecksum;
  final List<String> recognizedFields;
  final List<String> missingFields;
  final List<String> warnings;
  final List<String> unrecognizedContent;
  final String? errorMessage;

  const NpcMarkdownImportResult({
    required this.fileName,
    required this.card,
    this.categoryName = '',
    required this.status,
    this.recordedChecksum,
    this.calculatedChecksum,
    this.recognizedFields = const [],
    this.missingFields = const [],
    this.warnings = const [],
    this.unrecognizedContent = const [],
    this.errorMessage,
  });

  bool get importable =>
      card != null && status != NpcMarkdownImportStatus.invalid;

  String get statusLabel => switch (status) {
    NpcMarkdownImportStatus.verified => '校验一致',
    NpcMarkdownImportStatus.modified => '文件已修改',
    NpcMarkdownImportStatus.arbitrary => '尽力识别',
    NpcMarkdownImportStatus.unsupported => '版本不受支持',
    NpcMarkdownImportStatus.invalid => '无法导入',
  };
}

enum NpcMarkdownExportDisposition { saved, shared, cancelled }

class NpcMarkdownExportOutcome {
  final NpcMarkdownExportDisposition disposition;
  final String fileName;

  const NpcMarkdownExportOutcome(this.disposition, this.fileName);
}

class NpcMarkdownCodec {
  static const formatVersion = 1;
  static const formatKey = 'DnDToolkit-NPC';
  static const checksumKey = 'SHA256';

  static const _textHeaderFields = <String>[
    '名称',
    '分类',
    '体型与生物类型',
    '速度',
    '挑战等级',
    '豁免',
    '技能',
    '伤害易伤',
    '伤害抗性',
    '伤害免疫',
    '状态免疫',
    '感官',
    '语言',
    '备注',
  ];

  static const _numericHeaderFields = <String>[
    '护甲等级',
    '最大生命值',
    '力量',
    '力量调整值',
    '敏捷',
    '敏捷调整值',
    '体质',
    '体质调整值',
    '智力',
    '智力调整值',
    '感知',
    '感知调整值',
    '魅力',
    '魅力调整值',
  ];

  static const _entrySections = <String>['特性', '动作', '附赠动作', '反应', '传奇动作'];

  static const _requiredFields = <String>{
    ..._textHeaderFields,
    ..._numericHeaderFields,
    ..._entrySections,
  };

  static String exportCard(NpcCard card, {required String categoryName}) {
    card.abilities.synchronizeModifiers();
    final ability = card.abilities;
    final lines = <String>[
      '---',
      '$formatKey: $formatVersion',
      '名称: ${jsonEncode(card.name)}',
      '分类: ${jsonEncode(categoryName)}',
      '体型与生物类型: ${jsonEncode(card.sizeAndType)}',
      '护甲等级: ${card.armorClass}',
      '最大生命值: ${card.maximumHitPoints}',
      '速度: ${jsonEncode(card.speed)}',
      '挑战等级: ${jsonEncode(card.challengeRating)}',
      '力量: ${ability.strength}',
      '力量调整值: ${_signed(ability.strengthModifier)}',
      '敏捷: ${ability.dexterity}',
      '敏捷调整值: ${_signed(ability.dexterityModifier)}',
      '体质: ${ability.constitution}',
      '体质调整值: ${_signed(ability.constitutionModifier)}',
      '智力: ${ability.intelligence}',
      '智力调整值: ${_signed(ability.intelligenceModifier)}',
      '感知: ${ability.wisdom}',
      '感知调整值: ${_signed(ability.wisdomModifier)}',
      '魅力: ${ability.charisma}',
      '魅力调整值: ${_signed(ability.charismaModifier)}',
      '豁免: ${jsonEncode(card.saves)}',
      '技能: ${jsonEncode(card.skills)}',
      '伤害易伤: ${jsonEncode(card.damageVulnerabilities)}',
      '伤害抗性: ${jsonEncode(card.damageResistances)}',
      '伤害免疫: ${jsonEncode(card.damageImmunities)}',
      '状态免疫: ${jsonEncode(card.conditionImmunities)}',
      '感官: ${jsonEncode(card.senses)}',
      '语言: ${jsonEncode(card.languages)}',
      '备注: ${jsonEncode(card.notes)}',
      '---',
      '',
    ];
    _writeEntries(lines, '特性', card.traits);
    _writeEntries(lines, '动作', card.actions);
    _writeEntries(lines, '附赠动作', card.bonusActions);
    _writeEntries(lines, '反应', card.reactions);
    _writeEntries(lines, '传奇动作', card.legendaryActions);
    final withoutChecksum = '${lines.join('\n')}\n';
    final checksum = calculateChecksum(withoutChecksum);
    lines.insert(2, '$checksumKey: $checksum');
    return '${lines.join('\n')}\n';
  }

  static String exportBlankTemplate() => exportCard(
    NpcCard(name: '', categoryId: defaultNpcCategoryId),
    categoryName: defaultNpcCategoryName,
  );

  static NpcMarkdownImportResult parse(String fileName, String source) {
    final normalized = normalizeNewlines(source).replaceFirst('\uFEFF', '');
    if (normalized.trim().isEmpty) {
      return NpcMarkdownImportResult(
        fileName: fileName,
        card: null,
        status: NpcMarkdownImportStatus.invalid,
        errorMessage: '文件为空。请填写 NPC 内容后重试。',
      );
    }

    final frontMatter = _readFrontMatter(normalized);
    final rawVersion = frontMatter.values[formatKey];
    final version = int.tryParse(rawVersion ?? '');
    if (version == formatVersion) {
      return _parseApplicationFile(fileName, normalized, frontMatter);
    }

    final result = _parseArbitraryFile(
      fileName,
      normalized,
      frontMatter,
      unsupportedVersion: rawVersion,
    );
    return result;
  }

  static String normalizeNewlines(String value) =>
      value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  static String canonicalContent(String value) {
    final lines = normalizeNewlines(value).split('\n');
    var inFrontMatter = false;
    var removed = false;
    final canonical = <String>[];
    for (final line in lines) {
      if (line.trim() == '---') {
        inFrontMatter = !inFrontMatter;
        canonical.add(line);
        continue;
      }
      if (inFrontMatter && !removed && line.startsWith('$checksumKey:')) {
        removed = true;
        continue;
      }
      canonical.add(line);
    }
    return canonical.join('\n');
  }

  static String calculateChecksum(String value) =>
      sha256.convert(utf8.encode(canonicalContent(value))).toString();

  static void _writeEntries(
    List<String> lines,
    String title,
    List<NpcFeatureEntry> entries,
  ) {
    lines.add('# $title');
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      lines
        ..add('')
        ..add('## 条目 ${index + 1}')
        ..add('名称: ${jsonEncode(entry.name)}')
        ..add('描述: ${jsonEncode(entry.description)}');
    }
    lines.add('');
  }

  static String _signed(int value) => value >= 0 ? '+$value' : '$value';

  static NpcMarkdownImportResult _parseApplicationFile(
    String fileName,
    String content,
    _FrontMatter frontMatter,
  ) {
    final warnings = <String>[];
    final recordedChecksum = frontMatter.values[checksumKey]?.toLowerCase();
    final calculatedChecksum = calculateChecksum(content);
    final validChecksum =
        recordedChecksum != null &&
        RegExp(r'^[0-9a-f]{64}$').hasMatch(recordedChecksum) &&
        recordedChecksum == calculatedChecksum;
    if (!validChecksum) {
      warnings.add('文件在导出后被修改，或记录的 SHA-256 校验值缺失/无效。请核对预览后再导入。');
    }

    final accumulator = _ParseAccumulator();
    for (final entry in frontMatter.values.entries) {
      if (entry.key == formatKey || entry.key == checksumKey) continue;
      if (!accumulator.applyField(entry.key, entry.value)) {
        accumulator.addUnrecognized('${entry.key}: ${entry.value}');
      }
    }
    accumulator.parseApplicationEntries(
      content.split('\n'),
      frontMatter.endLine + 1,
    );

    final missing = _requiredFields
        .difference(accumulator.recognizedFields.toSet())
        .toList();
    if (missing.isNotEmpty) {
      warnings.add('缺少 ${missing.length} 个应用格式字段；缺失字段将使用安全默认值。');
    }
    accumulator.validateRecordedModifiers(warnings);

    if (!accumulator.hasMeaningfulContent) {
      return NpcMarkdownImportResult(
        fileName: fileName,
        card: null,
        categoryName: accumulator.categoryName,
        status: NpcMarkdownImportStatus.invalid,
        recordedChecksum: recordedChecksum,
        calculatedChecksum: calculatedChecksum,
        recognizedFields: accumulator.recognizedFields,
        missingFields: missing,
        warnings: warnings,
        unrecognizedContent: accumulator.unrecognized,
        errorMessage: '没有识别到有意义的 NPC 内容。请至少填写名称、核心数值或一个特性/动作条目。',
      );
    }

    return NpcMarkdownImportResult(
      fileName: fileName,
      card: accumulator.finishCard(),
      categoryName: accumulator.categoryName,
      status: validChecksum
          ? NpcMarkdownImportStatus.verified
          : NpcMarkdownImportStatus.modified,
      recordedChecksum: recordedChecksum,
      calculatedChecksum: calculatedChecksum,
      recognizedFields: accumulator.recognizedFields,
      missingFields: missing,
      warnings: warnings,
      unrecognizedContent: accumulator.unrecognized,
    );
  }

  static NpcMarkdownImportResult _parseArbitraryFile(
    String fileName,
    String content,
    _FrontMatter frontMatter, {
    String? unsupportedVersion,
  }) {
    final accumulator = _ParseAccumulator();
    for (final entry in frontMatter.values.entries) {
      if (entry.key == formatKey || entry.key == checksumKey) continue;
      if (!accumulator.applyField(entry.key, entry.value)) {
        accumulator.addUnrecognized('${entry.key}: ${entry.value}');
      }
    }
    accumulator.parseArbitraryBody(
      content.split('\n'),
      frontMatter.hasFrontMatter ? frontMatter.endLine + 1 : 0,
    );

    final warnings = <String>[
      if (unsupportedVersion != null)
        '不支持 DnDToolkit-NPC: $unsupportedVersion，已按任意 Markdown 尽力识别。',
      if (unsupportedVersion == null)
        '文件没有受支持的 DnDToolkit-NPC 格式标识，以下内容为尽力识别结果。',
    ];
    if (!accumulator.hasMeaningfulContent) {
      return NpcMarkdownImportResult(
        fileName: fileName,
        card: null,
        categoryName: accumulator.categoryName,
        status: NpcMarkdownImportStatus.invalid,
        recognizedFields: accumulator.recognizedFields,
        warnings: warnings,
        unrecognizedContent: accumulator.unrecognized,
        errorMessage: '没有识别到有意义的 NPC 内容。可按空白模板补充中文字段后重试。',
      );
    }

    return NpcMarkdownImportResult(
      fileName: fileName,
      card: accumulator.finishCard(),
      categoryName: accumulator.categoryName,
      status: unsupportedVersion == null
          ? NpcMarkdownImportStatus.arbitrary
          : NpcMarkdownImportStatus.unsupported,
      recognizedFields: accumulator.recognizedFields,
      warnings: warnings,
      unrecognizedContent: accumulator.unrecognized,
    );
  }

  static _FrontMatter _readFrontMatter(String content) {
    final lines = content.split('\n');
    if (lines.isEmpty || lines.first.trim() != '---') {
      return const _FrontMatter({}, -1, false);
    }
    final values = <String, String>{};
    for (var index = 1; index < lines.length; index++) {
      final line = lines[index];
      if (line.trim() == '---') {
        return _FrontMatter(values, index, true);
      }
      final match = RegExp(r'^([^:：]+)[:：]\s*(.*)$').firstMatch(line);
      if (match == null) continue;
      values[match.group(1)!.trim()] = _decodeScalar(match.group(2)!.trim());
    }
    // 没有闭合分隔线时不把整份文件吞成 front matter；按普通 Markdown
    // 继续尽力识别，并在预览的未识别内容中保留原文。
    return const _FrontMatter({}, -1, false);
  }

  static String _decodeScalar(String value) {
    if (value.startsWith('"')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is String) return decoded;
      } catch (_) {
        return value;
      }
    }
    return value;
  }
}

class NpcMarkdownService {
  static const maxImportBytes = 2 * 1024 * 1024;
  static const _shareDirectoryName = 'dndtoolkit_npc_markdown_share';

  Future<List<NpcMarkdownImportResult>?> pickImportFiles() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['md', 'markdown'],
      allowMultiple: true,
      withData: true,
    );
    if (picked == null) return null;
    final results = <NpcMarkdownImportResult>[];
    for (final file in picked.files) {
      try {
        final bytes =
            file.bytes ??
            (file.path == null ? null : await File(file.path!).readAsBytes());
        if (bytes == null) {
          results.add(_fileError(file.name, '系统没有提供可读取的文件内容。请重新选择该文件。'));
          continue;
        }
        if (bytes.length > maxImportBytes) {
          results.add(_fileError(file.name, '文件超过 2 MB。请拆分或精简内容后重试。'));
          continue;
        }
        final content = utf8.decode(bytes, allowMalformed: false);
        results.add(NpcMarkdownCodec.parse(file.name, content));
      } catch (error) {
        results.add(
          _fileError(file.name, '文件不是有效的 UTF-8 Markdown，或读取失败：$error'),
        );
      }
    }
    return results;
  }

  Future<NpcMarkdownExportOutcome> exportCard(
    NpcCard card, {
    required String categoryName,
  }) => _exportText(
    NpcMarkdownCodec.exportCard(card, categoryName: categoryName),
    _safeFileName(card.name.trim().isEmpty ? '未命名_NPC' : card.name),
  );

  Future<NpcMarkdownExportOutcome> exportBlankTemplate() => _exportText(
    NpcMarkdownCodec.exportBlankTemplate(),
    'DnDToolkit_NPC_空白模板',
  );

  Future<NpcMarkdownExportOutcome> _exportText(
    String content,
    String baseName,
  ) async {
    if (Platform.isAndroid) {
      final tempDirectory = await getTemporaryDirectory();
      return shareMobileText(content, tempDirectory, baseName);
    }
    final fileName = '$baseName.md';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: '导出 NPC Markdown',
      fileName: fileName,
      allowedExtensions: const ['md'],
    );
    if (savePath == null) {
      return NpcMarkdownExportOutcome(
        NpcMarkdownExportDisposition.cancelled,
        fileName,
      );
    }
    final normalizedPath = savePath.toLowerCase().endsWith('.md')
        ? savePath
        : '$savePath.md';
    await File(
      normalizedPath,
    ).writeAsString(content, encoding: utf8, flush: true);
    return NpcMarkdownExportOutcome(
      NpcMarkdownExportDisposition.saved,
      File(normalizedPath).uri.pathSegments.last,
    );
  }

  @visibleForTesting
  Future<NpcMarkdownExportOutcome> shareMobileText(
    String content,
    Directory tempDirectory,
    String baseName, {
    DateTime? exportedAt,
    Future<void> Function(XFile file, String text)? shareFile,
  }) async {
    final shareDirectory = Directory(
      '${tempDirectory.path}${Platform.pathSeparator}$_shareDirectoryName',
    );
    await shareDirectory.create(recursive: true);
    final fileName = buildMobileFileName(
      baseName,
      exportedAt ?? DateTime.now(),
    );
    final output = File(
      '${shareDirectory.path}${Platform.pathSeparator}$fileName',
    );
    try {
      await output.writeAsString(content, encoding: utf8, flush: true);
      final xFile = XFile(output.path, mimeType: 'text/markdown');
      if (shareFile != null) {
        await shareFile(xFile, '分享 NPC 卡：$fileName');
      } else {
        await Share.shareXFiles([xFile], text: '分享 NPC 卡：$fileName');
      }
      return NpcMarkdownExportOutcome(
        NpcMarkdownExportDisposition.shared,
        fileName,
      );
    } finally {
      try {
        if (await output.exists()) await output.delete();
      } catch (_) {
        // 临时文件清理失败不应掩盖分享结果，系统缓存仍可后续清理。
      }
    }
  }

  @visibleForTesting
  static String buildMobileFileName(String baseName, DateTime exportedAt) {
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    final stamp =
        '${exportedAt.year.toString().padLeft(4, '0')}'
        '${two(exportedAt.month)}${two(exportedAt.day)}_'
        '${two(exportedAt.hour)}${two(exportedAt.minute)}${two(exportedAt.second)}_'
        '${three(exportedAt.millisecond)}${three(exportedAt.microsecond)}';
    return '${_safeFileName(baseName)}_$stamp.md';
  }

  static NpcMarkdownImportResult _fileError(String name, String message) =>
      NpcMarkdownImportResult(
        fileName: name,
        card: null,
        status: NpcMarkdownImportStatus.invalid,
        errorMessage: message,
      );

  static String _safeFileName(String value) {
    final safe = value.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
    return safe.isEmpty ? '未命名_NPC' : safe;
  }
}

class _FrontMatter {
  final Map<String, String> values;
  final int endLine;
  final bool hasFrontMatter;

  const _FrontMatter(this.values, this.endLine, this.hasFrontMatter);
}

class _ParseAccumulator {
  final card = NpcCard();
  final recognizedFields = <String>[];
  final unrecognized = <String>[];
  String categoryName = '';
  final _recordedModifiers = <String, int>{};

  static const _aliases = <String, String>{
    '姓名': '名称',
    '名字': '名称',
    'name': '名称',
    '分类名称': '分类',
    '类型': '体型与生物类型',
    '生物类型': '体型与生物类型',
    'ac': '护甲等级',
    '护甲': '护甲等级',
    'hp': '最大生命值',
    '生命值': '最大生命值',
    '最大hp': '最大生命值',
    'cr': '挑战等级',
    '伤害抗性与免疫': '伤害抗性',
    '状态免疫能力': '状态免疫',
  };

  static const _sectionAliases = <String, String>{
    '特性': '特性',
    '能力': '特性',
    '动作': '动作',
    '行动': '动作',
    '附赠动作': '附赠动作',
    '奖励动作': '附赠动作',
    '反应': '反应',
    '传奇动作': '传奇动作',
  };

  bool applyField(String rawKey, String rawValue) {
    final normalizedKey = rawKey.replaceAll('*', '').replaceAll('`', '').trim();
    final key = _aliases[normalizedKey.toLowerCase()] ?? normalizedKey;
    final value = rawValue.trim();
    switch (key) {
      case '名称':
        card.name = value;
      case '分类':
        categoryName = value;
      case '体型与生物类型':
        card.sizeAndType = value;
      case '护甲等级':
        card.armorClass = _readInt(value, 10).clamp(0, 999);
      case '最大生命值':
        card.maximumHitPoints = _readInt(value).clamp(0, 999999);
      case '速度':
        card.speed = value;
      case '挑战等级':
        card.challengeRating = value;
      case '力量':
        card.abilities.strength = _readInt(value, 10);
      case '敏捷':
        card.abilities.dexterity = _readInt(value, 10);
      case '体质':
        card.abilities.constitution = _readInt(value, 10);
      case '智力':
        card.abilities.intelligence = _readInt(value, 10);
      case '感知':
        card.abilities.wisdom = _readInt(value, 10);
      case '魅力':
        card.abilities.charisma = _readInt(value, 10);
      case '力量调整值':
      case '敏捷调整值':
      case '体质调整值':
      case '智力调整值':
      case '感知调整值':
      case '魅力调整值':
        _recordedModifiers[key] = _readInt(value);
      case '豁免':
        card.saves = value;
      case '技能':
        card.skills = value;
      case '伤害易伤':
        card.damageVulnerabilities = value;
      case '伤害抗性':
        card.damageResistances = value;
      case '伤害免疫':
        card.damageImmunities = value;
      case '状态免疫':
        card.conditionImmunities = value;
      case '感官':
        card.senses = value;
      case '语言':
        card.languages = value;
      case '备注':
        card.notes = value;
      default:
        return false;
    }
    _record(key);
    return true;
  }

  void parseApplicationEntries(List<String> lines, int start) {
    String? section;
    NpcFeatureEntry? current;
    void flush() {
      final activeSection = section;
      final activeEntry = current;
      if (activeSection != null && activeEntry != null) {
        _entriesFor(activeSection).add(activeEntry);
      }
      current = null;
    }

    for (var index = start; index < lines.length; index++) {
      final line = lines[index];
      final heading = RegExp(r'^#\s+(.+)$').firstMatch(line);
      if (heading != null) {
        flush();
        final candidate = heading.group(1)!.trim();
        section = _sectionAliases[candidate];
        if (section == null) addUnrecognized(line);
        final activeSection = section;
        if (activeSection != null) _record(activeSection);
        continue;
      }
      if (section == null) {
        if (line.trim().isNotEmpty) addUnrecognized(line);
        continue;
      }
      if (RegExp(r'^##\s+').hasMatch(line)) {
        flush();
        current = NpcFeatureEntry();
        continue;
      }
      final activeEntry = current;
      if (activeEntry == null || line.trim().isEmpty) continue;
      final pair = RegExp(r'^(名称|描述)[:：]\s*(.*)$').firstMatch(line);
      if (pair == null) {
        addUnrecognized(line);
      } else if (pair.group(1) == '名称') {
        activeEntry.name = NpcMarkdownCodec._decodeScalar(
          pair.group(2)!.trim(),
        );
      } else {
        activeEntry.description = NpcMarkdownCodec._decodeScalar(
          pair.group(2)!.trim(),
        );
      }
    }
    flush();
  }

  void parseArbitraryBody(List<String> lines, int start) {
    final consumed = <int>{};
    _parseTables(lines, start, consumed);
    String? section;
    NpcFeatureEntry? current;
    final description = <String>[];

    void flushEntry() {
      final activeSection = section;
      final activeEntry = current;
      if (activeSection != null && activeEntry != null) {
        activeEntry.description = description.join('\n').trim();
        _entriesFor(activeSection).add(activeEntry);
      }
      current = null;
      description.clear();
    }

    for (var index = start; index < lines.length; index++) {
      if (consumed.contains(index)) continue;
      final raw = lines[index];
      final line = raw.trim();
      if (line.isEmpty || line == '---') continue;
      final heading = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
      if (heading != null) {
        final title = heading.group(2)!.replaceAll('*', '').trim();
        final mapped = _sectionAliases[title];
        if (mapped != null) {
          flushEntry();
          section = mapped;
          _record(mapped);
        } else if (section != null && heading.group(1)!.length >= 2) {
          flushEntry();
          current = NpcFeatureEntry(name: _plainText(title));
        } else if (card.name.trim().isEmpty) {
          card.name = _plainText(title);
          _record('名称');
        } else {
          addUnrecognized(raw);
        }
        continue;
      }
      if (section != null && current != null) {
        description.add(raw);
        continue;
      }
      final cleaned = line.replaceFirst(RegExp(r'^[-*+]\s+'), '');
      final pair = RegExp(r'^([^:：]{1,24})[:：]\s*(.*)$').firstMatch(cleaned);
      if (pair != null &&
          applyField(pair.group(1)!, _plainText(pair.group(2)!))) {
        continue;
      }
      final common = RegExp(
        r'^(护甲等级|护甲|AC|最大生命值|生命值|HP|速度|挑战等级|CR|力量|敏捷|体质|智力|感知|魅力)\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(_plainText(cleaned));
      if (common != null && applyField(common.group(1)!, common.group(2)!)) {
        continue;
      }
      addUnrecognized(raw);
    }
    flushEntry();
  }

  void _parseTables(List<String> lines, int start, Set<int> consumed) {
    var index = start;
    while (index < lines.length) {
      if (!lines[index].trim().startsWith('|')) {
        index++;
        continue;
      }
      final begin = index;
      final rows = <List<String>>[];
      while (index < lines.length && lines[index].trim().startsWith('|')) {
        rows.add(_tableCells(lines[index]));
        consumed.add(index);
        index++;
      }
      final useful = rows
          .where(
            (row) =>
                !row.every((cell) => RegExp(r'^:?-{2,}:?$').hasMatch(cell)),
          )
          .toList();
      if (useful.length >= 2) {
        final headers = useful.first;
        final values = useful[1];
        var matched = false;
        for (
          var cell = 0;
          cell < headers.length && cell < values.length;
          cell++
        ) {
          matched = applyField(headers[cell], values[cell]) || matched;
        }
        if (!matched) {
          for (final row in useful) {
            if (row.length >= 2 && applyField(row[0], row[1])) matched = true;
          }
        }
        if (!matched) {
          for (var line = begin; line < index; line++) {
            addUnrecognized(lines[line]);
          }
        }
      } else {
        for (var line = begin; line < index; line++) {
          addUnrecognized(lines[line]);
        }
      }
    }
  }

  void validateRecordedModifiers(List<String> warnings) {
    card.abilities.synchronizeModifiers();
    final calculated = <String, int>{
      '力量调整值': card.abilities.strengthModifier,
      '敏捷调整值': card.abilities.dexterityModifier,
      '体质调整值': card.abilities.constitutionModifier,
      '智力调整值': card.abilities.intelligenceModifier,
      '感知调整值': card.abilities.wisdomModifier,
      '魅力调整值': card.abilities.charismaModifier,
    };
    for (final entry in _recordedModifiers.entries) {
      if (calculated[entry.key] != entry.value) {
        warnings.add('${entry.key}与属性值不一致，已按属性值重新计算。');
      }
    }
  }

  NpcCard finishCard() {
    card.categoryId = defaultNpcCategoryId;
    card.abilities.synchronizeModifiers();
    return card;
  }

  bool get hasMeaningfulContent =>
      card.sizeAndType.trim().isNotEmpty ||
      card.maximumHitPoints > 0 ||
      card.armorClass != 10 ||
      card.speed.trim().isNotEmpty ||
      card.challengeRating.trim().isNotEmpty ||
      card.saves.trim().isNotEmpty ||
      card.skills.trim().isNotEmpty ||
      card.damageVulnerabilities.trim().isNotEmpty ||
      card.damageResistances.trim().isNotEmpty ||
      card.damageImmunities.trim().isNotEmpty ||
      card.conditionImmunities.trim().isNotEmpty ||
      card.senses.trim().isNotEmpty ||
      card.languages.trim().isNotEmpty ||
      card.notes.trim().isNotEmpty ||
      card.traits.isNotEmpty ||
      card.actions.isNotEmpty ||
      card.bonusActions.isNotEmpty ||
      card.reactions.isNotEmpty ||
      card.legendaryActions.isNotEmpty ||
      card.abilities.strength != 10 ||
      card.abilities.dexterity != 10 ||
      card.abilities.constitution != 10 ||
      card.abilities.intelligence != 10 ||
      card.abilities.wisdom != 10 ||
      card.abilities.charisma != 10;

  void addUnrecognized(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || unrecognized.contains(normalized)) return;
    if (unrecognized.length < 100) {
      unrecognized.add(
        normalized.length > 240
            ? '${normalized.substring(0, 240)}…'
            : normalized,
      );
    }
  }

  List<NpcFeatureEntry> _entriesFor(String section) => switch (section) {
    '特性' => card.traits,
    '动作' => card.actions,
    '附赠动作' => card.bonusActions,
    '反应' => card.reactions,
    '传奇动作' => card.legendaryActions,
    _ => card.traits,
  };

  void _record(String field) {
    if (!recognizedFields.contains(field)) recognizedFields.add(field);
  }

  static int _readInt(String value, [int fallback = 0]) {
    final match = RegExp(r'[+-]?\d+').firstMatch(value);
    return int.tryParse(match?.group(0) ?? '') ?? fallback;
  }

  static String _plainText(String value) => value
      .replaceAll(RegExp(r'\*\*|__|`'), '')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .trim();

  static List<String> _tableCells(String line) {
    final trimmed = line.trim();
    final content = trimmed.startsWith('|') ? trimmed.substring(1) : trimmed;
    final withoutEnd = content.endsWith('|')
        ? content.substring(0, content.length - 1)
        : content;
    return withoutEnd.split('|').map((cell) => _plainText(cell)).toList();
  }
}
