import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 身份令牌管理服务
/// 使用 shared_preferences 持久化存储用户的同步令牌
class TokenManager {
  static const String _tokenKey = 'cloud_sync_token';

  static TokenManager? _instance;
  static TokenManager get instance => _instance ??= TokenManager._();

  TokenManager._();

  /// 获取本地保存的令牌，如果没有则返回 null
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// 保存令牌到本地
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// 生���一个新的 UUID v4 令牌
  static String generateToken() => const Uuid().v4();

  /// 检查是否有令牌，首次启动时弹窗引导用户生成
  /// 返回当前的令牌（可能刚生成）
  /// [context] 用于弹出对话框
  static Future<String?> ensureToken(BuildContext context) async {
    final existingToken = await instance.getToken();
    if (existingToken != null && existingToken.isNotEmpty) {
      return existingToken;
    }

    // 没有令牌，弹窗询问用户是否生成
    String? newToken;
    final shouldGenerate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("欢迎使用云端同步"),
        content: const Text(
          "检测到您尚未设置身份令牌。\n\n"
          "云端同步使用无密码令牌制，系统将为您生成一个唯一的身份令牌，"
          "用于标识您的角色数据。\n\n"
          "请妥善保存此令牌，它相当于您云端数据的钥匙。",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("暂不开启"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("生成令牌"),
          ),
        ],
      ),
    );

    if (shouldGenerate == true && context.mounted) {
      newToken = generateToken();
      await instance.saveToken(newToken);

      // 展示令牌给用户
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("令牌已生成"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("您的身份令牌为："),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    newToken!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "⚠️ 请妥善保存此令牌，它相当于您云端数据的钥匙。",
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("我已复制并保存"),
              ),
            ],
          ),
        );
      }
    }

    return newToken ?? existingToken;
  }
}
