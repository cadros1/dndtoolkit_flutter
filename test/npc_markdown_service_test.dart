import 'dart:io';

import 'package:dndtoolkit_flutter/models/dm_models.dart';
import 'package:dndtoolkit_flutter/services/npc_markdown_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NpcMarkdownCodec', () {
    test('round trips a complete Chinese NPC card without runtime data', () {
      final source = NpcCard(
        name: '哥布林斥候',
        categoryId: 'source-category-id',
        sizeAndType: '小型类人生物（地精）',
        maximumHitPoints: 11,
        armorClass: 15,
        speed: '30 尺',
        abilities: NpcAbilityScores(
          strength: 8,
          dexterity: 16,
          constitution: 12,
          intelligence: 10,
          wisdom: 14,
          charisma: 8,
        ),
        saves: '敏捷 +5',
        skills: '隐匿 +7，察觉 +4',
        damageVulnerabilities: '光耀',
        damageResistances: '寒冷',
        damageImmunities: '毒素',
        conditionImmunities: '中毒',
        senses: '黑暗视觉 60 尺，被动察觉 14',
        languages: '通用语，地精语',
        challengeRating: '1/2',
        traits: [NpcFeatureEntry(name: '灵活逃脱', description: '可执行撤离或躲藏。')],
        actions: [
          NpcFeatureEntry(
            name: '短弓',
            description: '远程武器攻击：命中 +5。\n命中：6（1d6+3）穿刺伤害。',
          ),
        ],
        bonusActions: [NpcFeatureEntry(name: '疾走', description: '移动。')],
        reactions: [NpcFeatureEntry(name: '闪避', description: 'AC +2。')],
        legendaryActions: [
          NpcFeatureEntry(name: '快速射击', description: '进行一次短弓攻击。'),
        ],
        notes: '首领派出的侦察兵。\n不会战至最后一人。',
      );

      final markdown = NpcMarkdownCodec.exportCard(source, categoryName: '荒野');
      final parsed = NpcMarkdownCodec.parse('哥布林斥候.md', markdown);

      expect(parsed.status, NpcMarkdownImportStatus.verified);
      expect(parsed.categoryName, '荒野');
      expect(parsed.card, isNotNull);
      expect(parsed.card!.id, isNot(source.id));
      expect(parsed.card!.name, source.name);
      expect(parsed.card!.sizeAndType, source.sizeAndType);
      expect(parsed.card!.maximumHitPoints, source.maximumHitPoints);
      expect(parsed.card!.armorClass, source.armorClass);
      expect(parsed.card!.abilities.dexterityModifier, 3);
      expect(parsed.card!.traits.single.name, '灵活逃脱');
      expect(
        parsed.card!.actions.single.description,
        source.actions.single.description,
      );
      expect(parsed.card!.notes, source.notes);
      expect(markdown, contains('DnDToolkit-NPC: 1'));
      expect(markdown, contains(RegExp(r'SHA256: [0-9a-f]{64}')));
      expect(markdown, isNot(contains(source.id)));
      expect(markdown, isNot(contains('CurrentHitPoints')));
      expect(markdown, isNot(contains('Initiative')));
      expect(markdown, isNot(contains('Encounter')));
    });

    test('normalizes CRLF before validating SHA-256', () {
      final markdown = NpcMarkdownCodec.exportCard(
        NpcCard(name: '灰矮人', sizeAndType: '中型类人生物'),
        categoryName: defaultNpcCategoryName,
      );

      final parsed = NpcMarkdownCodec.parse(
        'crlf.md',
        markdown.replaceAll('\n', '\r\n'),
      );

      expect(parsed.status, NpcMarkdownImportStatus.verified);
      expect(parsed.card!.name, '灰矮人');
    });

    test(
      'keeps a checksum-mismatched file importable with an explicit warning',
      () {
        final markdown = NpcMarkdownCodec.exportCard(
          NpcCard(name: '哥布林', armorClass: 15),
          categoryName: defaultNpcCategoryName,
        );

        final parsed = NpcMarkdownCodec.parse(
          'modified.md',
          markdown.replaceFirst('哥布林', '洞穴哥布林'),
        );

        expect(parsed.status, NpcMarkdownImportStatus.modified);
        expect(parsed.importable, isTrue);
        expect(parsed.card!.name, '洞穴哥布林');
        expect(parsed.warnings.join(), contains('文件在导出后被修改'));
        expect(parsed.recordedChecksum, isNot(parsed.calculatedChecksum));
      },
    );

    test('best-effort parses Chinese headings, a table and common text', () {
      const markdown = '''
# 食人魔守卫

| 护甲等级 | 最大生命值 | 速度 | 挑战等级 |
| --- | --- | --- | --- |
| 13 | 59 | 40 尺 | 2 |

类型：大型巨人

## 动作
### 巨棒
近战武器攻击：命中 +6，触及 5 尺。

这一行无法归类。
''';

      final parsed = NpcMarkdownCodec.parse('ogre.md', markdown);

      expect(parsed.status, NpcMarkdownImportStatus.arbitrary);
      expect(parsed.card!.name, '食人魔守卫');
      expect(parsed.card!.armorClass, 13);
      expect(parsed.card!.maximumHitPoints, 59);
      expect(parsed.card!.speed, '40 尺');
      expect(parsed.card!.actions.single.name, '巨棒');
      expect(parsed.card!.actions.single.description, contains('这一行无法归类'));
      expect(parsed.warnings.single, contains('没有受支持'));
    });

    test('does not swallow an unclosed front matter block', () {
      const markdown = '''
---
# 骷髅
护甲等级：13
最大生命值：13
''';

      final parsed = NpcMarkdownCodec.parse('unclosed.md', markdown);

      expect(parsed.importable, isTrue);
      expect(parsed.card!.name, '骷髅');
      expect(parsed.card!.armorClass, 13);
    });

    test('rejects empty and nearly empty Markdown', () {
      final empty = NpcMarkdownCodec.parse('empty.md', ' \r\n');
      final headingOnly = NpcMarkdownCodec.parse('heading.md', '# 未完成 NPC\n');

      expect(empty.status, NpcMarkdownImportStatus.invalid);
      expect(headingOnly.status, NpcMarkdownImportStatus.invalid);
      expect(headingOnly.errorMessage, contains('没有识别到有意义'));
    });

    test('falls back for an unsupported application format version', () {
      const markdown = '''
---
DnDToolkit-NPC: 99
名称: "未来怪物"
护甲等级: 18
最大生命值: 80
---
''';

      final parsed = NpcMarkdownCodec.parse('future.md', markdown);

      expect(parsed.status, NpcMarkdownImportStatus.unsupported);
      expect(parsed.importable, isTrue);
      expect(parsed.warnings.join(), contains('不支持 DnDToolkit-NPC: 99'));
    });

    test(
      'reads the fixed LF fixture with Chinese and multiline fields',
      () async {
        final fixture = await File(
          'test/fixtures/dm/npc_markdown_v1_lf.md',
        ).readAsString();

        final parsed = NpcMarkdownCodec.parse('fixture.md', fixture);

        expect(parsed.status, NpcMarkdownImportStatus.verified);
        expect(parsed.card!.name, '月影狼');
        expect(parsed.card!.notes, contains('\n'));
        expect(parsed.card!.actions.single.description, contains('\n'));
      },
    );
  });

  group('NpcMarkdownService mobile sharing', () {
    test(
      'uses a unique name and removes its temporary file after sharing',
      () async {
        final tempDirectory = await Directory.systemTemp.createTemp(
          'dndtoolkit_npc_markdown_test_',
        );
        addTearDown(() async {
          if (await tempDirectory.exists()) {
            await tempDirectory.delete(recursive: true);
          }
        });
        final service = NpcMarkdownService();
        String? sharedPath;
        String? sharedContent;

        final result = await service.shareMobileText(
          '测试内容',
          tempDirectory,
          '狼/人',
          exportedAt: DateTime(2026, 8, 20, 12, 34, 56, 789, 123),
          shareFile: (file, _) async {
            sharedPath = file.path;
            sharedContent = await File(file.path).readAsString();
            expect(await File(file.path).exists(), isTrue);
          },
        );

        expect(result.disposition, NpcMarkdownExportDisposition.shared);
        expect(result.fileName, '狼_人_20260820_123456_789123.md');
        expect(sharedContent, '测试内容');
        expect(sharedPath, isNotNull);
        expect(await File(sharedPath!).exists(), isFalse);
      },
    );
  });
}
