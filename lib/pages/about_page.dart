import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../services/snack_bar_service.dart';
import '../widgets/app_ui.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = "";
  String _buildNumber = "";
  bool _isChecking = false;

  // GitHub 仓库地址
  final String _repoUrl = "https://github.com/cadros1/dndtoolkit_flutter";

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  /// 检查更新
  Future<void> _checkUpdate() async {
    // 如果 Service 已经检测到有更新，直接弹窗，无需再次请求网络
    if (UpdateService.instance.hasNewVersion) {
      _showUpdateDialog(
        UpdateService.instance.latestVersion,
        UpdateService.instance.releaseNotes,
        UpdateService.instance.downloadUrl,
      );
      return;
    }

    setState(() => _isChecking = true);

    try {
      // 强制请求网络
      final hasUpdate = await UpdateService.instance.checkUpdate(silent: false);

      if (!mounted) return;

      if (hasUpdate) {
        _showUpdateDialog(
          UpdateService.instance.latestVersion,
          UpdateService.instance.releaseNotes,
          UpdateService.instance.downloadUrl,
        );
      } else {
        SnackBarService.showInfo("当前已是最新版本");
      }
    } catch (e) {
      if (mounted) {
        SnackBarService.showError("检查更新失败: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  /// 显示发现更新对话框
  void _showUpdateDialog(String version, String desc, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("发现新版本 $version"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "更新内容：",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(desc),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("稍后"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl(url);
            },
            child: const Text("前往下载"),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("无法打开浏览器")));
      }
    }
  }

  /// 显示自定义许可协议页
  void _showLicenseAgreement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text("许可协议")),
          // [修改] 使用 FutureBuilder 异步加载资源文件
          body: FutureBuilder<String>(
            future: DefaultAssetBundle.of(context).loadString('assets/LICENSE'),
            builder: (context, snapshot) {
              // 1. 正在加载
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // 2. 加载出错
              if (snapshot.hasError) {
                return Center(child: Text("无法加载协议文件: ${snapshot.error}"));
              }

              // 3. 加载成功
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  snapshot.data ?? "协议内容为空",
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ), // 稍微调大行高，阅读更舒适
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("关于")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          AppPanel(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                final info = Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.casino_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "DnD Toolkit",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Designed for D&D 5E Players",
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "版本: v$_version (Build $_buildNumber)",
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final updateChip = UpdateService.instance.hasNewVersion
                    ? const Chip(
                        avatar: Icon(Icons.system_update_alt, size: 18),
                        label: Text("可更新"),
                      )
                    : null;

                if (updateChip == null) return info;
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [info, const SizedBox(height: 12), updateChip],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 12),
                    updateChip,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // --- 功能区 ---
          const AppSectionTitle(title: "应用", icon: Icons.apps_outlined),
          _buildListTile(
            icon: Icons.system_update,
            title: "检查更新",
            subtitle: "访问 GitHub Release",
            trailing: _isChecking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Badge(
                    isLabelVisible: UpdateService.instance.hasNewVersion,
                    child: const Icon(Icons.arrow_forward_ios, size: 16),
                  ),
            onTap: _isChecking ? null : _checkUpdate,
          ),

          const SizedBox(height: 12),

          _buildListTile(
            icon: Icons.code,
            title: "项目主页",
            subtitle: _repoUrl,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _launchUrl(_repoUrl),
          ),

          const SizedBox(height: 18),

          // --- 法律信息区 ---
          const AppSectionTitle(title: "法律信息", icon: Icons.gavel_outlined),

          // 1. 许可协议 (PolyForm)
          _buildListTile(
            icon: Icons.gavel,
            title: "许可协议",
            subtitle: "PolyForm Noncommercial 1.0.0",
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showLicenseAgreement,
          ),

          const SizedBox(height: 12),

          // 2. 第三方开源声明 (Flutter 自带页面)
          _buildListTile(
            icon: Icons.article,
            title: "第三方开源声明",
            subtitle: "Open Source Licenses",
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Flutter 自带的神奇函数，自动生成开源协议页
              showLicensePage(
                context: context,
                applicationName: "DnD Toolkit",
                applicationVersion: "v$_version",
                applicationIcon: const FlutterLogo(size: 48),
                applicationLegalese:
                    "Copyright © 2025 DnD Toolkit Contributors",
              );
            },
          ),
        ],
      ),
    );
  }

  // 辅助方法：统一 ListTile 样式
  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback? onTap,
  }) {
    return AppSettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
