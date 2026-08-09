import 'package:flutter/material.dart';

import '../widgets/app_ui.dart';
import 'identity_token_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppPageHeader(
                    icon: Icons.settings_outlined,
                    title: '设置',
                    subtitle: '管理应用偏好和数据相关设置。',
                  ),
                  const SizedBox(height: 18),
                  const AppSectionTitle(
                    title: '云端备份',
                    icon: Icons.cloud_outlined,
                  ),
                  AppSettingsTile(
                    icon: Icons.vpn_key_outlined,
                    title: '身份令牌',
                    subtitle: '查看、复制或更换令牌',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => const IdentityTokenPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
