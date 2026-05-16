# DnD Toolkit

![Flutter Version](https://img.shields.io/badge/Flutter-3.x-blue.svg)
![License](https://img.shields.io/badge/License-PolyForm%20Noncommercial%201.0.0-green.svg)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows-lightgrey.svg)

**DnD Toolkit** 是一款为龙与地下城（D&D）等跑团游戏设计的角色卡管理与游戏辅助工具。该版本使用 Flutter 重构，主要面向移动端（Android/iOS），并提供现代化的跨平台体验，让你能在任何设备上轻松管理角色状态、进行检定。

## ✨ 核心功能

- **角色管理**: 快速创建、全面编辑与管理你的角色卡（属性、技能、专长、魔法等）。
- **快捷掷骰检定**: 内置快捷的属性与技能检定系统，一键完成判定。
- **动态状态追踪**: 在冒险中实时记录并更新角色的生命值、法术位、物品消耗及其他临时状态。
- **云端同步与导出**: 
  - 支持局域网内的桌面端（WPF）与移动端（Flutter）角色卡互传。
  - 借助 Supabase 提供云端数据同步支持。
  - 支持导出 / 解析跑团相关的 PDF 内容。
- **现代化设计**: 清晰整洁的 Material UI，对触屏交互进行了深度优化。

## 🚀 待开发路线图
- [x] 创建与编辑角色卡
- [x] 智能属性与技能检定
- [x] 实时角色状态记录
- [x] 局域网内桌面与移动端数据互传
- [x] Supabase 云端同步基础接入
- [ ] 多人联机跑团与 DM 交互系统
- [ ] 多语言支持

## 🛠️ 技术栈

- **框架**: Flutter (Dart)
- **数据管理**: `shared_preferences`, 本地 JSON, 构建生成器 (`json_serializable`)
- **云端服务**: Supabase (`supabase` package)
- **特定功能**: 
  - `file_picker` & `syncfusion_flutter_pdf`（文件及 PDF 操作）
  - `url_launcher` & `share_plus`（分享与外部链接）
  - `uuid` (唯一标识生成)

## 📦 开始使用

### 环境要求
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (推荐 3.10.1 及以上)

### 安装与运行

1. 克隆本项目：
   ```bash
   git clone https://github.com/cadros1/dndtoolkit_flutter.git
   cd dndtoolkit_flutter
   ```

2. 安装依赖：
   ```bash
   flutter pub get
   ```

3. 生成必要的数据序列化文件（如遇报错请先执行此步骤）：
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. 运行项目：
   ```bash
   flutter run
   ```

## 📄 许可协议

本项目采用 **PolyForm Noncommercial License 1.0.0** 许可协议。

您可以在非商业用途下自由使用、复制和分发本软件。详细条款请参阅项目中的静态许可文件 (`assets/LICENSE`) 或在线协议 [PolyForm Noncommercial License 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0/)。