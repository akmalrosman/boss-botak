import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/analytics.dart';
import '../../../core/format.dart';
import '../../../services/contact_service.dart';
import '../../../state/finance_controller.dart';
import '../../../state/orders_controller.dart';
import '../../widgets/common.dart';
import 'admin_shell.dart';

/// Screen 12 - Customer database built from registered users and from every
/// sale (including WhatsApp / walk-in customers).
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _query = '';

  void _open(CustomerSummary c) {
    final contact = context.read<ContactService>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  CircleAvatar(radius: 28, child: Text(initials(c.name))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: theme.textTheme.titleLarge),
                      Text(c.phone.isEmpty ? 'No phone' : c.phone),
                      if (c.email != null && c.email!.isNotEmpty) Text(c.email!),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                Wrap(spacing: 24, runSpacing: 8, children: [
                  _stat(ctx, 'Orders', '${c.orderCount}'),
                  _stat(ctx, 'Total spent', rm(c.totalSpent)),
                  _stat(ctx, 'Last order', c.lastOrder == null ? '-' : formatDate(c.lastOrder!)),
                ]),
                if (c.address.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text(c.address)),
                  ]),
                ],
                const SizedBox(height: 20),
                if (c.phone.isNotEmpty)
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => runWithFeedback(ctx, () => contact.call(c.phone)),
                        icon: const Icon(Icons.call_outlined),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => runWithFeedback(
                          ctx,
                          () => contact.whatsapp(c.phone,
                              message: 'Hi ${c.name}! Boss Botak dah buka tempahan '
                                  'otak-otak & pepes untuk open house. Nak order? '
                                  'Boleh terus order dalam app Boss Botak :)'),
                        ),
                        icon: const Icon(Icons.campaign_outlined),
                        label: const Text('Send promo'),
                      ),
                    ),
                  ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrdersController>().orders;
    final finance = context.watch<FinanceController>();
    final all = Analytics.customers(orders, finance.customerProfiles);
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty
        ? all
        : all.where((c) => c.name.toLowerCase().contains(q) || c.phone.contains(q)).toList();
    final repeat = all.where((c) => c.orderCount > 1).length;
    final registered = all.where((c) => c.isRegistered).length;
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(title: const Text('Customers')),
      body: RefreshIndicator(
        onRefresh: finance.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(spacing: 32, runSpacing: 12, children: [
                        _stat(context, 'Customers', '${all.length}'),
                        _stat(context, 'Repeat buyers', '$repeat'),
                        _stat(context, 'Using the app', '$registered'),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SearchBar(
                    hintText: 'Search customers',
                    leading: const Icon(Icons.search),
                    elevation: const WidgetStatePropertyAll(0),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SectionTitle('Top customers by spending'),
                  if (list.isEmpty)
                    const SizedBox(
                      height: 260,
                      child: EmptyState(icon: Icons.people_outline, title: 'No customers found'),
                    ),
                  for (final (i, c) in list.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          onTap: () => _open(c),
                          leading: CircleAvatar(
                            backgroundColor: i < 3 && q.isEmpty
                                ? theme.colorScheme.tertiaryContainer
                                : theme.colorScheme.secondaryContainer,
                            child: Text(initials(c.name)),
                          ),
                          title: Row(children: [
                            Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                            if (c.isRegistered) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Registered app user',
                                child: Icon(Icons.phone_android,
                                    size: 16, color: theme.colorScheme.primary),
                              ),
                            ],
                          ]),
                          subtitle: Text(
                              '${c.orderCount} order${c.orderCount == 1 ? '' : 's'}'
                              '${c.lastOrder != null ? ' · last ${formatDate(c.lastOrder!)}' : ''}'),
                          trailing: Text(rm(c.totalSpent), style: theme.textTheme.titleSmall),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
