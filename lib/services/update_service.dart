import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'snack_bar_service.dart';

class UpdateService extends ChangeNotifier {
  // 单例模式
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  bool _hasNewVersion = false;
  String _latestVersion = "";
  String _releaseNotes = "";
  String _downloadUrl = "";
  
  // GitHub 配置
  final String _repoUrl = "https://github.com/cadros1/dndtoolkit_flutter";
  final String _apiUrl = "https://api.github.com/repos/cadros1/dndtoolkit_flutter/releases/latest";

  bool get hasNewVersion => _hasNewVersion;
  String get latestVersion => _latestVersion;
  String get releaseNotes => _releaseNotes;
  String get downloadUrl => _downloadUrl.isEmpty ? _repoUrl : _downloadUrl;

  /// 检查更新
  /// [silent]: 是否静默检查（不抛出异常，只更新状态）
  Future<bool> checkUpdate({bool silent = true}) async {
    try {
      // 1. 获取本地版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 2. 获取远程版本
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String tagName = data['tag_name'] ?? "";
        final String htmlUrl = data['html_url'] ?? _repoUrl;
        final String body = data['body'] ?? "没有更新说明";

        // 移除 'v' 前缀进行对比
        final cleanTagName = tagName.replaceAll('v', '');

        // 简单的字符串对比 (生产环境建议用 pub_semver)
        if (cleanTagName.isNotEmpty && cleanTagName != currentVersion) {
          _hasNewVersion = true;
          _latestVersion = tagName;
          _releaseNotes = body;
          _downloadUrl = htmlUrl;
          notifyListeners(); // 通知 UI 显示红点
          return true;
        }
      }
    } catch (e) {
      if (!silent) rethrow;
      SnackBarService.showError("检查更新失败: $e");
    }
    
    // 如果没有更新或出错，且之前有更新标记，这里保持 true 还是重置为 false？
    // 通常如果检查失败，保持上次状态或重置。这里我们不重置为 false，以免红点闪烁消失。
    return false;
  }
}