import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cloud_sync_service.dart';
import '../services/snack_bar_service.dart';
import '../services/token_manager.dart';
import '../widgets/app_ui.dart';

final RegExp _uuidV4RegExp = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

class IdentityTokenPage extends StatefulWidget {
  const IdentityTokenPage({super.key});

  @override
  State<IdentityTokenPage> createState() => _IdentityTokenPageState();
}

class _IdentityTokenPageState extends State<IdentityTokenPage> {
  String? _token;
  bool _loading = true;
  bool _busy = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }

    try {
      final token = await TokenManager.instance.getToken();
      if (!mounted) return;
      setState(() {
        _token = token == null || token.isEmpty ? null : token;
        _loading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _copyToken(String token) async {
    try {
      await Clipboard.setData(ClipboardData(text: token));
      if (mounted) {
        SnackBarService.showSuccess('身份令牌已复制');
      }
    } on Exception {
      if (mounted) {
        SnackBarService.showError('复制失败，请重新尝试');
      }
    }
  }

  Future<bool> _applyToken(String token) async {
    if (_busy) return false;
    final previousToken = _token;
    setState(() => _busy = true);

    try {
      await TokenManager.instance.saveToken(token);
      await CloudSyncService.instance.resetClient();
      if (!mounted) return false;
      setState(() => _token = token);
      SnackBarService.showSuccess(
        previousToken == null ? '身份令牌已保存' : '身份令牌已更换',
      );
      return true;
    } on Exception {
      try {
        if (previousToken == null) {
          await TokenManager.instance.removeToken();
        } else {
          await TokenManager.instance.saveToken(previousToken);
        }
        await CloudSyncService.instance.resetClient();
      } on Exception {
        // 恢复失败时仍以重新读取的本地状态为准。
      }
      if (!mounted) return false;
      await _loadToken();
      if (mounted) {
        SnackBarService.showError('没有保存成功，请重新尝试');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _useExistingToken() async {
    if (_busy) return;
    final candidate = await _showTokenInputDialog();
    if (candidate == null || !mounted) return;

    final currentToken = _token;
    if (currentToken != null) {
      final confirmed = await _showReplacementConfirmation(
        title: '更换身份令牌？',
        detail:
            '更换后，这台设备会改用另一份云端备份。当前令牌下的备份不会被删除，本地角色也不会改变。想再次打开原来的备份，需要保留当前令牌。',
      );
      if (!confirmed || !mounted) return;
    }

    await _applyToken(candidate);
  }

  Future<void> _generateToken() async {
    if (_busy) return;
    if (_token != null) {
      final confirmed = await _showReplacementConfirmation(
        title: '生成新的身份令牌？',
        detail: '生成后，这台设备会改用一份新的云端备份。原来的备份不会被删除，本地角色也不会改变。应用不会把旧备份搬到新令牌下。',
      );
      if (!confirmed || !mounted) return;
    }

    final newToken = TokenManager.generateToken();
    final saved = await _applyToken(newToken);
    if (saved && mounted) {
      await _showNewTokenDialog(newToken);
    }
  }

  Future<String?> _showTokenInputDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => _ExistingTokenDialog(currentToken: _token),
    );
  }

  Future<bool> _showReplacementConfirmation({
    required String title,
    required String detail,
  }) async {
    var acknowledged = false;
    final currentToken = _token;
    if (currentToken == null) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              icon: Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(detail),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      key: const Key('copy-token-before-replacement'),
                      onPressed: () => _copyToken(currentToken),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('复制当前令牌'),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      key: const Key('confirm-current-token-saved'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('我已保存当前令牌'),
                      value: acknowledged,
                      onChanged: (value) {
                        setDialogState(() => acknowledged = value ?? false);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  key: const Key('confirm-token-replacement'),
                  onPressed: acknowledged
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: const Text('确认更换'),
                ),
              ],
            );
          },
        );
      },
    );
    return result ?? false;
  }

  Future<void> _showNewTokenDialog(String token) async {
    var saved = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
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
                      _TokenText(token: token),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('copy-new-token'),
                        onPressed: () => _copyToken(token),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('复制令牌'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '应用无法帮你找回令牌，请保存到可信的位置。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      CheckboxListTile(
                        key: const Key('confirm-new-token-saved'),
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
                    key: const Key('close-new-token-dialog'),
                    onPressed: saved
                        ? () => Navigator.pop(dialogContext)
                        : null,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('身份令牌')),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(label: '正在读取身份令牌');
    }
    if (_loadFailed) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: '暂时无法读取令牌',
        message: '请重新尝试。',
        action: FilledButton.icon(
          onPressed: _loadToken,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppPageHeader(
                  icon: Icons.vpn_key_outlined,
                  title: '身份令牌',
                  subtitle: '在不同设备上使用同一份云端备份。',
                ),
                const SizedBox(height: 18),
                const AppSectionTitle(
                  title: '使用前先了解',
                  icon: Icons.info_outline,
                ),
                const AppPanel(
                  child: Column(
                    children: [
                      _InfoItem(
                        icon: Icons.devices_outlined,
                        title: '令牌有什么用',
                        text: '另一台设备填入同一令牌，就能看到同一份云端备份。',
                      ),
                      SizedBox(height: 16),
                      _InfoItem(
                        icon: Icons.shield_outlined,
                        title: '请妥善保管',
                        text: '应用没有账号和找回功能。令牌丢失后无法找回，也不要把它交给不信任的人。',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AppSectionTitle(
                  title: _token == null ? '设置身份令牌' : '当前令牌',
                  icon: Icons.key_outlined,
                ),
                if (_token == null)
                  _NoTokenPanel(
                    busy: _busy,
                    onGenerate: _generateToken,
                    onUseExisting: _useExistingToken,
                  )
                else
                  _CurrentTokenPanel(
                    token: _token!,
                    busy: _busy,
                    onCopy: () => _copyToken(_token!),
                  ),
                if (_token != null) ...[
                  const SizedBox(height: 18),
                  const AppSectionTitle(
                    title: '更换令牌',
                    subtitle: '切换到已有令牌，或生成一个全新的令牌。',
                    icon: Icons.swap_horiz_rounded,
                  ),
                  _ChangeTokenPanel(
                    busy: _busy,
                    onUseExisting: _useExistingToken,
                    onGenerate: _generateToken,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExistingTokenDialog extends StatefulWidget {
  final String? currentToken;

  const _ExistingTokenDialog({required this.currentToken});

  @override
  State<_ExistingTokenDialog> createState() => _ExistingTokenDialogState();
}

class _ExistingTokenDialogState extends State<_ExistingTokenDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final input = _controller.text.trim();
    String? error;
    if (input.isEmpty || !_uuidV4RegExp.hasMatch(input)) {
      error = '这个令牌格式不对，请检查是否复制完整。';
    } else if (input.toLowerCase() == widget.currentToken?.toLowerCase()) {
      error = '这就是当前正在使用的令牌。';
    }

    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    Navigator.pop(context, input);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('使用已有令牌'),
      content: SingleChildScrollView(
        child: TextField(
          key: const Key('existing-token-field'),
          controller: _controller,
          autofocus: true,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: '身份令牌',
            helperText: '从另一台设备复制完整令牌并粘贴到这里。',
            errorText: _errorText,
          ),
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) {
            if (_errorText != null) {
              setState(() => _errorText = null);
            }
          },
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('继续')),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoItem({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TokenText extends StatelessWidget {
  final String token;

  const _TokenText({required this.token});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        token,
        key: const Key('current-token-text'),
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', height: 1.45),
      ),
    );
  }
}

class _CurrentTokenPanel extends StatelessWidget {
  final String token;
  final bool busy;
  final VoidCallback onCopy;

  const _CurrentTokenPanel({
    required this.token,
    required this.busy,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TokenText(token: token),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('copy-current-token'),
            onPressed: busy ? null : onCopy,
            icon: const Icon(Icons.copy_outlined),
            label: const Text('复制令牌'),
          ),
        ],
      ),
    );
  }
}

class _NoTokenPanel extends StatelessWidget {
  final bool busy;
  final VoidCallback onGenerate;
  final VoidCallback onUseExisting;

  const _NoTokenPanel({
    required this.busy,
    required this.onGenerate,
    required this.onUseExisting,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '这台设备还没有身份令牌。',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '第一次使用可以生成一个；已有令牌则直接填入。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('generate-token'),
            onPressed: busy ? null : onGenerate,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('生成身份令牌'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('use-existing-token'),
            onPressed: busy ? null : onUseExisting,
            icon: const Icon(Icons.input_outlined),
            label: const Text('使用已有令牌'),
          ),
        ],
      ),
    );
  }
}

class _ChangeTokenPanel extends StatelessWidget {
  final bool busy;
  final VoidCallback onUseExisting;
  final VoidCallback onGenerate;

  const _ChangeTokenPanel({
    required this.busy,
    required this.onUseExisting,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useExistingButton = OutlinedButton.icon(
            key: const Key('use-existing-token'),
            onPressed: busy ? null : onUseExisting,
            icon: const Icon(Icons.input_outlined),
            label: const Text('使用已有令牌'),
          );
          final generateButton = OutlinedButton.icon(
            key: const Key('generate-token'),
            onPressed: busy ? null : onGenerate,
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error),
            ),
            icon: const Icon(Icons.autorenew_rounded),
            label: const Text('生成新令牌'),
          );

          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                useExistingButton,
                const SizedBox(height: 8),
                generateButton,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: useExistingButton),
              const SizedBox(width: 8),
              Expanded(child: generateButton),
            ],
          );
        },
      ),
    );
  }
}
