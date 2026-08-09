---
status: accepted
title: ADR-0003：仅正式支持 Windows 与 Android
date: 2026-08-08
---

# ADR-0003：仅正式支持 Windows 与 Android

## 背景

Flutter 默认生成多个平台目录，但维护、测试和发布每个平台都需要持续成本。项目的主要场景集中在桌面角色编辑和移动跑团操作。

## 决策

- 正式支持 Windows 和 Android。
- Windows 面向集中编辑和文件操作，使用 Inno Setup 6 EXE 安装包发布。
- Android 面向跑团快捷操作，使用 APK 发布。
- 两端功能当前不裁剪，共享同一数据和领域模型。
- iOS、macOS、Linux、Web 明确不支持；保留目录不代表承诺。
- 发布渠道当前为 GitHub Releases。

## 结果

- 开发和测试资源集中在两个平台。
- UI 仍采用响应式设计，而不是两套业务代码。
- 非目标平台的模板文件可能继续存在，但不应驱动依赖选择或发布说明。
- 最低 Windows/Android 版本仍需通过路线图确定、固定和测试。
