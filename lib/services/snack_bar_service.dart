import 'package:flutter/material.dart';

class SnackBarService {
  // 1. 定义一个全局 Key，用于在任何地方获取 ScaffoldMessenger 的状态
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// 显示通用 SnackBar (私有底层方法)
  static void _show({
    required String message,
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    // 如果当前有显示的 SnackBar，先移除，避免堆积
    scaffoldMessengerKey.currentState?.removeCurrentSnackBar();

    // 显示新的 SnackBar
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating, // 悬浮样式，更好看
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: duration,
        margin: const EdgeInsets.all(16), // 外边距
        elevation: 4,
      ),
    );
  }

  // --- 公开 API ---

  /// 显示成功信息 (绿色)
  static void showSuccess(String message) {
    _show(
      message: message,
      backgroundColor: Colors.green.shade600,
      icon: Icons.check_circle_outline,
    );
  }

  /// 显示错误信息 (红色)
  static void showError(String message) {
    _show(
      message: message,
      backgroundColor: Colors.red.shade600,
      icon: Icons.error_outline,
    );
  }

  /// 显示警告信息 (橙色)
  static void showWarning(String message) {
    _show(
      message: message,
      backgroundColor: Colors.orange.shade800,
      icon: Icons.warning_amber_rounded,
    );
  }

  /// 显示普通通知 (深灰色/主题色)
  static void showInfo(String message) {
    _show(
      message: message,
      backgroundColor: Colors.grey.shade800,
      icon: Icons.info_outline,
    );
  }
}