import 'package:dndtoolkit_flutter/services/update_service.dart';
import 'package:flutter/material.dart';
import 'about_page.dart';
import 'sync/discovery_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("更多"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          // 示例：之前的 PDF 手册入口（可选）
          // ListTile(
          //   leading: const Icon(Icons.book),
          //   title: const Text("玩家手册 (PDF)"),
          //   trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => const PdfViewerPage(assetPath: 'assets/handbook.pdf'),
          //       ),
          //     );
          //   },
          // ),
          // const Divider(),

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
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text("PC 端同步"),
            subtitle: const Text("与 Windows 客户端互传角色"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DiscoveryPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}