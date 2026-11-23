import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/backend.dart';
import 'data/local_cache.dart';
import 'services/contact_service.dart';
import 'services/invoice_service.dart';
import 'services/location_service.dart';
import 'state/cart_controller.dart';
import 'state/catalog_controller.dart';
import 'state/finance_controller.dart';
import 'state/orders_controller.dart';
import 'state/session_controller.dart';
import 'state/settings_controller.dart';
import 'ui/screens/admin/admin_shell.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/customer/customer_shell.dart';

class BossBotakApp extends StatelessWidget {
  const BossBotakApp({super.key, required this.backend, required this.cache});

  final Backend backend;
  final LocalCache cache;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Backend>.value(value: backend),
        Provider<LocalCache>.value(value: cache),
        Provider(create: (_) => LocationService()),
        Provider(create: (_) => const ContactService()),
        Provider(create: (_) => const InvoiceService()),
        ChangeNotifierProvider(create: (_) => SettingsController(cache)),
        ChangeNotifierProvider(create: (_) => SessionController(backend)..restore()),
        ChangeNotifierProvider(create: (_) => CatalogController(backend, cache)),
        ChangeNotifierProvider(create: (_) => CartController(cache)),
        ChangeNotifierProvider(create: (_) => OrdersController(backend, cache)),
        ChangeNotifierProvider(create: (_) => FinanceController(backend)),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Boss Botak',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          home: const AuthGate(),
        ),
      ),
    );
  }
}

/// Routes to the right experience based on the signed-in user's role.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.user;
    context.read<CartController>().bindUser(user?.id);

    final Widget child = switch (session.status) {
      AuthStatus.loading => const _Splash(),
      AuthStatus.signedOut => const LoginScreen(),
      AuthStatus.signedIn => user!.isAdmin
          ? AdminShell(key: ValueKey('admin-${user.id}'))
          : CustomerShell(key: ValueKey('customer-${user.id}')),
    };
    return AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: child);
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: BrandColors.leafGreen,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 96),
            SizedBox(height: 24),
            CircularProgressIndicator(color: BrandColors.sunYellow),
          ],
        ),
      ),
    );
  }
}

/// Simple logo: yellow badge with "BB" monogram.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Boss Botak logo',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: BrandColors.sunYellow,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: size / 24),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
        ),
        alignment: Alignment.center,
        child: ExcludeSemantics(
          child: Text(
            'BB',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: size * 0.38,
              fontWeight: FontWeight.w900,
              color: BrandColors.leafGreen,
              letterSpacing: -1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Signs out and clears every user-specific controller.
Future<void> signOutAndReset(BuildContext context) async {
  final session = context.read<SessionController>();
  final orders = context.read<OrdersController>();
  final finance = context.read<FinanceController>();
  final catalog = context.read<CatalogController>();
  // Close any pushed screens (e.g. Profile opened from the drawer).
  Navigator.of(context).popUntil((r) => r.isFirst);
  await session.signOut();
  orders.clear();
  finance.clear();
  catalog.clear();
}
