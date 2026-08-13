import 'dart:io';

import 'package:dndtoolkit_flutter/models/character.dart';
import 'package:dndtoolkit_flutter/services/pdf_data_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  final templateFile = File('assets/Character.pdf');
  final fontFile = File('assets/fonts/simsun.ttc');

  test('Feat+Traits 双向映射 additionalFeaturesAndTraits', () async {
    final source = PdfDocument(inputBytes: templateFile.readAsBytesSync());
    final sourceRoleplay = Roleplay(
      additionalFeaturesAndTraits: 'canonical additional features',
    );

    PdfDataService.writeAdditionalFeaturesAndTraitsToForm(
      source.form,
      sourceRoleplay,
    );
    final outputBytes = await source.save();
    source.dispose();

    final reopened = PdfDocument(inputBytes: outputBytes);
    final importedRoleplay = Roleplay();
    PdfDataService.readAdditionalFeaturesAndTraitsFromForm(
      reopened.form,
      importedRoleplay,
    );
    reopened.dispose();

    expect(
      importedRoleplay.additionalFeaturesAndTraits,
      'canonical additional features',
    );
  });

  test('导出按字段内容缩小字号并允许继续滚动编辑', () {
    final character = Character();
    character.profile.classAndLevel = '3级游侠（幽域追踪者）兼任2级战士';
    character.profile.race = '人类（标准人类）';
    character.roleplay.personalityTraits =
        '沉着冷静，习惯先观察地形和敌情再行动；面对突发状况时会用简短口令组织同伴。'
        '即使在漫长旅途中，也会持续记录线索并反复核对每一个细节。';

    final outputBytes = PdfDataService.buildCharacterPdfBytes(
      character,
      templateFile.readAsBytesSync(),
      fontFile.readAsBytesSync(),
    );

    final reopened = PdfDocument(inputBytes: outputBytes);
    try {
      final classLevel = _findTextField(reopened.form, 'ClassLevel');
      final personality = _findTextField(reopened.form, 'PersonalityTraits');

      expect(classLevel.text, character.profile.classAndLevel);
      expect(classLevel.font.size, lessThan(12));
      expect(classLevel.scrollable, isTrue);

      expect(personality.text, character.roleplay.personalityTraits);
      expect(personality.font.size, lessThanOrEqualTo(8));
      expect(personality.font.size, greaterThanOrEqualTo(4));
      expect(personality.scrollable, isTrue);
    } finally {
      reopened.dispose();
    }
  });

  test('移动端 PDF 分享文件名包含可读且唯一的导出时间', () {
    final firstName = PdfDataService.buildMobileShareFileName(
      '阿斯特里德',
      DateTime(2026, 8, 13, 14, 5, 9, 23, 7),
    );
    final secondName = PdfDataService.buildMobileShareFileName(
      '阿斯特里德',
      DateTime(2026, 8, 13, 14, 5, 9, 23, 8),
    );

    expect(firstName, '阿斯特里德_20260813_140509_023007.pdf');
    expect(secondName, '阿斯特里德_20260813_140509_023008.pdf');
    expect(secondName, isNot(firstName));
  });

  test('移动端 PDF 分享明确 MIME 并在分享后清理源临时文件', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'dndtoolkit_pdf_share_test_',
    );
    String? sharedPath;
    try {
      await PdfDataService.shareMobilePdfBytes(
        const <int>[1, 2, 3, 4],
        tempDirectory,
        '阿斯特里德',
        exportedAt: DateTime(2026, 8, 13, 14, 5, 9, 23, 7),
        shareFile: (file, text) async {
          sharedPath = file.path;
          expect(file.mimeType, 'application/pdf');
          expect(text, '分享角色卡: 阿斯特里德_20260813_140509_023007.pdf');
          expect(await File(file.path).readAsBytes(), const <int>[1, 2, 3, 4]);
        },
      );

      expect(sharedPath, isNotNull);
      expect(await File(sharedPath!).exists(), isFalse);
    } finally {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('移动端 PDF 分享失败时仍清理源临时文件', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'dndtoolkit_pdf_share_failure_test_',
    );
    String? sharedPath;
    try {
      await expectLater(
        PdfDataService.shareMobilePdfBytes(
          const <int>[1, 2, 3, 4],
          tempDirectory,
          '阿斯特里德',
          exportedAt: DateTime(2026, 8, 13, 14, 5, 9, 23, 7),
          shareFile: (file, _) async {
            sharedPath = file.path;
            throw StateError('模拟分享失败');
          },
        ),
        throwsStateError,
      );

      expect(sharedPath, isNotNull);
      expect(await File(sharedPath!).exists(), isFalse);
    } finally {
      await tempDirectory.delete(recursive: true);
    }
  });
}

PdfTextBoxField _findTextField(PdfForm form, String name) {
  for (int i = 0; i < form.fields.count; i++) {
    final field = form.fields[i];
    if (field.name?.trim() == name && field is PdfTextBoxField) return field;
  }
  throw StateError('PDF text field not found: $name');
}
