import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/cart_controller.dart';
import '../../../state/catalog_controller.dart';
import '../../../state/orders_controller.dart';
import '../../../state/session_controller.dart';
import '../../widgets/adaptive_nav.dart';
import '../shared/profile_screen.dart';
import 'cart_screen.dart';
import 'my_orders_screen.dart';
import 'shop_screen.dart';

/// Customer experience: Shop - Cart - Orders - Profile.
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  final _nav = ShellNavigator();
  late final CatalogController _catalog = context.read<CatalogController>();

  @override
  void initState() {
    super.initState();
    _catalog.addListener(_syncCart);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _catalog.load();
      context.read<OrdersController>().load(context.read<SessionController>().user!.id);
    });
  }

  /// Keep cart prices and stock limits in line with the latest catalogue.
  void _syncCart() {
    if (!_catalog.loading && !_catalog.offline && _catalog.products.isNotEmpty) {
      context.read<CartController>().syncWith(_catalog.products);
    }
  }

  @override
  void dispose() {
    _catalog.removeListener(_syncCart);
    _nav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<CartController, int>((c) => c.count);
    final openOrders = context.select<OrdersController, int>((o) => o.openCount);

    return ChangeNotifierProvider.value(
      value: _nav,
      child: ListenableBuilder(
        listenable: _nav,
        builder: (context, _) => AdaptiveNavScaffold(
          index: _nav.index,
          onSelect: _nav.go,
          items: [
            const NavItem(
                icon: Icons.storefront_outlined, selectedIcon: Icons.storefront, label: 'Shop'),
            NavItem(
                icon: Icons.shopping_cart_outlined,
                selectedIcon: Icons.shopping_cart,
                label: 'Cart',
                badge: cartCount),
            NavItem(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long,
                label: 'Orders',
                badge: openOrders),
            const NavItem(
                icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
          ],
          pages: const [
            ShopScreen(),
            CartScreen(),
            MyOrdersScreen(),
            ProfileScreen(),
          ],
        ),
      ),
    );
  }
}
