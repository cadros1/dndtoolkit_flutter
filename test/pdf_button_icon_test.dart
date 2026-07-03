import 'dart:io';

import 'package:dndtoolkit_flutter/services/pdf_data_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  const testPdfPath = r'C:\Users\16272\Downloads\test.pdf';
  const replacementImagePath = r'C:\Users\16272\OneDrive\图片\环世界小人\美狐-咲花\1.png';
  const jpgReplacementImagePath =
      r'C:\Users\16272\Documents\Tencent Files\1627255598\FileRecv\MobileFile\1659864511014headpic.jpg';
  final testPdfFile = File(testPdfPath);
  final replacementImageFile = File(replacementImagePath);
  final jpgReplacementImageFile = File(jpgReplacementImagePath);

  test(
    'extracts the Acrobat button icon image from Character Image',
    () {
      final imageBytes = PdfDataService.extractButtonIconImageBytes(
        testPdfFile.readAsBytesSync(),
      );

      expect(imageBytes, isNotNull);
      expect(imageBytes!.length, greaterThan(1000));
      expect(imageBytes[0], 0xff);
      expect(imageBytes[1], 0xd8);
      expect(imageBytes[2], 0xff);

      final image = PdfBitmap(imageBytes);
      expect(image.width, 1170);
      expect(image.height, 1170);
    },
    skip: testPdfFile.existsSync()
        ? false
        : 'Missing local test PDF: $testPdfPath',
  );

  test(
    'sets the Acrobat button icon image and reads it back',
    () {
      final pdfBytes = testPdfFile.readAsBytesSync();
      final originalImageBytes = PdfDataService.extractButtonIconImageBytes(
        pdfBytes,
      );

      expect(originalImageBytes, isNotNull);

      final updatedPdfBytes = PdfDataService.setButtonIconImageBytes(
        pdfBytes,
        originalImageBytes!,
      );
      expect(updatedPdfBytes, isNotNull);

      final roundTripImageBytes = PdfDataService.extractButtonIconImageBytes(
        updatedPdfBytes!,
      );
      expect(roundTripImageBytes, isNotNull);

      final image = PdfBitmap(roundTripImageBytes!);
      expect(image.width, 1170);
      expect(image.height, 1170);
    },
    skip: testPdfFile.existsSync()
        ? false
        : 'Missing local test PDF: $testPdfPath',
  );

  test(
    'sets a PNG file as the Acrobat button icon image and reads it back',
    () {
      final pdfBytes = testPdfFile.readAsBytesSync();
      final replacementImageBytes = replacementImageFile.readAsBytesSync();
      final replacementImage = PdfBitmap(replacementImageBytes);

      final updatedPdfBytes = PdfDataService.setButtonIconImageBytes(
        pdfBytes,
        replacementImageBytes,
      );
      expect(updatedPdfBytes, isNotNull);

      final roundTripImageBytes = PdfDataService.extractButtonIconImageBytes(
        updatedPdfBytes!,
      );
      expect(roundTripImageBytes, isNotNull);

      final roundTripImage = PdfBitmap(roundTripImageBytes!);
      expect(roundTripImage.width, replacementImage.width);
      expect(roundTripImage.height, replacementImage.height);
    },
    skip: !testPdfFile.existsSync()
        ? 'Missing local test PDF: $testPdfPath'
        : !replacementImageFile.existsSync()
        ? 'Missing local replacement image: $replacementImagePath'
        : false,
  );

  test(
    'sets a JPG file as the Acrobat button icon image and reads it back',
    () {
      _setImageAndVerifyReadBack(testPdfFile, jpgReplacementImageFile);
    },
    skip: !testPdfFile.existsSync()
        ? 'Missing local test PDF: $testPdfPath'
        : !jpgReplacementImageFile.existsSync()
        ? 'Missing local replacement image: $jpgReplacementImagePath'
        : false,
  );

  test(
    'sets a grayscale PNG with alpha as the Acrobat button icon image and reads it back',
    () {
      final imageBytes = _createGrayAlphaPngBytes();
      final replacementImage = PdfBitmap(imageBytes);

      _setImageBytesAndVerifyReadBack(
        testPdfFile: testPdfFile,
        imageBytes: imageBytes,
        replacementImage: replacementImage,
      );
    },
    skip: testPdfFile.existsSync()
        ? false
        : 'Missing local test PDF: $testPdfPath',
  );

  test(
    'writes PNG and JPG Acrobat button icon PDF outputs',
    () {
      final outputDirectory = Directory('output/pdf')
        ..createSync(recursive: true);

      _setImageVerifyAndSavePdf(
        testPdfFile: testPdfFile,
        imageFile: replacementImageFile,
        outputPdfFile: File(
          '${outputDirectory.path}/character_image_png_button_icon.pdf',
        ),
      );
      _setImageVerifyAndSavePdf(
        testPdfFile: testPdfFile,
        imageFile: jpgReplacementImageFile,
        outputPdfFile: File(
          '${outputDirectory.path}/character_image_jpg_button_icon.pdf',
        ),
      );
    },
    skip: !testPdfFile.existsSync()
        ? 'Missing local test PDF: $testPdfPath'
        : !replacementImageFile.existsSync()
        ? 'Missing local replacement image: $replacementImagePath'
        : !jpgReplacementImageFile.existsSync()
        ? 'Missing local replacement image: $jpgReplacementImagePath'
        : false,
  );
}

void _setImageAndVerifyReadBack(File testPdfFile, File imageFile) {
  final imageBytes = imageFile.readAsBytesSync();
  final replacementImage = PdfBitmap(imageBytes);

  _setImageBytesAndVerifyReadBack(
    testPdfFile: testPdfFile,
    imageBytes: imageBytes,
    replacementImage: replacementImage,
  );
}

void _setImageBytesAndVerifyReadBack({
  required File testPdfFile,
  required List<int> imageBytes,
  required PdfBitmap replacementImage,
}) {
  final pdfBytes = testPdfFile.readAsBytesSync();
  final updatedPdfBytes = PdfDataService.setButtonIconImageBytes(
    pdfBytes,
    imageBytes,
  );
  expect(updatedPdfBytes, isNotNull);

  final roundTripImageBytes = PdfDataService.extractButtonIconImageBytes(
    updatedPdfBytes!,
  );
  expect(roundTripImageBytes, isNotNull);

  final roundTripImage = PdfBitmap(roundTripImageBytes!);
  expect(roundTripImage.width, replacementImage.width);
  expect(roundTripImage.height, replacementImage.height);
}

List<int> _createGrayAlphaPngBytes() {
  const width = 2;
  const height = 2;
  final rows = <int>[0, 0x00, 0xff, 0x80, 0x80, 0, 0xff, 0x40, 0x30, 0x00];

  return _createPngBytes(
    width: width,
    height: height,
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
      if ((crc & 1) == 1) {
        crc = 0xedb88320 ^ (crc >> 1);
      } else {
        crc >>= 1;
      }
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

void _setImageVerifyAndSavePdf({
  required File testPdfFile,
  required File imageFile,
  required File outputPdfFile,
}) {
  final pdfBytes = testPdfFile.readAsBytesSync();
  final imageBytes = imageFile.readAsBytesSync();
  final replacementImage = PdfBitmap(imageBytes);

  final updatedPdfBytes = PdfDataService.setButtonIconImageBytes(
    pdfBytes,
    imageBytes,
  );
  expect(updatedPdfBytes, isNotNull);

  outputPdfFile.writeAsBytesSync(updatedPdfBytes!, flush: true);

  final roundTripImageBytes = PdfDataService.extractButtonIconImageBytes(
    outputPdfFile.readAsBytesSync(),
  );
  expect(roundTripImageBytes, isNotNull);

  final roundTripImage = PdfBitmap(roundTripImageBytes!);
  expect(roundTripImage.width, replacementImage.width);
  expect(roundTripImage.height, replacementImage.height);
}
