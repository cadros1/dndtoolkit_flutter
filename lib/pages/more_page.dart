import 'package:dndtoolkit_flutter/services/update_service.dart';
import 'package:flutter/material.dart';
import 'about_page.dart';
import 'settings_page.dart';
import 'sync/sync_center_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          // 云端同步入口
          ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text("云端同步中心"),
            subtitle: const Text("通过 Supabase 云端存取角色数据"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SyncCenterPage()),
              );
            },
          ),

          const Divider(),

          // 设置页入口
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("设置"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),

          // 关于页入口
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("关于本应用"),
            trailing: Badge(
                  isLabelVisible: UpdateService.instance.hasNewVersion,
                  smallSize: 8,
                  child: const Icon(Icons.arrow_forward_ios, size: 16),
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
    );
  }
}