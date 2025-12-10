import 'package:flutter/material.dart';
// 引入主屏幕
import 'pages/main_screen.dart';

void main() {
  runApp(const DnDToolkitApp());
}

class DnDToolkitApp extends StatelessWidget {
  const DnDToolkitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DnD Toolkit',
      theme: ThemeData(
        // 开启 Material 3 风格
        useMaterial3: true,
        // 设置主题种子颜色
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // 指定首页
      home: const MainScreen(),
    );
  }
}