import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/features.dart';
import '../../../models/order.dart';
import '../../../state/orders_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/order_card.dart';
import '../shared/order_detail_screen.dart';
import 'admin_shell.dart';

enum _OrderFilter {
  pending('New'),
  verify('To verify'),
  active('In progress'),
  unpaid('Unpaid'),
  completed('Completed'),
  cancelled('Cancelled'),
  all('All');

  const _OrderFilter(this.label);
  final String label;

  bool matches(Order o) => switch (this) {
        pending => o.status == OrderStatus.pending,
        verify => o.awaitingVerification,
        active => o.status.isOpen && o.status != OrderStatus.pending,
        unpaid => o.canPay,
        completed => o.status == OrderStatus.completed,
        cancelled => o.status == OrderStatus.cancelled,
        all => true,
      };
}

/// Screen 9 - Owner's order management (all channels: app, WhatsApp, walk-in).
class ManageOrdersScreen extends StatefulWidget {
  const ManageOrdersScreen({super.key});

  @override
  State<ManageOrdersScreen> createState() => _ManageOrdersScreenState();
}

class _ManageOrdersScreenState extends State<ManageOrdersScreen> {
  _OrderFilter _filter = _OrderFilter.pending;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<OrdersController>();
    final q = _query.trim().toLowerCase();
    final list = ctrl.orders.where((o) {
      if (!_filter.matches(o)) return false;
      if (q.isEmpty) return true;
      return o.customerName.toLowerCase().contains(q) ||
          o.code.toLowerCase().contains(q) ||
          o.customerPhone.contains(q);
    }).toList();

    int count(_OrderFilter f) => ctrl.orders.where(f.matches).length;

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        title: const Text('Orders'),
        bottom: ctrl.loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
            : null,
      ),
      floatingActionButton: !Features.recordSale
          ? null
          : FloatingActionButton.extended(
            heroTag: 'fab-orders',
            onPressed: () => openNewSale(context),
            icon: const Icon(Icons.add),
            label: const Text('Record sale'),
          ),
      body: Column(
        children: [
          OfflineBanner(visible: ctrl.offline, onRetry: ctrl.refresh),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              hintText: 'Search name, phone or order no.',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              for (final f in _OrderFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('${f.label} (${count(f)})'),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.refresh,
              child: list.isEmpty
                  ? ListView(children: [
                      SizedBox(
                        height: 380,
                        child: EmptyState(
                          icon: Icons.inbox_outlined,
                          title: 'No ${_filter.label.toLowerCase()} orders',
                          message: ctrl.error ?? 'Pull down to refresh.',
                        ),
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => ContentWidth(
                        child: OrderCard(
                          order: list[i],
                          showCustomer: true,
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
