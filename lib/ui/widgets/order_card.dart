import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/order.dart';
import 'common.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.showCustomer = false,
  });

  final Order order;
  final VoidCallback onTap;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final summary = order.items.map((i) => '${i.productName} x${i.quantity}').join(', ');

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      showCustomer ? order.customerName : order.code,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(rm(order.total),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.primary)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (showCustomer) order.code,
                  formatDateTime(order.createdAt),
                  if (showCustomer && order.source != OrderSource.app) 'via ${order.source.label}',
                ].join(' · '),
                style: muted,
              ),
              const SizedBox(height: 8),
              Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusChip(order.status),
                  PaymentChip(status: order.paymentStatus),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(order.fulfilment.icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        order.scheduledFor == null
                            ? order.fulfilment.label
                            : '${order.fulfilment.label} · ${formatDate(order.scheduledFor!)}',
                        style: muted,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
