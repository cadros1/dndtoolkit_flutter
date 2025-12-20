import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
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
  /// [silent]: 是否静默检查（静默模式下，网络错误不会弹窗提示）
  Future<bool> checkUpdate({bool silent = true}) async {
    try {
      // 1. 获取本地版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = Version.parse(packageInfo.version);

      // 2. 获取远程版本
      final response = await http.get(Uri.parse(_apiUrl));

      // --- [修改] 状态处理逻辑 ---
      
      // Case A: 成功获取到 Release 信息
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String tagName = data['tag_name'] ?? "";
        
        if (tagName.isEmpty) {
          // 如果 tag 为空，视为没有更新
          _resetUpdateState();
          return false;
        }

        final String cleanTagName = tagName.replaceAll('v', '');
        final Version latestVersion;
        try {
          latestVersion = Version.parse(cleanTagName);
        } catch (e) {
          // 如果远程 tag 格式不规范，无法解析，也视为没有更新
          _resetUpdateState();
          return false;
        }

        // 使用 pub_semver 进行版本比较
        if (latestVersion > currentVersion) {
          _hasNewVersion = true;
          _latestVersion = tagName;
          _releaseNotes = data['body'] ?? "没有更新说明";
          _downloadUrl = data['html_url'] ?? _repoUrl;
          notifyListeners(); // 通知 UI 显示红点
          return true;
        } else {
          // 当前已是最新版，清除更新状态
          _resetUpdateState();
          return false;
        }
      } 
      // Case B: 仓库没有发布任何 Release
      else if (response.statusCode == 404) {
        // 404 意味着没有 'latest' release，这也是一种“没有更新”
        _resetUpdateState();
        return false;
      }
      // Case C: 其他 HTTP 错误 (如 403 频率限制, 500 服务器错误)
      else {
        if (!silent) {
          SnackBarService.showError("检查更新失败，服务器响应: ${response.statusCode}");
        }
        // 在HTTP错误时，不改变 _hasNewVersion 的状态，避免红点因临时网络问题消失
        return _hasNewVersion;
      }

    } catch (e) {
      // Case D: 网络异常 (如无网络连接)
      if (!silent) {
        SnackBarService.showError("检查更新失败，请检查网络连接");
      }
      // 在网络异常时，同样不改变状态
      return _hasNewVersion;
    }
  }

  /// 辅助方法：重置更新状态并通知 UI
  void _resetUpdateState() {
    // 只有当状态确实发生改变时才通知，避免不必要的重绘
    if (_hasNewVersion) {
      _hasNewVersion = false;
      _latestVersion = "";
      _releaseNotes = "";
      _downloadUrl = "";
      notifyListeners(); // 通知 UI 移除红点
    }
  }
}