import 'package:flutter/material.dart';
import 'services/snack_bar_service.dart';
import 'services/update_service.dart';
import 'pages/main_screen.dart';

void main() {
  runApp(const DnDToolkitApp());
  UpdateService.instance.checkUpdate();
}

class DnDToolkitApp extends StatelessWidget {
  const DnDToolkitApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Colors.deepPurple;

    return MaterialApp(
      title: 'DnD Toolkit',
      // 配置亮色主题 (Light Mode)
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light, // 明确指定为亮色
        ),
      ),

      // 配置暗色主题 (Dark Mode)
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark, // 明确指定为暗色
        ),
      ),

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