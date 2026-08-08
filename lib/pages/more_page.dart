import 'package:dndtoolkit_flutter/services/update_service.dart';
import 'package:flutter/material.dart';

import '../widgets/app_ui.dart';
import 'about_page.dart';
import 'settings_page.dart';
import 'sync/sync_center_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  void _openAboutPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutPage()),
    );
  }

  Widget _buildUpdateBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final version = UpdateService.instance.latestVersion;
    return Material(
      color: cs.primaryContainer.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openAboutPage(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(Icons.system_update_alt, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      version.isEmpty ? "发现新版本" : "发现新版本 $version",
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      "点击查看更新详情",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UpdateService.instance,
      builder: (context, child) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (UpdateService.instance.hasNewVersion) ...[
                _buildUpdateBanner(context),
                const SizedBox(height: 18),
              ],
              const AppSectionTitle(
                title: "数据",
                icon: Icons.cloud_sync_outlined,
              ),
              AppSettingsTile(
                icon: Icons.cloud_sync_outlined,
                title: "云端同步中心",
                subtitle: "通过 Supabase 云端存取角色数据",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SyncCenterPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              const AppSectionTitle(title: "应用", icon: Icons.tune_outlined),
              AppSettingsTile(
                icon: Icons.settings_outlined,
                title: "设置",
                subtitle: "管理身份令牌和云端访问凭据",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              AppSettingsTile(
                icon: Icons.info_outline,
                title: "关于本应用",
                subtitle: "版本、更新、项目主页和许可协议",
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openAboutPage(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
