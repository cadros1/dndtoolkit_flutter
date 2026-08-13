import 'dart:io';

import 'package:dndtoolkit_flutter/models/character.dart';
import 'package:dndtoolkit_flutter/services/pdf_data_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  final templateFile = File('assets/Character.pdf');

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
}
