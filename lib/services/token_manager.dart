import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'snack_bar_service.dart';

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
    final saved = await prefs.setString(_tokenKey, token);
    if (!saved) {
      throw Exception('身份令牌保存失败');
    }
  }

  /// 移除本地保存的令牌
  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    final removed = await prefs.remove(_tokenKey);
    if (!removed && prefs.containsKey(_tokenKey)) {
      throw Exception('身份令牌移除失败');
    }
  }

  /// 生成一个新的 UUID v4 令牌
  static String generateToken() => const Uuid().v4();

  /// 检查是否有令牌，首次启动时弹窗引导用户生成
  /// 返回当前的令牌（可能刚生成）
  /// [context] 用于弹出对话框
  static Future<String?> ensureToken(BuildContext context) async {
    final existingToken = await instance.getToken();
    if (existingToken != null && existingToken.isNotEmpty) {
      return existingToken;
    }
    if (!context.mounted) return existingToken;

    String? newToken;
    final shouldGenerate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('开启云端备份'),
        content: const Text(
          '这台设备还没有身份令牌。生成后，另一台设备填入同一令牌，就能看到同一份云端备份。\n\n'
          '应用无法帮你找回令牌，请妥善保存。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('暂不开启'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('生成身份令牌'),
          ),
        ],
      ),
    );

    if (shouldGenerate == true && context.mounted) {
      newToken = generateToken();
      try {
        await instance.saveToken(newToken);
      } on Exception {
        if (context.mounted) {
          SnackBarService.showError('没有保存成功，请重新尝试');
        }
        return existingToken;
      }

      if (context.mounted) {
        var saved = false;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return PopScope(
                  canPop: saved,
                  child: AlertDialog(
                    title: const Text('新令牌已生成'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                ctx,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SelectableText(
                              newToken!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                height: 1.45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await Clipboard.setData(
                                  ClipboardData(text: newToken!),
                                );
                                SnackBarService.showSuccess('身份令牌已复制');
                              } on Exception {
                                SnackBarService.showError('复制失败，请重新尝试');
                              }
                            },
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('复制令牌'),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '应用无法帮你找回令牌，请保存到可信的位置。',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('我已把新令牌保存好'),
                            value: saved,
                            onChanged: (value) {
                              setDialogState(() => saved = value ?? false);
                            },
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      FilledButton(
                        onPressed: saved ? () => Navigator.pop(ctx) : null,
                        child: const Text('完成'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      }
    }

    return newToken ?? existingToken;
  }
}
