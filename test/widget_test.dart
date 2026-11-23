import 'package:boss_botak/app.dart';
import 'package:boss_botak/config/features.dart';
import 'package:boss_botak/data/demo_backend.dart';
import 'package:boss_botak/data/local_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpApp(WidgetTester tester, {Size size = const Size(400, 860)}) async {
  SharedPreferences.setMockInitialValues({});
  final cache = LocalCache(await SharedPreferences.getInstance());
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(BossBotakApp(backend: DemoBackend(cache), cache: cache));
  await tester.pumpAndSettle();
}

/// Demo backend adds a small artificial delay - let it finish.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows sign-in screen with demo shortcuts', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Boss Botak'), findsWidgets);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Boss (owner)'), findsOneWidget);
  });

  testWidgets('validates the sign-in form', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('customer can browse and add a product to the cart', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Customer'));
    await _settle(tester);
    await _settle(tester);

    expect(find.text('Hi, Aisyah!'), findsOneWidget);
    expect(find.text('Otak-Otak Ikan Original'), findsOneWidget);

    await tester.tap(find.byTooltip('Add Otak-Otak Ikan Original to cart'));
    await tester.pump();
    expect(find.text('Added Otak-Otak Ikan Original to cart'), findsOneWidget);

    // Cart badge shows 1 item.
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart (1)'), findsOneWidget);
  });

  testWidgets('owner can sign out from the drawer', (tester) async {
    await _pumpApp(tester);
    await tester.ensureVisible(find.text('Boss (owner)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boss (owner)'));
    await _settle(tester);
    await _settle(tester);

    await tester.tap(find.byTooltip('Open navigation menu').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await _settle(tester);

    expect(find.text('Boss (owner)'), findsOneWidget); // back on the sign-in screen
    expect(find.text('Profit & loss'), findsNothing);
  });

  testWidgets('owner can sign out from Profile & settings', (tester) async {
    await _pumpApp(tester);
    await tester.ensureVisible(find.text('Boss (owner)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boss (owner)'));
    await _settle(tester);
    await _settle(tester);

    await tester.tap(find.byTooltip('Open navigation menu').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile & settings'));
    await tester.pumpAndSettle();
    // Let the start-up low-stock SnackBar disappear first (it overlaps the bottom).
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await _settle(tester);

    expect(find.text('Boss (owner)'), findsOneWidget);
  });

  testWidgets('owner sees the financial dashboard (landscape uses rail)', (tester) async {
    await _pumpApp(tester, size: const Size(1000, 700));
    await tester.tap(find.text('Boss (owner)'));
    await _settle(tester);
    await _settle(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Profit & loss'), findsOneWidget);
    // Must not call it "net" profit while expenses are not being tracked.
    expect(find.text('Net profit'), Features.expenses ? findsWidgets : findsNothing);
    expect(find.text('Gross profit'), findsWidgets);
  });
}
