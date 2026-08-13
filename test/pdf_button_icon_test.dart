// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:dndtoolkit_flutter/models/character.dart';
import 'package:dndtoolkit_flutter/services/pdf_data_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_library;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/io/pdf_cross_table.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_array.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_dictionary.dart';
import 'package:syncfusion_flutter_pdf/src/pdf/interfaces/pdf_interface.dart';

void main() {
  final templateFile = File('assets/Character.pdf');

  test(
    'sets and extracts an Acrobat button icon using the bundled template',
    () {
      final imageBytes = _createRgbPngBytes();
      final updatedPdfBytes = PdfDataService.setButtonIconImageBytes(
        templateFile.readAsBytesSync(),
        imageBytes,
      );

      expect(updatedPdfBytes, isNotNull);
      final extractedBytes = PdfDataService.extractButtonIconImageBytes(
        updatedPdfBytes!,
      );
      expect(extractedBytes, isNotNull);

      final image = PdfBitmap(extractedBytes!);
      expect(image.width, 3);
      expect(image.height, 2);
    },
  );

  test('sets and extracts a grayscale image with an alpha mask', () {
    final imageBytes = _createGrayAlphaPngBytes();
    final updatedPdfBytes = PdfDataService.setButtonIconImageBytes(
      templateFile.readAsBytesSync(),
      imageBytes,
    );

    expect(updatedPdfBytes, isNotNull);
    final extractedBytes = PdfDataService.extractButtonIconImageBytes(
      updatedPdfBytes!,
    );
    expect(extractedBytes, isNotNull);

    final image = PdfBitmap(extractedBytes!);
    expect(image.width, 2);
    expect(image.height, 2);
  });

  test('sets and extracts a JPEG button icon', () {
    final imageBytes = image_library.encodeJpg(
      image_library.Image(width: 4, height: 3),
    );
    final updatedPdfBytes = PdfDataService.setButtonIconImageBytes(
      templateFile.readAsBytesSync(),
      imageBytes,
    );

    expect(updatedPdfBytes, isNotNull);
    final extractedBytes = PdfDataService.extractButtonIconImageBytes(
      updatedPdfBytes!,
    );
    expect(extractedBytes, isNotNull);
    expect(extractedBytes!.take(3), <int>[0xff, 0xd8, 0xff]);

    final image = PdfBitmap(extractedBytes);
    expect(image.width, 4);
    expect(image.height, 3);
  });

  test('imports and exports the portrait through the formal PDF bridge', () {
    final templateBytes = templateFile.readAsBytesSync();
    final imageBytes = _createRgbPngBytes(width: 5, height: 4);
    final sourcePdfBytes = PdfDataService.setButtonIconImageBytes(
      templateBytes,
      imageBytes,
    );
    expect(sourcePdfBytes, isNotNull);

    final character = Character();
    expect(
      PdfDataService.importPortraitFromPdfBytes(character, sourcePdfBytes!),
      isTrue,
    );
    expect(character.profile.portraitBase64, isNotEmpty);

    final importedImage = PdfBitmap(
      base64Decode(character.profile.portraitBase64),
    );
    expect(importedImage.width, 5);
    expect(importedImage.height, 4);

    final exportedPdfBytes = PdfDataService.exportPortraitToPdfBytes(
      character,
      templateBytes,
    );
    final exportedImageBytes = PdfDataService.extractButtonIconImageBytes(
      exportedPdfBytes,
    );
    expect(exportedImageBytes, isNotNull);

    final exportedImage = PdfBitmap(exportedImageBytes!);
    expect(exportedImage.width, 5);
    expect(exportedImage.height, 4);
  });

  test('portrait export preserves text, button type, and button action', () {
    final sourcePdfBytes = _setTextField(
      templateFile.readAsBytesSync(),
      'CharacterName',
      'Portrait Test',
    );
    expect(_hasButtonAction(sourcePdfBytes), isTrue);

    final character = Character();
    character.profile.portraitBase64 = base64Encode(_createRgbPngBytes());
    final exportedPdfBytes = PdfDataService.exportPortraitToPdfBytes(
      character,
      sourcePdfBytes,
    );

    expect(_readTextField(exportedPdfBytes, 'CharacterName'), 'Portrait Test');
    expect(_isButtonField(exportedPdfBytes), isTrue);
    expect(_hasButtonAction(exportedPdfBytes), isTrue);
  });

  test('invalid or oversized portrait data does not block PDF export', () {
    final templateBytes = templateFile.readAsBytesSync();
    final character = Character();

    character.profile.portraitBase64 = 'not-valid-base64';
    expect(
      identical(
        PdfDataService.exportPortraitToPdfBytes(character, templateBytes),
        templateBytes,
      ),
      isTrue,
    );

    character.profile.portraitBase64 = base64Encode(
      _createRgbPngBytes(width: 8193, height: 1),
    );
    expect(
      identical(
        PdfDataService.exportPortraitToPdfBytes(character, templateBytes),
        templateBytes,
      ),
      isTrue,
    );
  });
}

PdfField? _findField(PdfForm form, String name) {
  for (int i = 0; i < form.fields.count; i++) {
    final field = form.fields[i];
    if (field.name?.trim() == name) return field;
  }
  return null;
}

List<int> _setTextField(List<int> pdfBytes, String name, String value) {
  final document = PdfDocument(inputBytes: pdfBytes);
  try {
    final field = _findField(document.form, name);
    expect(field, isA<PdfTextBoxField>());
    (field! as PdfTextBoxField).text = value;
    return document.saveSync();
  } finally {
    document.dispose();
  }
}

String? _readTextField(List<int> pdfBytes, String name) {
  final document = PdfDocument(inputBytes: pdfBytes);
  try {
    final field = _findField(document.form, name);
    return field is PdfTextBoxField ? field.text : null;
  } finally {
    document.dispose();
  }
}

bool _isButtonField(List<int> pdfBytes) {
  final document = PdfDocument(inputBytes: pdfBytes);
  try {
    return _findField(document.form, PdfDataService.characterImageFieldName)
        is PdfButtonField;
  } finally {
    document.dispose();
  }
}

bool _hasButtonAction(List<int> pdfBytes) {
  final document = PdfDocument(inputBytes: pdfBytes);
  try {
    final field = _findField(
      document.form,
      PdfDataService.characterImageFieldName,
    );
    if (field is! PdfButtonField) return false;

    final object = PdfCrossTable.dereference(IPdfWrapper.getElement(field));
    return object is PdfDictionary && _dictionaryHasAction(object);
  } finally {
    document.dispose();
  }
}

bool _dictionaryHasAction(PdfDictionary dictionary) {
  if (dictionary['AA'] != null || dictionary['A'] != null) return true;

  final kids = PdfCrossTable.dereference(dictionary['Kids']);
  if (kids is! PdfArray) return false;
  for (final kid in kids.elements) {
    final child = PdfCrossTable.dereference(kid);
    if (child is PdfDictionary && _dictionaryHasAction(child)) return true;
  }
  return false;
}

List<int> _createRgbPngBytes({int width = 3, int height = 2}) {
  final rows = <int>[];
  for (int y = 0; y < height; y++) {
    rows.add(0);
    for (int x = 0; x < width; x++) {
      rows.addAll(<int>[
        (x * 31 + y * 17) & 0xff,
        (x * 13 + y * 47) & 0xff,
        (x * 59 + y * 7) & 0xff,
      ]);
    }
  }

  return _createPngBytes(
    width: width,
    height: height,
    bitDepth: 8,
    colorType: 2,
    rawRows: rows,
  );
}

List<int> _createGrayAlphaPngBytes() {
  const rows = <int>[0, 0x00, 0xff, 0x80, 0x80, 0, 0xff, 0x40, 0x30, 0x00];

  return _createPngBytes(
    width: 2,
    height: 2,
    bitDepth: 8,
    colorType: 4,
    rawRows: rows,
  );
}

List<int> _createPngBytes({
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

void _addPngChunk(List<int> output, String type, List<int> data) {
  final typeBytes = type.codeUnits;
  output.addAll(_uint32Bytes(data.length));
  output.addAll(typeBytes);
  output.addAll(data);
  output.addAll(_uint32Bytes(_crc32(<int>[...typeBytes, ...data])));
}

List<int> _uint32Bytes(int value) {
  return <int>[
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];
}

int _crc32(List<int> data) {
  int crc = 0xffffffff;
  for (final byte in data) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
      crc = (crc & 1) == 1 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
