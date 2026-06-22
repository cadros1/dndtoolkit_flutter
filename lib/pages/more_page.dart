import 'package:dndtoolkit_flutter/services/update_service.dart';
import 'package:flutter/material.dart';

import '../widgets/app_ui.dart';
import 'about_page.dart';
import 'settings_page.dart';
import 'sync/sync_center_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            AppPageHeader(
              icon: Icons.more_horiz,
              title: "更多",
              subtitle: "同步、偏好设置、更新与项目说明。",
              actions: [
                if (UpdateService.instance.hasNewVersion)
                  Chip(
                    avatar: Icon(
                      Icons.system_update_alt,
                      size: 18,
                      color: cs.primary,
                    ),
                    label: const Text("发现新版本"),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const AppSectionTitle(title: "数据", icon: Icons.cloud_sync_outlined),
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
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
            const SizedBox(height: 12),
            AppSettingsTile(
              icon: Icons.info_outline,
              title: "关于本应用",
              subtitle: "版本、更新、项目主页和许可协议",
              trailing: Badge(
                isLabelVisible: UpdateService.instance.hasNewVersion,
                smallSize: 8,
                child: const Icon(Icons.chevron_right),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
