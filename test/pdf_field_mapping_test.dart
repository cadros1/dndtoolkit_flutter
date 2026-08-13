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
}

PdfTextBoxField _findTextField(PdfForm form, String name) {
  for (int i = 0; i < form.fields.count; i++) {
    final field = form.fields[i];
    if (field.name?.trim() == name && field is PdfTextBoxField) return field;
  }
  throw StateError('PDF text field not found: $name');
}
