# DnD Toolkit AI 协作指南

本文件是 AI 在本仓库工作的首要入口。开始任务前先阅读本文件，再按任务范围阅读 [`docs/文档索引.md`](docs/文档索引.md) 中列出的相关文档；不要只根据文件名或旧 README 推断产品行为。

## 项目定位

DnD Toolkit 是面向 Dungeons & Dragons 5E 2014 规则的 Flutter 角色卡与跑团辅助工具。目标用户是任何需要编辑角色卡、查看跑团状态或进行检定的人，不区分玩家与 DM。

- 正式支持平台：Windows、Android。
- 明确不支持：iOS、macOS、Linux、Web。仓库中的对应平台目录只是 Flutter 模板遗留，不代表产品支持。
- Windows 更适合角色卡编辑，Android 更适合跑团中的快捷检定和状态查看；当前功能能力不按平台裁剪。
- 核心功能离线可用。云端备份需要网络；GitHub 更新检查也会选择性联网，但失败不影响核心功能。
- 规则基线是 5E 2014；5R（5E 2024）兼容属于后续路线。
- 普通掷骰结果只展示和记录在当前页面会话中，不自动判断 DC，也不改变角色状态。冒险页的专用死亡豁免 Card 是唯一例外：它按 5E 2014 记录成功/失败，自然 20 会恢复 1 点生命值。
- 应用只提供计算、空白字段和用户自行输入的内容，不内置职业、种族、法术、专长或规则原文。

## 事实来源与冲突处理

按以下顺序理解信息：

1. 用户在当前任务中明确提出的要求。
2. `docs/产品概览.md` 与架构决策记录中记录的产品意图和长期决策。
3. `docs/领域模型.md`、`docs/数据存储与云端备份.md`、功能文档中的兼容契约。
4. 测试和当前代码所表现的现有行为。
5. `README.md` 中的用户介绍与路线描述。

产品意图和现有代码不一致时，不要静默选边：应指出差异，将修复范围交代清楚。除非任务明确要求，不要借文档任务顺带改变业务行为。

## 代码地图

- 应用入口与启动服务：`lib/main.dart`
- 一级导航与页面切换：`lib/pages/main_screen.dart`
- 角色列表、创建、删除、PDF 入口：`lib/pages/character_list_page.dart`
- 角色编辑容器：`lib/pages/character_edit_page.dart`
- 角色编辑页签：`lib/pages/tabs/`
- 冒险状态与检定中心：`lib/pages/adventure_page.dart`
- 云端备份 UI：`lib/pages/sync/sync_center_page.dart`
- 核心领域模型：`lib/models/character.dart`
- JSON 生成代码：`lib/models/character.g.dart`
- 本地存储：`lib/services/character_storage.dart`
- 云端备份：`lib/services/cloud_sync_service.dart`
- 身份令牌：`lib/services/token_manager.dart`
- PDF 映射：`lib/services/pdf_data_service.dart`
- 更新检查：`lib/services/update_service.dart`
- 主题与共享 UI：`lib/theme/app_theme.dart`、`lib/widgets/app_ui.dart`
- 已废弃局域网实现：`lib/services/lan_sync_service.dart`、`lib/pages/sync/discovery_page.dart`、`lib/pages/sync/transfer_page.dart`

## 架构约束

- 当前架构以 `StatefulWidget`、可变领域对象和轻量服务类为主，没有引入 BLoC、Riverpod、Provider 等全局状态管理框架。不要只为局部改动引入新的状态管理体系。
- 本地 JSON 是角色数据的主要副本；Supabase 是用户手动操作的云端备份，不是实时同步或多人协作系统。
- 一个角色以 UUID 字符串 `Character.id` 标识。本地文件名为 `<id>.json`，云端以 `(id, sync_token)` 为联合主键。
- JSON 使用 PascalCase 字段名。`filePath` 不参与序列化；`updatedAt` 参与序列化并用于备份冲突提示。
- 云端不得保存 `Profile.PortraitBase64`。下载同 ID 角色时，应尽量保留本地已有画像。
- 角色数据已被小规模真实用户使用。任何模型或序列化改动都必须保持向后兼容；不能无迁移地改名、删除字段或改变字段类型。
- 无法解析的本地角色文件的目标行为是“向用户提示并跳过”，不能因为一个坏文件阻止其他角色加载。当前实现尚未完成 UI 提示，见 `docs/项目状态与路线图.md`。
- PDF 只兼容随应用分发的 `assets/Character.pdf`。字段名和映射以 `PdfDataService` 当前代码为契约。
- 局域网同步已经废弃。不要在新功能中继续依赖旧 LAN 服务或 WPF 配套端。
- 中文术语以当前 UI 为准。新增面向用户的文本保持中文，并使用 UTF-8。

## 生成文件与敏感配置

- 不要手工编辑 `lib/models/character.g.dart`；修改 `character.dart` 后运行代码生成。
- `build/`、`.dart_tool/`、`node_modules/` 和平台生成文件通常不应作为业务修改目标。
- Supabase publishable/anon key可以存在于客户端；身份令牌是 bearer secret，不应写入日志、测试 fixture、截图或文档示例。
- 不要把真实用户角色、身份令牌、个人绝对路径或含私密内容的 PDF 提交到仓库。

## 常用命令

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build windows
flutter build apk
```

涉及 Android 正式发布前还必须配置唯一 `applicationId` 和 release signing；当前配置仍使用默认包名与 debug 签名。Windows 安装包使用 Inno Setup 6 在 Flutter release 产物基础上制作，仓库目前没有对应安装脚本。

## 修改检查清单

### 修改角色模型或持久化

- 说明旧 JSON 如何继续读取。
- 新字段提供安全默认值；需要时增加显式迁移或 schema version。
- 重新生成 `character.g.dart`。
- 检查本地保存、PDF、云端上传下载和冒险页四条数据路径。
- 增加旧版 fixture 与 round-trip 测试。
- 更新 `docs/领域模型.md` 和 `docs/数据存储与云端备份.md`。

### 修改掷骰或 5E 规则

- 先阅读 `docs/功能/掷骰检定.md`。
- 区分“计算结果”和“规则判定”；应用不替代 DM 判定成功或失败。
- 不把自然 20/1 扩展成对所有检定自动成功/失败。
- 增加确定性测试；随机数逻辑应可注入或拆分后测试。

### 修改云端备份

- 保持 RLS 的 `x-sync-token` 隔离契约。
- 确认图片仍不会进入云端 payload。
- 检查时钟偏差、空 `updatedAt`、覆盖提示和令牌更换行为。
- 不把云备份描述成账户系统、实时同步或端到端加密。

### 修改 PDF

- 以 `assets/Character.pdf` 和 `PdfDataService` 字段映射为准。
- 使用仓库内脱敏 fixture；禁止依赖开发者个人目录。
- 同时测试中文文本、复选框、法术槽位和画像 round trip。
- 更新 `docs/功能/PDF导入与导出.md`。

### 完成任何代码任务

- 运行格式化、静态检查和相关测试。
- Windows 与 Android 的交互和文件行为都要考虑。
- 若改变用户可见行为、数据契约或架构，同步更新相关文档和 ADR。
- 在交付说明中明确：改了什么、验证了什么、仍有哪些限制。
