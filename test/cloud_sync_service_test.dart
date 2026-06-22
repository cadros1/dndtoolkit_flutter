import 'dart:convert';

import 'package:dndtoolkit_flutter/services/cloud_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CloudCharacterSummary.fromRow', () {
    test('parses character data from a map', () {
      final summary = CloudCharacterSummary.fromRow({
        'id': 'char-1',
        'data': {
          'Profile': {
            'CharacterName': '小卡',
            'Race': '人类',
            'ClassAndLevel': '战士 1',
          },
        },
        'updated_at': '2026-06-22T10:00:00Z',
      });

      expect(summary.id, 'char-1');
      expect(summary.name, '小卡');
      expect(summary.details, '人类 | 战士 1');
      expect(summary.updatedAt, DateTime.parse('2026-06-22T10:00:00Z'));
    });

    test('parses character data from a JSON string', () {
      final summary = CloudCharacterSummary.fromRow({
        'id': 'char-2',
        'data': jsonEncode({
          'Profile': {
            'CharacterName': '法师',
            'Race': '精灵',
            'ClassAndLevel': '法师 3',
          },
        }),
      });

      expect(summary.id, 'char-2');
      expect(summary.name, '法师');
      expect(summary.details, '精灵 | 法师 3');
    });

    test('rejects invalid JSON string data', () {
      expect(
        () => CloudCharacterSummary.fromRow({
          'id': 'char-3',
          'data': '{not-json',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects missing character data', () {
      expect(
        () => CloudCharacterSummary.fromRow({'id': 'char-4'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
