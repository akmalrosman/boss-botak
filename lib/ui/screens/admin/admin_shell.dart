import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app.dart';
import '../../../config/features.dart';
import '../../../config/shop_config.dart';
import '../../../core/theme.dart';
import '../../../state/catalog_controller.dart';
import '../../../state/finance_controller.dart';
import '../../../state/orders_controller.dart';
import '../../../state/session_controller.dart';
import '../../widgets/adaptive_nav.dart';
import '../../widgets/common.dart';
import '../customer/shop_screen.dart';
import '../shared/profile_screen.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'inventory_screen.dart';
import 'manage_orders_screen.dart';

/// Tab positions that other screens jump to (always present).
class AdminTabs {
  AdminTabs._();
  static const dashboard = 0;
  static const orders = 1;
  static const inventory = 2;
}

class _AdminTab {
  const _AdminTab(this.icon, this.selectedIcon, this.label, this.page);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;
}

/// Owner experience: Dashboard - Orders - Inventory (+ optional Expenses and
/// Customers, see [Features]), plus a navigation drawer.
List<_AdminTab> _tabs() => [
      const _AdminTab(Icons.space_dashboard_outlined, Icons.space_dashboard, 'Dashboard',
          DashboardScreen()),
      const _AdminTab(Icons.receipt_long_outlined, Icons.receipt_long, 'Orders',
          ManageOrdersScreen()),
      const _AdminTab(Icons.inventory_2_outlined, Icons.inventory_2, 'Inventory',
          InventoryScreen()),
      if (Features.expenses)
        const _AdminTab(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet,
            'Expenses', ExpensesScreen()),
      if (Features.customers)
        const _AdminTab(Icons.people_outline, Icons.people, 'Customers', CustomersScreen()),
    ];

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _nav = ShellNavigator();
  bool _lowStockAlertShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    final userId = context.read<SessionController>().user!.id;
    final catalog = context.read<CatalogController>();
    await Future.wait([
      catalog.load(includeInactive: true),
      context.read<OrdersController>().load(userId),
      if (Features.expenses || Features.customers) context.read<FinanceController>().load(),
    ]);
    if (!mounted || _lowStockAlertShown) return;
    // Low-stock notification on start-up.
    final low = catalog.lowStock;
    if (low.isNotEmpty) {
      _lowStockAlertShown = true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        persist: false,
        content: Text(low.length == 1
            ? '${low.first.name} is running low (${low.first.stock} left)'
            : '${low.length} products are running low on stock'),
        action: SnackBarAction(label: 'View', onPressed: () => _nav.go(AdminTabs.inventory)),
      ));
    }
  }

  @override
  void dispose() {
    _nav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toAction = context.select<OrdersController, int>((o) => o.needsActionCount);
    final lowStock = context.select<CatalogController, int>((c) => c.lowStock.length);
    final tabs = _tabs();

    return ChangeNotifierProvider.value(
      value: _nav,
      child: ListenableBuilder(
        listenable: _nav,
        builder: (context, _) => AdaptiveNavScaffold(
          index: _nav.index,
          onSelect: _nav.go,
          items: [
            for (final (i, t) in tabs.indexed)
              NavItem(
                icon: t.icon,
                selectedIcon: t.selectedIcon,
                label: t.label,
                badge: i == AdminTabs.orders
                    ? toAction
                    : i == AdminTabs.inventory
                        ? lowStock
                        : 0,
              ),
          ],
          pages: [for (final t in tabs) t.page],
        ),
      ),
    );
  }
}

/// Opens the "record a sale" flow (owner picks products for a customer).
void openNewSale(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShopScreen(saleMode: true)));
}

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final nav = context.read<ShellNavigator>();
    final theme = Theme.of(context);

    void go(int i) {
      Navigator.pop(context);
      nav.go(i);
    }

    return NavigationDrawer(
      selectedIndex: nav.index,
      onDestinationSelected: go,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BrandColors.leafGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            const BrandMark(size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ShopConfig.name,
                      style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                  Text(user?.fullName ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(color: BrandColors.sunYellow)),
                ],
              ),
            ),
          ]),
        ),
        for (final t in _tabs())
          NavigationDrawerDestination(icon: Icon(t.icon), label: Text(t.label)),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 28), child: Divider()),
        if (Features.recordSale)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 28),
            leading: const Icon(Icons.add_shopping_cart),
            title: const Text('Record a sale'),
            subtitle: const Text('WhatsApp or walk-in order'),
            onTap: () {
              Navigator.pop(context);
              openNewSale(context);
            },
          ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          leading: const Icon(Icons.manage_accounts_outlined),
          title: const Text('Profile & settings'),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProfileScreen(pushed: true)));
          },
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 28),
          leading: Icon(Icons.logout, color: theme.colorScheme.error),
          title: Text('Sign out', style: TextStyle(color: theme.colorScheme.error)),
          onTap: () async {
            // Keep the drawer open while asking: closing it first unmounts this
            // context, so the sign-out after the dialog would be skipped.
            final ok = await confirmDialog(context,
                title: 'Sign out?', message: 'You will need to sign in again.', confirmLabel: 'Sign out');
            if (ok && context.mounted) await signOutAndReset(context);
          },
        ),
      ],
    );
  }
}
