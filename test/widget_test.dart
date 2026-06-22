import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:dndtoolkit_flutter/main.dart';

void main() {
  testWidgets('app starts on character management', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DnDToolkitApp());

    expect(find.text('角色管理'), findsOneWidget);
    expect(find.text('角色'), findsOneWidget);
    expect(find.text('冒险'), findsOneWidget);
  });
}
