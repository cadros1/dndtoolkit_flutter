import 'package:flutter/material.dart';
import 'services/snack_bar_service.dart';
import 'services/update_service.dart';
import 'services/token_manager.dart';
import 'services/cloud_sync_service.dart';
import 'pages/main_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 预加载令牌并初始化 Supabase 客户端（如有令牌）
  final token = await TokenManager.instance.getToken();
  if (token != null && token.isNotEmpty) {
    // 预热 CloudSyncService，将 token 注入全局请求头
    try {
      await CloudSyncService.instance.client;
    } catch (_) {
      // 静默失败，云端功能将在用户访问时提示
    }
  }

  runApp(const DnDToolkitApp());
  UpdateService.instance.checkUpdate();
}

class DnDToolkitApp extends StatelessWidget {
  const DnDToolkitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DnD Toolkit',
      // 配置亮色主题 (Light Mode)
      theme: AppTheme.light(),

      // 配置暗色主题 (Dark Mode)
      darkTheme: AppTheme.dark(),

      // 设置主题模式跟随系统 (默认就是 system，写出来更清晰)
      // system: 跟随系统设置
      // light: 强制亮色
      // dark: 强制暗色
      themeMode: ThemeMode.system,
      scaffoldMessengerKey: SnackBarService.scaffoldMessengerKey,
      // 指定首页
      home: const MainScreen(),
    );
  }
}
