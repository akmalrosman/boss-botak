import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../config/shop_config.dart';
import '../../../core/format.dart';
import '../../../models/order.dart';
import '../../../state/orders_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/receipt_image.dart';

/// DuitNow QR payment (demo).
///
/// 1. The customer scans the QR with their banking app / e-wallet.
/// 2. After paying they upload the receipt screenshot.
/// 3. The order becomes "Verifying receipt" until the owner approves it.
///
/// The QR is a DUMMY for the project prototype - it does not contain a real
/// DuitNow merchant account, so scanning it cannot transfer money.
class DuitNowPaymentScreen extends StatefulWidget {
  const DuitNowPaymentScreen({super.key, required this.orderId});

  final String orderId;

  static const pink = Color(0xFFD6145F);

  @override
  State<DuitNowPaymentScreen> createState() => _DuitNowPaymentScreenState();
}

class _DuitNowPaymentScreenState extends State<DuitNowPaymentScreen> {
  Uint8List? _receipt;
  String _fileName = 'receipt.jpg';
  bool _picking = false;

  String _payload(Order o) =>
      'DEMO-DUITNOW-QR|MERCHANT=${ShopConfig.name.toUpperCase()}|REF=${o.code}'
      '|AMOUNT=${o.total.toStringAsFixed(2)}|CURRENCY=MYR';

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final file = await pickReceiptImage(context);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _receipt = bytes;
        _fileName = file.name;
      });
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open the image: $e', error: true);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    final bytes = _receipt;
    if (bytes == null) return;
    await runWithFeedback(
      context,
      () => context.read<OrdersController>().submitReceipt(widget.orderId, bytes, _fileName),
      success: 'Receipt sent to Boss Botak',
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrdersController>().byId(widget.orderId);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.search_off, title: 'Order not found'),
      );
    }

    final submitted = !order.canPay;

    return Scaffold(
      appBar: AppBar(title: const Text('Pay with DuitNow QR')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ContentWidth(
            maxWidth: 520,
            child: submitted
                ? _Submitted(order: order)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---------- QR card ----------
                      Card(
                        child: Column(children: [
                          Container(
                            width: double.infinity,
                            color: DuitNowPaymentScreen.pink,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            child: Row(children: [
                              const Icon(Icons.qr_code_2, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('DuitNow QR',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                        color: Colors.white, fontWeight: FontWeight.w800)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.white, borderRadius: BorderRadius.circular(8)),
                                child: const Text('DEMO',
                                    style: TextStyle(
                                        color: DuitNowPaymentScreen.pink,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12)),
                              ),
                            ]),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(children: [
                              Text(ShopConfig.name.toUpperCase(),
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 12),
                              Semantics(
                                label: 'Demo DuitNow QR code for order ${order.code}',
                                image: true,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white, // QR needs a light background
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: DuitNowPaymentScreen.pink, width: 3),
                                  ),
                                  child: QrImageView(
                                    data: _payload(order),
                                    size: 220,
                                    backgroundColor: Colors.white,
                                    eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square, color: Colors.black),
                                    dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: Colors.black),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text('Amount to pay', style: theme.textTheme.labelLarge),
                              Text(rm(order.total),
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                      color: scheme.primary, fontWeight: FontWeight.w900)),
                              Text('Reference: ${order.code}', style: theme.textTheme.bodyMedium),
                              const SizedBox(height: 12),
                              Text(
                                'Demo QR for the prototype - scanning it will not make a real payment.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ]),
                          ),
                        ]),
                      ),

                      // ---------- steps ----------
                      const SectionTitle('How to pay'),
                      const _Step(1, 'Open your banking app or e-wallet and choose "Scan QR / DuitNow QR".'),
                      _Step(2, 'Scan the QR above and pay exactly ${rm(order.total)}. '
                          'Put ${order.code} as the reference.'),
                      const _Step(3, 'Take a screenshot of the successful payment and upload it below.'),

                      // ---------- receipt upload ----------
                      const SectionTitle('Upload payment receipt'),
                      if (_receipt != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 260,
                            color: scheme.surfaceContainerHighest,
                            child: Image.memory(_receipt!,
                                fit: BoxFit.contain, semanticLabel: 'Selected receipt'),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: _picking ? null : _pick,
                        icon: _picking
                            ? const SizedBox.square(
                                dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(_receipt == null ? Icons.upload_file : Icons.swap_horiz),
                        label: Text(_receipt == null ? 'Choose receipt image' : 'Choose a different image'),
                      ),
                      const SizedBox(height: 12),
                      LoadingButton(
                        label: 'Submit receipt',
                        icon: Icons.send_outlined,
                        onPressed: _receipt == null ? null : _submit,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.text);
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: scheme.primaryContainer,
          child: Text('$number',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ]),
    );
  }
}

/// Shown after the receipt is sent (or if the order is already paid).
class _Submitted extends StatelessWidget {
  const _Submitted({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paid = order.isPaid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Icon(paid ? Icons.verified : Icons.mark_email_read_outlined,
            size: 72, color: scheme.primary),
        const SizedBox(height: 12),
        Text(paid ? 'Payment confirmed' : 'Receipt sent!',
            textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          paid
              ? 'Terima kasih! Your payment for ${order.code} has been confirmed.'
              : 'Boss Botak will check your receipt and confirm your order soon. '
                  'You can follow the status in My Orders.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Center(child: PaymentChip(status: order.paymentStatus)),
        if (order.hasReceipt) ...[
          const SectionTitle('Your receipt'),
          ReceiptImage(order: order, height: 220),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('View order'),
        ),
      ],
    );
  }
}
