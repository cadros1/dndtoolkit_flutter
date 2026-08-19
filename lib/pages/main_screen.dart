import 'package:dndtoolkit_flutter/services/update_service.dart';
import 'package:flutter/material.dart';
import '../widgets/app_ui.dart';
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
  String? _adventureEntryCharacterId;

  static const _pages = [
    _MainDestination(Icons.groups_2_outlined, Icons.groups_2),
    _MainDestination(Icons.explore_outlined, Icons.explore),
    _MainDestination(Icons.more_horiz, Icons.more_horiz),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index != 1) {
        _adventureEntryCharacterId = null;
      }
    });
  }

  void _startAdventure(String characterId) {
    setState(() {
      _adventureEntryCharacterId = characterId;
      _selectedIndex = 1;
    });
  }

  Widget _buildPage(int index) {
    return switch (index) {
      0 => CharacterListPage(onStartAdventure: _startAdventure),
      1 => AdventurePage(initialCharacterId: _adventureEntryCharacterId),
      2 => const MorePage(),
      _ => CharacterListPage(onStartAdventure: _startAdventure),
    };
  }

  // ---- 导航目标列表（移动端和桌面端共用） ----
  List<NavigationDestination> get _destinations => [
    NavigationDestination(
      icon: Icon(_pages[0].icon),
      selectedIcon: Icon(_pages[0].selectedIcon),
      label: '角色',
    ),
    NavigationDestination(
      icon: Icon(_pages[1].icon),
      selectedIcon: Icon(_pages[1].selectedIcon),
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

  // ---- 移动端布局：页面内容 + 底部导航 ----
  Widget _buildMobileLayout() {
    return Scaffold(
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Row(
        children: [
          // 侧栏导航
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(right: BorderSide(color: cs.outlineVariant)),
            ),
            child: NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              labelType: NavigationRailLabelType.all,
              minWidth: 96,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 22),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.casino_outlined,
                        size: 28,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'DnD\nToolkit',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        height: 1.1,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
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
                      child: IconButton.filledTonal(
                        icon: const Icon(Icons.more_horiz),
                        tooltip: '更多',
                        onPressed: () => _onItemTapped(2),
                      ),
                    ),
                  ),
                ),
              ),
              destinations: [
                NavigationRailDestination(
                  icon: Icon(_pages[0].icon),
                  selectedIcon: Icon(_pages[0].selectedIcon),
                  label: const Text('角色'),
                ),
                NavigationRailDestination(
                  icon: Icon(_pages[1].icon),
                  selectedIcon: Icon(_pages[1].selectedIcon),
                  label: const Text('冒险'),
                ),
                NavigationRailDestination(
                  icon: Badge(
                    isLabelVisible: UpdateService.instance.hasNewVersion,
                    smallSize: 8,
                    child: Icon(_pages[2].icon),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: UpdateService.instance.hasNewVersion,
                    smallSize: 8,
                    child: Icon(_pages[2].selectedIcon),
                  ),
                  label: const Text('更多'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildPage(_selectedIndex)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kAppDesktopBreakpoint) {
          return _buildDesktopLayout();
        }
        return _buildMobileLayout();
      },
    );
  }
}

class _MainDestination {
  final IconData icon;
  final IconData selectedIcon;

  const _MainDestination(this.icon, this.selectedIcon);
}
