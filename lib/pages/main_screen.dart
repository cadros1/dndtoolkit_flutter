import 'package:dndtoolkit_flutter/services/update_service.dart';
import 'package:flutter/material.dart';
import 'adventure_page.dart';
import 'character_list_page.dart';
import 'more_page.dart';

/// 移动端/桌面端响应式布局的宽度断点
const _kDesktopBreakpoint = 600.0;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // ---- 导航目标列表（移动端和桌面端共用） ----
  List<NavigationDestination> get _destinations => [
        const NavigationDestination(
          icon: Icon(Icons.people),
          label: '角色',
        ),
        const NavigationDestination(
          icon: Icon(Icons.map),
          label: '冒险',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: UpdateService.instance.hasNewVersion,
            smallSize: 8,
            child: const Icon(Icons.more_horiz),
          ),
          label: '更多',
        ),
      ];

  // ---- 移动端布局：AppBar + BottomNavigationBar ----
  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DnD Toolkit'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildPage(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: _destinations,
      ),
    );
  }

  // ---- 桌面端布局：NavigationRail 侧栏 + 内容区 ----
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          // 侧栏导航
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(
                    Icons.casino,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'DnD Toolkit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Badge(
                    isLabelVisible: UpdateService.instance.hasNewVersion,
                    smallSize: 8,
                    child: IconButton(
                      icon: const Icon(Icons.more_horiz),
                      tooltip: '更多',
                      onPressed: () => _onItemTapped(2),
                    ),
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.people_outlined),
                selectedIcon: Icon(Icons.people),
                label: Text('角色'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: Text('冒险'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.more_horiz),
                selectedIcon: Icon(Icons.more_horiz),
                label: Text('更多'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // 右侧内容区
          Expanded(
            child: Column(
              children: [
                // 简洁顶栏
                Material(
                  elevation: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.inversePrimary,
                    child: Text(
                      'DnD Toolkit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                Expanded(child: _buildPage(_selectedIndex)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _kDesktopBreakpoint) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }
}

/// 页面切换：不使用 IndexedStack，直接切换 Widget
/// 这会导致旧页面 dispose，新页面 initState，满足"每次进入重新读取数据"的需求
Widget _buildPage(int index) {
  return switch (index) {
    0 => const CharacterListPage(),
    1 => const AdventurePage(),
    2 => const MorePage(),
    _ => const CharacterListPage(),
  };
}
