import 'package:dndtoolkit_flutter/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings opens named AI service configuration page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    expect(find.text('AI 服务配置'), findsOneWidget);
    await tester.tap(find.text('AI 服务配置'));
    await tester.pumpAndSettle();

    expect(find.text('还没有 AI 服务配置'), findsOneWidget);
    expect(find.text('新建 AI 服务配置'), findsOneWidget);
  });
}
