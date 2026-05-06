import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/token_manager.dart';
import '../services/cloud_sync_service.dart';
import '../services/snack_bar_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _token;
  bool _loading = true;
  late final TextEditingController _tokenController;

  // UUID v4 格式正则
  static final _uuidV4RegExp = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController();
    _loadToken();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final t = await TokenManager.instance.getToken();
    if (mounted) {
      setState(() {
        _token = t;
        _tokenController.text = t ?? '';
        _loading = false;
      });
    }
  }

  /// 校验并应用输入框中的令牌
  Future<void> _saveAndApplyToken() async {
    final input = _tokenController.text.trim();
    if (input.isEmpty) {
      SnackBarService.showError('令牌不能为空');
      return;
    }
    if (!_uuidV4RegExp.hasMatch(input)) {
      SnackBarService.showError('令牌格式不正确，应为标准 UUID v4 格式');
      return;
    }

    await TokenManager.instance.saveToken(input);
    await CloudSyncService.instance.resetClient();

    if (mounted) {
      setState(() => _token = input);
      SnackBarService.showSuccess('令牌已保存并应用');
    }
  }

  /// 复制输入框内容到剪贴板
  void _copyToken() {
    final text = _tokenController.text.trim();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    SnackBarService.showSuccess('身份令牌已复制到剪贴板');
  }

  /// 生成新令牌 —— 红色警告弹窗
  Future<void> _regenerateToken() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 48),
        title: const Text("⚠️ 严重警告"),
        content: Text(
          "生成新令牌可能导致您失去当前云端所有数据的访问权限，且无法找回。\n\n"
          "当前令牌：\n${_token ?? '无'}\n\n"
          "是否确认生成新令牌？",
          style: TextStyle(
            color: Theme.of(ctx).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("取消"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("确认生成并应用"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newToken = TokenManager.generateToken();
      await TokenManager.instance.saveToken(newToken);
      await CloudSyncService.instance.resetClient();

      if (mounted) {
        setState(() {
          _token = newToken;
          _tokenController.text = newToken;
        });
        _showNewTokenDialog(newToken);
      }
    }
  }

  void _showNewTokenDialog(String token) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("新令牌已生成并应用"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("您的新身份令牌为："),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                token,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            Icon(Icons.info_outline, color: Theme.of(ctx).colorScheme.primary, size: 18),
            const SizedBox(height: 4),
            Text(
              "请妥善保存此令牌。您需要使用它来访问云端角色数据。",
              style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("设置"),
        backgroundColor: cs.inversePrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 8),
                // 身份令牌区域
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    "身份令牌",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.vpn_key_outlined, color: cs.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "当前令牌",
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 可编辑的令牌输入框
                        TextField(
                          controller: _tokenController,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: cs.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: '请输入或生成 UUID v4 令牌',
                            hintStyle: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 12),
                        // 按钮行
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _saveAndApplyToken,
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text("保存并应用"),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: _copyToken,
                              child: const Text("复制"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 危险操作区域
                if (_token != null && _token!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      "危险操作",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.error,
                      ),
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.refresh, color: cs.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "生成新令牌",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "生成新令牌后，旧令牌将无法再访问云端数据。",
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _regenerateToken,
                              icon: const Icon(Icons.warning_rounded, size: 18),
                              label: const Text("生成新令牌"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.error,
                                side: BorderSide(color: cs.error),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
