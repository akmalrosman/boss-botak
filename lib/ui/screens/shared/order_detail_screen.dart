import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../models/order.dart';
import '../../../services/contact_service.dart';
import '../../../services/invoice_service.dart';
import '../../../state/catalog_controller.dart';
import '../../../state/orders_controller.dart';
import '../../../state/session_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/receipt_image.dart';
import '../payment/duitnow_payment_screen.dart';
import '../payment/fpx_payment_screen.dart';

/// Order details, tracking, digital invoice and payment.
/// Used by customers (track / pay / cancel) and by the owner (manage, verify).
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId, this.openPayment = false});

  final String orderId;

  /// Opens the payment page straight away (right after checkout).
  final bool openPayment;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.openPayment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final order = context.read<OrdersController>().byId(widget.orderId);
        if (order != null && order.canPay) _openPayment(order.paymentMethod);
      });
    }
  }

  void _openPayment(PaymentMethod method) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => method == PaymentMethod.duitnow
          ? DuitNowPaymentScreen(orderId: widget.orderId)
          : FpxPaymentScreen(orderId: widget.orderId),
    ));
  }

  Future<void> _setStatus(Order order, OrderStatus status) async {
    if (status == OrderStatus.cancelled) {
      final ok = await confirmDialog(
        context,
        title: 'Cancel ${order.code}?',
        message: 'The items will be returned to stock. This cannot be undone.',
        confirmLabel: 'Cancel order',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    final catalog = context.read<CatalogController>();
    final ok = await runWithFeedback(
      context,
      () => context.read<OrdersController>().setStatus(order.id, status),
      success: 'Order marked as ${status.label.toLowerCase()}',
    );
    if (ok && status == OrderStatus.cancelled) catalog.refresh();
  }

  Future<void> _review(Order order, {required bool approve}) async {
    if (!approve) {
      final ok = await confirmDialog(context,
          title: 'Reject this receipt?',
          message: 'The order goes back to "Unpaid" and the customer must pay again '
              'or upload a correct receipt.',
          confirmLabel: 'Reject',
          destructive: true);
      if (!ok || !mounted) return;
    }
    await runWithFeedback(
      context,
      () => context.read<OrdersController>().reviewReceipt(order.id, approve: approve),
      success: approve ? 'Payment approved' : 'Receipt rejected',
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrdersController>().byId(widget.orderId);
    final isAdmin = context.watch<SessionController>().isAdmin;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.search_off, title: 'Order not found'),
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final contact = context.read<ContactService>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Order ${order.code}'),
        actions: [
          IconButton(
            tooltip: 'Download / share invoice (PDF)',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => runWithFeedback(context, () => context.read<InvoiceService>().share(order)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<OrdersController>().reload(order.id),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ContentWidth(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    StatusChip(order.status),
                    PaymentChip(status: order.paymentStatus),
                    if (order.source != OrderSource.app)
                      Chip(label: Text('via ${order.source.label}')),
                  ]),
                  const SizedBox(height: 8),
                  Text('Placed ${formatDateTime(order.createdAt)}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  _Timeline(status: order.status),

                  // ---------- Customer: pay now ----------
                  if (!isAdmin && order.canPay) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: scheme.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text('Payment needed: ${rm(order.total)}',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: scheme.onTertiaryContainer)),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => _openPayment(order.paymentMethod),
                            icon: Icon(order.paymentMethod.icon),
                            label: Text('Pay with ${order.paymentMethod.label}'),
                          ),
                          const SizedBox(height: 8),
                          for (final m in PaymentMethod.values)
                            if (m != order.paymentMethod)
                              OutlinedButton.icon(
                                onPressed: () => _openPayment(m),
                                icon: Icon(m.icon),
                                label: Text('Use ${m.label} instead'),
                              ),
                        ]),
                      ),
                    ),
                  ],

                  // ---------- Owner actions ----------
                  if (isAdmin && order.awaitingVerification) ...[
                    const SectionTitle('Check DuitNow receipt'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text('Make sure ${rm(order.total)} from ${order.customerName} '
                              'reached your account before approving.'),
                          const SizedBox(height: 12),
                          ReceiptImage(order: order, height: 280),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _review(order, approve: false),
                                icon: Icon(Icons.close, color: scheme.error),
                                label: Text('Reject', style: TextStyle(color: scheme.error)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: LoadingButton(
                                label: 'Approve',
                                icon: Icons.verified_outlined,
                                onPressed: () => _review(order, approve: true),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    ),
                  ],
                  if (isAdmin && order.status.isOpen) ...[
                    const SectionTitle('Update order'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (order.status.next != null)
                        LoadingButton(
                          expand: false,
                          icon: order.status.next!.icon,
                          label: 'Mark ${order.status.next!.label.toLowerCase()}',
                          onPressed: () => _setStatus(order, order.status.next!),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _setStatus(order, OrderStatus.cancelled),
                        icon: Icon(Icons.cancel_outlined, color: scheme.error),
                        label: Text('Cancel', style: TextStyle(color: scheme.error)),
                      ),
                    ]),
                  ],

                  // ---------- Customer ----------
                  const SectionTitle('Customer'),
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(initials(order.customerName))),
                      title: Text(order.customerName),
                      subtitle: Text(order.customerPhone.isEmpty ? 'No phone' : order.customerPhone),
                      trailing: isAdmin && order.customerPhone.isNotEmpty
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                tooltip: 'Call customer',
                                icon: const Icon(Icons.call_outlined),
                                onPressed: () => runWithFeedback(
                                    context, () => contact.call(order.customerPhone)),
                              ),
                              IconButton(
                                tooltip: 'WhatsApp customer',
                                icon: const Icon(Icons.chat_outlined),
                                onPressed: () => runWithFeedback(
                                  context,
                                  () => contact.whatsapp(order.customerPhone,
                                      message: 'Hi ${order.customerName}, update for order '
                                          '${order.code}: ${order.status.label}.'),
                                ),
                              ),
                            ])
                          : null,
                    ),
                  ),

                  // ---------- Fulfilment ----------
                  const SectionTitle('Pickup / delivery'),
                  Card(
                    child: Column(children: [
                      ListTile(
                        leading: Icon(order.fulfilment.icon),
                        title: Text(order.fulfilment.label),
                        subtitle: Text(order.scheduledFor == null
                            ? 'Date to be confirmed'
                            : 'On ${formatDate(order.scheduledFor!)}'),
                      ),
                      if (order.fulfilment == Fulfilment.delivery)
                        ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(order.address),
                          subtitle: order.distanceKm == null
                              ? null
                              : Text('${order.distanceKm!.toStringAsFixed(1)} km from kitchen'),
                          trailing: order.lat == null
                              ? null
                              : IconButton(
                                  tooltip: 'Open in Google Maps',
                                  icon: const Icon(Icons.map_outlined),
                                  onPressed: () => runWithFeedback(
                                      context, () => contact.openMap(order.lat!, order.lng!)),
                                ),
                        ),
                      if (order.notes.isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.sticky_note_2_outlined),
                          title: Text(order.notes),
                        ),
                    ]),
                  ),

                  // ---------- Items & totals ----------
                  const SectionTitle('Items'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        for (final i in order.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Text('${i.quantity}x', style: theme.textTheme.titleSmall),
                              const SizedBox(width: 12),
                              Expanded(child: Text(i.productName)),
                              Text(rm(i.lineTotal)),
                            ]),
                          ),
                        const Divider(height: 24),
                        _row('Subtotal', rm(order.subtotal)),
                        if (order.discount > 0) _row('Open House discount', '- ${rm(order.discount)}'),
                        if (order.fulfilment == Fulfilment.delivery)
                          _row('Delivery fee', order.deliveryFee == 0 ? 'FREE' : rm(order.deliveryFee)),
                        const SizedBox(height: 4),
                        _row('Total', rm(order.total), style: theme.textTheme.titleLarge),
                        if (isAdmin) ...[
                          const Divider(height: 24),
                          _row('Cost of goods', rm(order.costOfGoods),
                              style: theme.textTheme.bodySmall),
                          _row('Gross profit', rm(order.total - order.costOfGoods),
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary)),
                        ],
                      ]),
                    ),
                  ),

                  // ---------- Payment ----------
                  const SectionTitle('Payment'),
                  Card(
                    child: Column(children: [
                      ListTile(
                        leading: Icon(order.paymentMethod.icon),
                        title: Text(order.paymentMethod.label),
                        subtitle: Text(switch (order.paymentStatus) {
                          PaymentStatus.paid =>
                            'Paid${order.paymentRef != null ? ' · ${order.paymentRef}' : ''}',
                          PaymentStatus.pendingVerification =>
                            'Receipt uploaded - waiting for Boss Botak to verify',
                          PaymentStatus.unpaid => 'Not paid yet',
                        }),
                        trailing: PaymentChip(status: order.paymentStatus),
                      ),
                      if (order.hasReceipt && !(isAdmin && order.awaitingVerification))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: ReceiptImage(order: order),
                        ),
                      if (isAdmin && order.canPay)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: LoadingButton(
                            tonal: true,
                            label: 'Mark as paid (received outside the app)',
                            icon: Icons.verified_outlined,
                            onPressed: () => runWithFeedback(
                              context,
                              () => context.read<OrdersController>().markPaid(order.id),
                              success: 'Payment recorded',
                            ),
                          ),
                        ),
                    ]),
                  ),

                  // ---------- Customer actions ----------
                  if (!isAdmin) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => runWithFeedback(
                        context,
                        () => contact.whatsappShop(
                            message: 'Hi Boss Botak, saya nak tanya tentang order ${order.code}.'),
                      ),
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Ask Boss on WhatsApp'),
                    ),
                    if (order.status == OrderStatus.pending && !order.isPaid) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _setStatus(order, OrderStatus.cancelled),
                        icon: Icon(Icons.cancel_outlined, color: scheme.error),
                        label: Text('Cancel order', style: TextStyle(color: scheme.error)),
                      ),
                    ],
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {TextStyle? style}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ]),
      );
}

/// Horizontal progress tracker: Pending -> Confirmed -> Preparing -> Ready -> Completed.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (status == OrderStatus.cancelled) {
      return Card(
        color: scheme.errorContainer,
        child: ListTile(
          leading: Icon(Icons.cancel_outlined, color: scheme.onErrorContainer),
          title: Text('This order was cancelled',
              style: TextStyle(color: scheme.onErrorContainer)),
        ),
      );
    }
    final current = OrderStatus.flow.indexOf(status);
    return Semantics(
      label: 'Order progress: step ${current + 1} of ${OrderStatus.flow.length}, ${status.label}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < OrderStatus.flow.length; i++)
              Expanded(
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= current ? scheme.primary : scheme.surfaceContainerHighest,
                    ),
                    child: Icon(OrderStatus.flow[i].icon,
                        size: 20, color: i <= current ? scheme.onPrimary : scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    OrderStatus.flow[i].label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: i == current ? FontWeight.w800 : null),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
