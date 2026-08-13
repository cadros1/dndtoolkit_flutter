---
status: active
title: PDF 导入与导出
last_verified: 2026-08-13
related_code:
  - assets/Character.pdf
  - lib/services/pdf_data_service.dart
  - lib/pages/character_list_page.dart
---

# PDF 导入与导出

## 兼容范围

项目只保证兼容随应用分发的 `assets/Character.pdf`。该模板由项目作者基于网络流通版本自制，语言为中文，并作为应用功能资产随安装包分发。

不保证兼容官方其他版本、第三方改版、字段扁平化后的 PDF、扫描图片或字段名不同的表单。未来支持新模板时必须通过显式模板识别和独立映射实现，不能破坏现有模板。

字段规范的最终事实来源是 `lib/services/pdf_data_service.dart`；本文件用于解释和索引，不取代代码契约测试。

## 工作流

### 导入

1. 用户从角色列表选择一个 `.pdf`。
2. 服务读取 AcroForm，并对字段名 `trim()` 后建立映射。
3. 创建带新 UUID 的默认 `Character`。
4. 按字段名填充角色数据。
5. 保存为新的本地 JSON 并刷新列表。

导入不会尝试匹配或覆盖已有角色，因为 PDF 不承载项目的 `Character.id`。

### 导出

1. 加载内置 `Character.pdf` 和 `simsun.ttc`。
2. 把当前角色填入模板字段。
3. Windows 打开保存对话框；Android 写入临时文件并调用系统分享。
4. 文件名来自角色名，并将 Windows 禁止字符替换为 `_`；空名使用 `Unnamed_Character.pdf`。

### 文本字号与可编辑性

导出不会再把所有文本框统一设为 `12pt`。服务会根据字段类型、字段矩形和实际内容选择字号：单行字段最大 `12pt`，多行字段遵循模板的 `8pt` 上限，必要时以 `0.25pt` 为步长缩小，最低为 `4pt`。这样可以避免较长的职业/等级、种族和人物设定文字在导出外观中被边框裁切。

导出同时清除文本框的 `DoNotScroll` 标志，保留 AcroForm、字段名、画像按钮和编辑能力。内容长到 `4pt` 仍无法完整显示时，页面外观仍受固定版面限制，但用户可以在 Acrobat 等兼容编辑器中滚动查看和修改字段；应用不会截断或丢弃字段值。

## 字段映射

### 基础资料和外貌

| PDF 字段 | Character 字段 | 方向 |
| --- | --- | --- |
| `CharacterName` | `profile.characterName` | 双向 |
| `CharacterName 2`, `Character Image Name` | `profile.characterName` | 仅导出 |
| `PlayerName` | `profile.playerName` | 双向 |
| `Race` | `profile.race` | 双向 |
| `ClassLevel` | `profile.classAndLevel` | 双向 |
| `Background` | `profile.background` | 双向 |
| `Alignment` | `profile.alignment` | 双向 |
| `XP` | `profile.experiencePoints` | 双向 |
| `Age`, `Height`, `Weight`, `Eyes`, `Skin`, `Hair` | 对应 `profile` 外貌字段 | 双向 |
| `Character Image` | `profile.portraitBase64` | 双向 |

### 属性与熟练

- `STR/DEX/CON/INT/WIS/CHA` ↔ 六项属性值。
- `STRmod/.../CHAmod` 仅导出计算后的属性修正。
- `Check Box STR/.../CHA` ↔ 六项豁免熟练。
- `Check Box <中文技能名>` ↔ 十八技能熟练。
- `ProfBonus` ↔ 熟练加值。
- `Passive Perception` ↔ 被动察觉。
- `Inspiration` ↔ 灵感字符串。
- `ProficienciesLang` ↔ 其他熟练项与语言。

PDF 技能名使用：运动、杂技、巧手、躲藏、奥秘、历史、调查、自然、宗教、驯兽、洞悉、医药、察觉、生存、欺瞒、威吓、表演、游说。

### 战斗、装备和武器

| PDF 字段 | Character 字段/行为 |
| --- | --- |
| `AC` | `combat.armorClass` |
| `Initiative` | `combat.initiative` |
| `Speed` | `combat.speed` |
| `HPMax` | `combat.hitPointsMax` |
| `HPCurrent` | 导出时写最大 HP；导入时不读取，当前 HP 设置为最大 HP |
| `HPTemp` | 导入到临时 HP；当前不导出 |
| `HDTotal` | `combat.hitDiceTotal` |
| `HDCurrent` | 导出时写总生命骰；导入时不读取，当前生命骰设置为总生命骰 |
| `AttacksAndSpellcasting` | `combat.attacksAndSpellcastingNotes` |
| `Ability` | `combat.ability` |
| `Equipment` | `inventory.equipmentText` |
| `CP/SP/EP/GP/PP` | 五类钱币 |
| `Wpn Name 1..3` | 前三个武器名称 |
| `Wpn1..3 AtkBonus` | 前三个武器攻击加值 |
| `Wpn1..3 Damage` | 前三个武器伤害文本 |

PDF 最多映射三个武器。导入后不足三个会补空槽；超过三个的本地武器不会导出。

### 人物设定

| PDF 字段 | Character 字段 |
| --- | --- |
| `PersonalityTraits` | `roleplay.personalityTraits` |
| `Ideals` | `roleplay.ideals` |
| `Bonds` | `roleplay.bonds` |
| `Flaws` | `roleplay.flaws` |
| `角色经历` | `roleplay.characterExperience` |
| `Backstory` | `roleplay.characterBackstory` |
| `Allies` | `roleplay.alliesAndOrganizations` |
| `Treasure` | `roleplay.treasure` |
| `Feat+Traits` | `roleplay.additionalFeaturesAndTraits` |

`additionalFeaturesAndTraits` 是 UI 与 PDF 共用的正式字段，PDF 导入和导出均只使用该字段。

### 施法

- `Spellcasting Class` ↔ 施法职业。
- `SpellcastingAbility` ↔ 施法关键属性。
- `SpellSaveDC` ↔ 法术豁免难度。
- `SpellAtkBonus` ↔ 法术攻击加值。
- `SlotsTotal 1..9` ↔ 总法术位。
- `SlotsRemaining 1..9` 导出时写总法术位；导入时不读取，剩余值设置为总值。
- `Spells LNN` ↔ 指定环级和序号的法术名称。
- `Check Box SLNN` ↔ 对应法术是否准备。

后缀由环级 `L` 和两位序号 `NN` 组成，例如 1 环第一个槽为 `101`。

## 动态状态边界

PDF 被视为“角色卡基线交换格式”，不是冒险中实时状态快照。当前 round trip 不完整保留：

- 当前 HP 被重置为最大 HP。
- 当前生命骰被重置为总生命骰。
- 剩余法术位被重置为总法术位。
- 临时 HP 只导入、不导出。
- 死亡豁免状态不映射。
- 超过三个的武器不映射。
- 云端身份令牌、角色 ID、更新时间和骰子日志不映射。

后续如希望 PDF 保存动态状态，需要先确认模板字段和兼容意图，不能静默改变现有语义。

## 画像处理与当前限制

正式导入会从 `Character Image` 按钮读取画像并保存到 `profile.portraitBase64`；正式导出会把本地画像写入按钮 icon 和 normal appearance。按钮字段、Acrobat JavaScript 动作和可编辑状态会保留，不会把画像绘制到页面或压平表单。

底层读取方法优先从按钮 `/MK /I` icon 中读取图片，其次检查 normal appearance。当前支持：

- DCTDecode JPEG 直接提取。
- FlateDecode 或无 filter 的 DeviceRGB/DeviceGray、8 bit 图片包装为 PNG。
- 可读取 8 bit soft mask 并生成 RGBA PNG。

其他色彩空间、位深或 filter 可能无法提取。图片为空、损坏、不受支持、超过 8 MiB 或任一边超过 8192 像素时，只跳过画像，文字角色卡仍会正常导入或导出。写入时按按钮区域等比缩放居中。

底层实现依赖 Syncfusion PDF 24.2.9 的内部接口，因此该依赖固定为精确版本。升级 PDF 库前必须运行画像、按钮动作和完整 PDF 回归测试。

## 错误与测试要求

- 无法读取、字段类型不符或 PDF 损坏时提示“读取 PDF 失败”。
- 缺失单个字段通常回退为空字符串、0 或 false，而不是拒绝整个文档。
- 关键结构完全不匹配时目前可能仍产生大量默认值角色；未来应增加模板识别/必填字段校验。
- 测试 fixture 必须放在仓库中并脱敏，禁止依赖个人下载或图片目录。
- 模板或字段映射变化必须包含双向契约测试和旧模板回归。
- 画像测试使用内置模板和程序生成图片，并验证画像往返、失败回退、文字字段、按钮类型及按钮动作保留。
- 文本布局测试应覆盖长单行字段、长多行字段、动态字号下限和 `DoNotScroll` 清除后的可编辑性。
