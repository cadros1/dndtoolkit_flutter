import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dndtoolkit_flutter/pages/identity_token_page.dart';
import 'package:dndtoolkit_flutter/pages/settings_page.dart';

const _oldToken = '11111111-1111-4111-8111-111111111111';
const _newToken = '22222222-2222-4222-8222-222222222222';

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('设置页只展示身份令牌入口，说明位于二级页面', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpPage(tester, const SettingsPage());

    expect(find.text('查看、复制或更换令牌'), findsOneWidget);
    expect(find.text('令牌有什么用'), findsNothing);

    await tester.tap(find.text('身份令牌').last);
    await tester.pumpAndSettle();

    expect(find.byType(IdentityTokenPage), findsOneWidget);
    expect(find.text('令牌有什么用'), findsOneWidget);
    expect(find.text('请妥善保管'), findsOneWidget);
  });

  testWidgets('无令牌时可以生成并要求确认已保存', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpPage(tester, const IdentityTokenPage());

    expect(find.text('这台设备还没有身份令牌。'), findsOneWidget);
    expect(find.byKey(const Key('generate-token')), findsOneWidget);
    expect(find.byKey(const Key('use-existing-token')), findsOneWidget);

    await tester.tap(find.byKey(const Key('generate-token')));
    await tester.pumpAndSettle();

    expect(find.text('新令牌已生成'), findsOneWidget);
    final closeButton = tester.widget<FilledButton>(
      find.byKey(const Key('close-new-token-dialog')),
    );
    expect(closeButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('confirm-new-token-saved')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('close-new-token-dialog')));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString('cloud_sync_token');
    expect(token, isNotNull);
    expect(token, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(find.text('这台设备还没有身份令牌。'), findsNothing);
  });

  testWidgets('相同令牌和格式错误会在输入框下方提示', (tester) async {
    SharedPreferences.setMockInitialValues({'cloud_sync_token': _oldToken});
    await _pumpPage(tester, const IdentityTokenPage());

    await tester.tap(find.byKey(const Key('use-existing-token')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('existing-token-field')),
      'not-a-token',
    );
    await tester.tap(find.text('继续'));
    await tester.pump();
    expect(find.text('这个令牌格式不对，请检查是否复制完整。'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('existing-token-field')),
      _oldToken,
    );
    await tester.tap(find.text('继续'));
    await tester.pump();
    expect(find.text('这就是当前正在使用的令牌。'), findsOneWidget);
  });

  testWidgets('更换令牌前必须确认已保存当前令牌', (tester) async {
    SharedPreferences.setMockInitialValues({'cloud_sync_token': _oldToken});
    await _pumpPage(tester, const IdentityTokenPage());

    await tester.tap(find.byKey(const Key('use-existing-token')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('existing-token-field')),
      _newToken,
    );
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();

    expect(find.text('更换身份令牌？'), findsOneWidget);
    var confirmButton = tester.widget<FilledButton>(
      find.byKey(const Key('confirm-token-replacement')),
    );
    expect(confirmButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('confirm-current-token-saved')));
    await tester.pump();
    confirmButton = tester.widget<FilledButton>(
      find.byKey(const Key('confirm-token-replacement')),
    );
    expect(confirmButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('confirm-token-replacement')));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('cloud_sync_token'), _newToken);
    expect(find.text(_newToken), findsOneWidget);
  });

  testWidgets('取消更换不会修改当前令牌', (tester) async {
    SharedPreferences.setMockInitialValues({'cloud_sync_token': _oldToken});
    await _pumpPage(tester, const IdentityTokenPage());

    await tester.tap(find.byKey(const Key('use-existing-token')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('existing-token-field')),
      _newToken,
    );
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('cloud_sync_token'), _oldToken);
    expect(find.text(_oldToken), findsOneWidget);
  });

  testWidgets('重新生成令牌沿用保存确认并展示新令牌', (tester) async {
    SharedPreferences.setMockInitialValues({'cloud_sync_token': _oldToken});
    await _pumpPage(tester, const IdentityTokenPage());

    await tester.tap(find.byKey(const Key('generate-token')));
    await tester.pumpAndSettle();
    expect(find.text('生成新的身份令牌？'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-current-token-saved')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-token-replacement')));
    await tester.pumpAndSettle();

    expect(find.text('新令牌已生成'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('cloud_sync_token'), isNot(_oldToken));

    await tester.tap(find.byKey(const Key('confirm-new-token-saved')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('close-new-token-dialog')));
    await tester.pumpAndSettle();
  });

  testWidgets('复制按钮复制当前已保存的完整令牌', (tester) async {
    SharedPreferences.setMockInitialValues({'cloud_sync_token': _oldToken});
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await _pumpPage(tester, const IdentityTokenPage());
    await tester.tap(find.byKey(const Key('copy-current-token')));
    await tester.pump();

    expect(copiedText, _oldToken);
  });

  testWidgets('小屏、横屏和桌面宽度下页面均可滚动且不溢出', (tester) async {
    SharedPreferences.setMockInitialValues({'cloud_sync_token': _oldToken});
    const sizes = [Size(360, 640), Size(844, 390), Size(1280, 720)];
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final size in sizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: ThemeMode.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: const IdentityTokenPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
