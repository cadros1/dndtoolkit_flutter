# 代码审查后续问题记录

审查日期：2026-06-22

本文档记录本次代码审查中需要后续处理的问题。以下问题已按要求暂不纳入本文档：

- PDF 导出使用最大生命值、最大生命骰、总法术位覆盖当前冒险状态。这是当前产品设计，不作为缺陷处理。
- 同步令牌使用 `SharedPreferences` 明文存储。暂时忽略。
- 静态分析、CI、测试覆盖等质量门槛问题。暂时忽略。

## 1. 云同步下载保存会破坏冲突时间戳

优先级：P1

位置：

- `lib/services/cloud_sync_service.dart`
  - `downloadCharacter` 将云端 `updated_at` 写入 `character.updatedAt`
- `lib/pages/sync/sync_center_page.dart`
  - `_handleDownload` 下载后调用 `_storage.saveCharacter(character)`
- `lib/services/character_storage.dart`
  - `saveCharacter` 保存前无条件执行 `character.updatedAt = DateTime.now().toUtc()`

原因：

云端下载流程先保留了云端更新时间，但本地保存流程会立刻把它改成本机当前时间。这样刚下载的角色会被标记为“本地较新”，导致后续上传冲突检测无法准确判断云端是否已经发生更新。

影响：

用户从云端下载角色后，如果没有实际编辑，角色仍可能被视为本地新版本。之后上传时可能绕过“云端版本更新”的提示，覆盖其他设备刚同步上去的数据。

建议措施：

- 将 `CharacterStorage.saveCharacter` 拆出保存语义，例如：
  - `saveCharacter(character)`：用于用户编辑，更新 `updatedAt`
  - `saveDownloadedCharacter(character)` 或 `saveCharacter(character, touchUpdatedAt: false)`：用于同步落盘，不改写云端时间戳
- 下载后本地落盘应保留云端 `updated_at`。
- 上传成功后应刷新云端列表，并用服务器返回或重新查询到的 `updated_at` 更新本地对象，避免本地和云端时间源长期漂移。

## 2. 本地角色加载缺少坏文件容错

优先级：P1

位置：

- `lib/services/character_storage.dart`
  - `loadAllCharacters` 读取应用文档目录下所有 `.json`
  - 直接执行 `jsonDecode(content)` 和 `Character.fromJson(jsonMap)`

原因：

角色存储直接按 `.json` 后缀读取所有文件。该目录可能存在用户手动拷贝、同步残留或写入中断产生的损坏文件。当前实现没有逐文件异常隔离。

影响：

只要目录中出现一个无关 JSON 或损坏 JSON，角色列表、冒险页和同步页都可能加载失败，表现为整页不可用，而不是仅跳过坏文件。

建议措施：

- 加载时校验文件名或 JSON 基本结构，避免误读非角色文件。
- 对单个文件的读取和解析加 `try/catch`，失败时跳过该文件并记录可诊断信息。
- 如需要用户感知，可在 UI 展示“部分角色文件读取失败”的非阻断提示。

## 3. 云端 JSONB 下载类型处理不一致

优先级：P2

位置：

- `lib/services/cloud_sync_service.dart`
  - `CloudCharacterSummary.fromRow` 兼容 `row['data']` 为 `Map<String, dynamic>` 或 `String`
  - `downloadCharacter` 只按 `Map<String, dynamic>` 读取 `row['data']`

原因：

列表摘要路径已经考虑 Supabase JSONB 可能返回字符串或已解析 Map，但详情下载路径没有复用同样的解析逻辑。如果后端或 SDK 返回字符串 JSON，列表可以正常展示，但下载会得到空数据或发生类型错误。

影响：

用户看到云端角色列表后点击下载，可能在下载详情阶段失败。该问题会表现为同一份云端数据“可见但不可下载”，排查成本较高。

建议措施：

- 抽出统一的解析函数，例如 `_decodeCharacterData(Object? rawData)`。
- 在列表摘要和详情下载中复用该函数。
- 当 `rawData` 不是可识别类型或 JSON 结构无效时，抛出包含上下文的业务异常，不要静默降级为空角色。
- 为 `rawData` 是 `Map`、`String`、非法字符串、空值的情况补单元测试。

## 4. 冒险页 HP 输入框在 build 中创建控制器

优先级：P2

位置：

- `lib/pages/adventure_page.dart`
  - `_buildHpStepperRow` 内部每次 build 都创建 `TextEditingController`
  - 该 controller 没有对应 `dispose`

原因：

`TextEditingController` 是有生命周期的对象，不应在普通 build/helper 方法里临时创建。HP 输入变化会触发 `setState`，页面重建后会反复创建新的 controller，并重置 selection。

影响：

连续输入或频繁点击加减按钮时，可能出现光标跳动、输入状态被重置、额外对象分配和潜在内存泄漏。这个路径在跑团时属于高频交互。

建议措施：

- 将 HP 步进输入抽成独立 `StatefulWidget`，在 `initState` 创建 controller，在 `didUpdateWidget` 同步外部值，在 `dispose` 释放。
- 或复用现有 `StepInputCard` / `CurrencyStepRow` 的 controller 生命周期模式。
- 删除 `ValueKey("hp_field_$label$value")` 这种强制重建策略，改为通过 controller 同步值。

## 5. 画像 base64 解码失败时在 build 阶段弹窗

优先级：P2

位置：

- `lib/pages/tabs/character_settings_tab.dart`
  - `_buildPortraitArea` 中 `base64Decode` 失败后直接调用 `showDialog`
  - `_pickImage` 在 `await image.readAsBytes()` 后 `setState` 前未检查 `mounted`

原因：

`build` 阶段应保持无副作用。当前实现如果角色画像 base64 损坏，每次构建画像区域都可能再次触发弹窗。图片选择流程中，异步读取结束后页面可能已经销毁，缺少 `mounted` 检查会带来生命周期风险。

影响：

损坏图片数据可能导致重复弹窗，甚至在 build 过程中触发 framework 异常或不稳定 UI 行为。异步图片选择返回较慢时，离开页面后仍可能尝试更新已卸载的 widget。

建议措施：

- 在 build 中只做安全解码，失败时返回空画像或错误占位，不直接弹窗。
- 将错误提示放到事件流程中处理，例如用户点击画像区域、保存校验或进入页面后的 post-frame 一次性提示。
- 解码失败后可提供“清除损坏画像”的操作，避免每次构建重复遇到同一坏数据。
- `_pickImage` 中在每个 `await` 之后检查 `mounted`，再调用 `setState` 或展示提示。
