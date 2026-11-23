import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/orders_controller.dart';
import '../../widgets/adaptive_nav.dart';
import '../../widgets/common.dart';
import '../../widgets/order_card.dart';
import '../shared/order_detail_screen.dart';

/// Screen 5 - Customer's order history and tracking.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  bool _showActive = true;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<OrdersController>();
    final list = ctrl.orders.where((o) => o.status.isOpen == _showActive).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: Column(
        children: [
          OfflineBanner(visible: ctrl.offline, onRetry: ctrl.refresh),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Active'), icon: Icon(Icons.timelapse)),
                  ButtonSegment(value: false, label: Text('History'), icon: Icon(Icons.history)),
                ],
                selected: {_showActive},
                onSelectionChanged: (s) => setState(() => _showActive = s.first),
              ),
            ),
          ),
          if (ctrl.loading) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.refresh,
              child: list.isEmpty
                  ? ListView(children: [
                      SizedBox(
                        height: 420,
                        child: EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: _showActive ? 'No active orders' : 'No past orders yet',
                          message: ctrl.error ??
                              'Orders you place will appear here so you can track them.',
                          action: _showActive
                              ? FilledButton.icon(
                                  onPressed: () => context.read<ShellNavigator>().go(0),
                                  icon: const Icon(Icons.storefront_outlined),
                                  label: const Text('Start shopping'),
                                )
                              : null,
                        ),
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => ContentWidth(
                        child: OrderCard(
                          order: list[i],
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(orderId: list[i].id),
                          )),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
