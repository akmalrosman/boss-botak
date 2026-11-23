import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/shop_config.dart';
import '../../../core/format.dart';
import '../../../data/backend.dart';
import '../../../models/order.dart';
import '../../../state/orders_controller.dart';
import '../../widgets/common.dart';

/// Banks shown in the FPX list (sandbox simulation).
const fpxBanks = [
  'Maybank2u',
  'CIMB Clicks',
  'Public Bank',
  'RHB Now',
  'Hong Leong Connect',
  'Bank Islam',
  'AmOnline',
  'Bank Rakyat',
  'BSN',
  'Affin Bank',
  'Alliance Bank',
  'Bank Muamalat',
  'OCBC Bank',
  'UOB Bank',
];

enum _Step { chooseBank, bankPage, success, cancelled }

/// FPX online banking - DUMMY flow for the prototype.
///
/// Mimics the real journey (choose bank -> bank approval page -> result)
/// without contacting any bank. It is replaced by a real payment gateway
/// (e.g. a licensed FPX provider's sandbox) in the next phase.
class FpxPaymentScreen extends StatefulWidget {
  const FpxPaymentScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<FpxPaymentScreen> createState() => _FpxPaymentScreenState();
}

class _FpxPaymentScreenState extends State<FpxPaymentScreen> {
  _Step _step = _Step.chooseBank;
  String? _bank;
  bool _processing = false;

  Future<void> _approve() async {
    setState(() => _processing = true);
    try {
      await context.read<OrdersController>().payWithFpx(widget.orderId, _bank!);
      if (mounted) setState(() => _step = _Step.success);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrdersController>().byId(widget.orderId);
    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.search_off, title: 'Order not found'),
      );
    }

    final body = switch (_step) {
      _Step.chooseBank => _chooseBank(order),
      _Step.bankPage => _bankPage(order),
      _Step.success => _result(order, success: true),
      _Step.cancelled => _result(order, success: false),
    };

    return PopScope(
      canPop: !_processing,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('FPX Online Banking'),
          leading: _step == _Step.bankPage
              ? IconButton(
                  tooltip: 'Back to bank list',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _processing ? null : () => setState(() => _step = _Step.chooseBank),
                )
              : null,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [ContentWidth(maxWidth: 560, child: body)],
        ),
      ),
    );
  }

  Widget _summary(Order order) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Pay to ${ShopConfig.name}', style: theme.textTheme.titleMedium)),
            const _SandboxBadge(),
          ]),
          const SizedBox(height: 4),
          Text('Order ${order.code}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(rm(order.total),
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------- step 1
  Widget _chooseBank(Order order) {
    final scheme = Theme.of(context).colorScheme;
    if (!order.canPay) return _result(order, success: order.isPaid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summary(order),
        const SectionTitle('Select your bank'),
        Card(
          child: RadioGroup<String>(
            groupValue: _bank,
            onChanged: (b) => setState(() => _bank = b),
            child: Column(children: [
              for (final b in fpxBanks)
                RadioListTile<String>(
                  value: b,
                  title: Text(b),
                  secondary: CircleAvatar(
                    backgroundColor: scheme.secondaryContainer,
                    child: Text(initials(b),
                        style: TextStyle(
                            color: scheme.onSecondaryContainer, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _bank == null ? null : () => setState(() => _step = _Step.bankPage),
          icon: const Icon(Icons.lock_outline),
          label: Text(_bank == null ? 'Choose a bank to continue' : 'Proceed to $_bank'),
        ),
        const SizedBox(height: 8),
        Text(
          'Prototype: this is a simulated FPX flow. No real bank account is charged.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------------------------------------------------------- step 2
  Widget _bankPage(Order order) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: scheme.surfaceContainerHigh,
          child: Column(children: [
            Container(
              width: double.infinity,
              color: scheme.inverseSurface,
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.account_balance, color: scheme.onInverseSurface),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$_bank (simulated)',
                      style: theme.textTheme.titleMedium?.copyWith(color: scheme.onInverseSurface)),
                ),
                const _SandboxBadge(),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Confirm this payment', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _kv('Merchant', ShopConfig.name),
                _kv('Reference', order.code),
                _kv('From account', 'Savings Account ****1234 (demo)'),
                const Divider(height: 24),
                _kv('Amount', rm(order.total), bold: true),
                const SizedBox(height: 16),
                if (_processing) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Processing payment with your bank...', textAlign: TextAlign.center),
                ] else ...[
                  FilledButton.icon(
                    onPressed: _approve,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Approve payment'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => setState(() => _step = _Step.cancelled),
                    child: const Text('Cancel'),
                  ),
                ],
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    final style = bold
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(k, style: style)),
        Flexible(child: Text(v, style: style, textAlign: TextAlign.end)),
      ]),
    );
  }

  // ---------------------------------------------------------- step 3
  Widget _result(Order order, {required bool success}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Icon(success ? Icons.verified : Icons.cancel_outlined,
              size: 72, color: success ? scheme.primary : scheme.error),
        ),
        const SizedBox(height: 12),
        Text(success ? 'Payment successful' : 'Payment cancelled',
            textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          success
              ? 'Terima kasih! Your order ${order.code} is paid.'
              : 'No money was taken. You can try again or choose another bank.',
          textAlign: TextAlign.center,
        ),
        if (success) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _kv('Amount', rm(order.total), bold: true),
                _kv('Transaction', order.paymentRef ?? '-'),
                _kv('Date', formatDateTime(DateTime.now())),
                _kv('Status', 'Successful'),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (!success)
          FilledButton.icon(
            onPressed: () => setState(() => _step = _Step.chooseBank),
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        if (!success) const SizedBox(height: 8),
        (success ? FilledButton.icon : OutlinedButton.icon)(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('View order'),
        ),
      ],
    );
  }
}

class _SandboxBadge extends StatelessWidget {
  const _SandboxBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Text('SANDBOX',
          style: TextStyle(
              color: scheme.onTertiaryContainer, fontWeight: FontWeight.w900, fontSize: 11)),
    );
  }
}
