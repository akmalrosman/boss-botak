import 'package:flutter/material.dart';

class NavItem {
  const NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
}

/// Lets nested screens switch the shell's tab (e.g. "Go to cart").
class ShellNavigator extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  void go(int index) {
    if (index == _index) return;
    _index = index;
    notifyListeners();
  }
}

/// Bottom NavigationBar on phones (portrait); NavigationRail on wider
/// screens such as landscape phones and tablets.
class AdaptiveNavScaffold extends StatelessWidget {
  const AdaptiveNavScaffold({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
    required this.pages,
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onSelect;
  final List<Widget> pages;

  Widget _icon(NavItem item, bool selected) {
    final icon = Icon(selected ? item.selectedIcon : item.icon);
    if (item.badge <= 0) return icon;
    return Badge.count(count: item.badge, child: icon);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final body = IndexedStack(
      index: index,
      children: [
        for (var i = 0; i < pages.length; i++)
          // Hide inactive tabs from screen readers & focus traversal.
          ExcludeFocus(
            excluding: i != index,
            child: ExcludeSemantics(excluding: i != index, child: pages[i]),
          ),
      ],
    );

    if (width >= 640) {
      return Scaffold(
        body: SafeArea(
          right: false,
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: onSelect,
                extended: width >= 1100,
                labelType: width >= 1100 ? null : NavigationRailLabelType.all,
                destinations: [
                  for (final item in items)
                    NavigationRailDestination(
                      icon: _icon(item, false),
                      selectedIcon: _icon(item, true),
                      label: Text(item.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onSelect,
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: _icon(item, false),
              selectedIcon: _icon(item, true),
              label: item.label,
              tooltip: item.badge > 0 ? '${item.label}, ${item.badge} new' : item.label,
            ),
        ],
      ),
    );
  }
}
