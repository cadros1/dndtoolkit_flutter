import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dndtoolkit_flutter/services/adventure_selection_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('保存并读取最近选择的冒险角色', () async {
    final service = AdventureSelectionService.instance;

    await service.saveSelectedCharacterId('character-b');

    expect(await service.getSelectedCharacterId(), 'character-b');
  });

  test('清除最近选择后返回空值', () async {
    final service = AdventureSelectionService.instance;
    await service.saveSelectedCharacterId('character-b');

    await service.clearSelectedCharacterId();

    expect(await service.getSelectedCharacterId(), isNull);
  });

  test('忽略空白角色 ID', () async {
    final service = AdventureSelectionService.instance;

    await service.saveSelectedCharacterId('   ');

    expect(await service.getSelectedCharacterId(), isNull);
  });
}
