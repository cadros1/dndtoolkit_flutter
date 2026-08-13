import 'dart:convert';

import 'package:dndtoolkit_flutter/models/ai_service_config.dart';
import 'package:dndtoolkit_flutter/pages/ai_service_configs_page.dart';
import 'package:dndtoolkit_flutter/services/ai_character_service.dart';
import 'package:dndtoolkit_flutter/services/ai_config_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android API Key uses normal visible text input and models load',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = AiCharacterService(
        clientFactory: () => MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.toString(), 'https://api.deepseek.com/models');
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'deepseek-model-a'},
                {'id': 'deepseek-model-b'},
              ],
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: AiServiceConfigEditPage(
            repository: AiConfigRepository(secretStore: _MemorySecretStore()),
            service: service,
          ),
        ),
      );

      final apiKeyField = find.widgetWithText(TextFormField, 'API Key *');
      await tester.dragUntilVisible(
        apiKeyField,
        find.byType(ListView),
        const Offset(0, -400),
      );
      final editable = tester.widget<EditableText>(
        find.descendant(of: apiKeyField, matching: find.byType(EditableText)),
      );
      expect(editable.obscureText, isFalse);
      expect(editable.keyboardType, TextInputType.text);
      expect(editable.enableSuggestions, isTrue);
      expect(editable.enableIMEPersonalizedLearning, isFalse);
      expect(find.text('例如：DeepSeek 日常建卡'), findsNothing);

      await tester.enterText(apiKeyField, 'test-key');
      await tester.tap(find.text('获取模型列表'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('模型列表'), findsOneWidget);
      expect(find.text('deepseek-model-a'), findsWidgets);
      await tester.tap(find.text('deepseek-model-a').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('deepseek-model-b').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认选择'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final modelField = find.widgetWithText(TextFormField, '模型名 *');
      final modelEditable = tester.widget<EditableText>(
        find.descendant(of: modelField, matching: find.byType(EditableText)),
      );
      expect(modelEditable.controller.text, 'deepseek-model-b');
      expect(find.text('模型列表'), findsNothing);
    },
  );

  testWidgets(
    'provider and model changes expose only official thinking controls',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: AiServiceConfigEditPage(
            repository: AiConfigRepository(secretStore: _MemorySecretStore()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('支持 low、high、max 三档强度'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<AiProviderKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kimi').last);
      await tester.pumpAndSettle();

      final baseUrlField = find.widgetWithText(TextFormField, 'Base URL *');
      final baseUrlEditable = tester.widget<EditableText>(
        find.descendant(of: baseUrlField, matching: find.byType(EditableText)),
      );
      expect(baseUrlEditable.controller.text, AiServiceConfig.kimiBaseUrl);

      final modelField = find.widgetWithText(TextFormField, '模型名 *');
      var modelEditable = tester.widget<EditableText>(
        find.descendant(of: modelField, matching: find.byType(EditableText)),
      );
      expect(modelEditable.controller.text, 'kimi-k3');
      expect(find.text('该模型始终启用思考模式'), findsOneWidget);
      expect(find.text('思考强度'), findsOneWidget);
      final kimiSwitch = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, '启用思考模式'),
      );
      expect(kimiSwitch.value, isTrue);
      expect(kimiSwitch.onChanged, isNull);

      await tester.enterText(modelField, 'kimi-k2.6');
      await tester.pumpAndSettle();
      expect(find.text('官方接口仅支持开启或关闭，不提供强度档位'), findsOneWidget);
      expect(find.text('思考强度'), findsNothing);
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, '启用思考模式'),
            )
            .onChanged,
        isNotNull,
      );

      await tester.tap(find.byType(DropdownButtonFormField<AiProviderKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MiMo').last);
      await tester.pumpAndSettle();
      modelEditable = tester.widget<EditableText>(
        find.descendant(of: modelField, matching: find.byType(EditableText)),
      );
      expect(modelEditable.controller.text, 'mimo-v2.5-pro');
      expect(find.text('官方接口仅支持开启或关闭，不提供强度档位'), findsOneWidget);
      expect(find.text('思考强度'), findsNothing);
    },
  );
}

class _MemorySecretStore implements AiSecretStore {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
