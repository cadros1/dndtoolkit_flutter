import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dndtoolkit_flutter/main.dart';

void main() {
  testWidgets('应用启动后显示角色页和移动端导航', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DnDToolkitApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('角色'), findsOneWidget);
    expect(find.text('冒险'), findsOneWidget);
    expect(find.text('DM'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 0);
  });
}
