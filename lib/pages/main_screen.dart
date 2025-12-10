import 'package:flutter/material.dart';
import 'adventure_page.dart';
import 'character_list_page.dart';
import 'more_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 页面列表
  // 使用 getter 确保每次 build 时都能获取到正确的组件引用
  // 虽然对于无状态切换来说，直接放 List<Widget> 也可以，
  // 但这里 body 直接使用 _pages[_selectedIndex] 配合下方的 setState
  // 实现了“切换即销毁/重建”的效果，满足“每次进入读取文件”的需求。
  final List<Widget> _pages = [
    const CharacterListPage(),
    const AdventurePage(),
    const MorePage(), 
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DnD Toolkit'),
        // 使用 Material 3 的颜色方案
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      // 这里的关键：不使用 IndexedStack，直接切换 Widget
      // 这会导致旧页面 dispose，新页面 initState
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: '角色',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: '冒险',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: '更多',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: _onItemTapped,
      ),
    );
  }
}