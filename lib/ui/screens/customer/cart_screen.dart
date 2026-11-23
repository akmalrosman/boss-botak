import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/shop_config.dart';
import '../../../core/format.dart';
import '../../../core/pricing.dart';
import '../../../core/validators.dart';
import '../../../data/backend.dart';
import '../../../models/cart_item.dart';
import '../../../models/order.dart';
import '../../../services/location_service.dart';
import '../../../state/cart_controller.dart';
import '../../../state/catalog_controller.dart';
import '../../../state/orders_controller.dart';
import '../../../state/session_controller.dart';
import '../../widgets/adaptive_nav.dart';
import '../../widgets/address_picker.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image.dart';
import '../shared/order_detail_screen.dart';

/// Screen 4 - Cart & checkout.
///
/// In [saleMode] the owner records a WhatsApp / walk-in sale for a customer.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key, this.saleMode = false});

  final bool saleMode;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();

  Fulfilment _fulfilment = Fulfilment.pickup;
  PaymentMethod _payment = PaymentMethod.duitnow;
  OrderSource _source = OrderSource.whatsapp;
  bool _alreadyPaid = false;
  GeoPlace? _place;
  late DateTime _date = _defaultDate();

  static DateTime _defaultDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  @override
  void initState() {
    super.initState();
    final user = context.read<SessionController>().user;
    if (!widget.saleMode && user != null && user.hasLocation && user.address.isNotEmpty) {
      _place = GeoPlace(address: user.address, lat: user.lat!, lng: user.lng!);
    }
    if (widget.saleMode) _date = DateTime.now();
  }

  @override
  void dispose() {
    _notes.dispose();
    _customerName.dispose();
    _customerPhone.dispose();
    super.dispose();
  }

  double? get _distanceKm => _place == null
      ? null
      : haversineKm(ShopConfig.shopLat, ShopConfig.shopLng, _place!.lat, _place!.lng);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
      helpText: _fulfilment == Fulfilment.pickup ? 'Pickup date' : 'Delivery date',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _placeOrder(CartController cart) async {
    if (!_formKey.currentState!.validate()) {
      showSnack(context, 'Please complete the highlighted fields.', error: true);
      return;
    }
    final delivery = _fulfilment == Fulfilment.delivery;
    if (delivery && _place == null) {
      showSnack(context, 'Please set a delivery address.', error: true);
      return;
    }
    if (delivery && !PricingPolicy.isDeliverable(_distanceKm!)) {
      showSnack(context, 'This address is outside our delivery area. Choose self pickup.',
          error: true);
      return;
    }

    final draft = OrderDraft(
      lines: {for (final i in cart.items) i.product.id: i.quantity},
      fulfilment: _fulfilment,
      paymentMethod: _payment,
      address: delivery ? _place!.address : '',
      lat: delivery ? _place!.lat : null,
      lng: delivery ? _place!.lng : null,
      scheduledFor: _date,
      notes: _notes.text.trim(),
      customerName: widget.saleMode ? _customerName.text.trim() : null,
      customerPhone: widget.saleMode ? _customerPhone.text.trim() : null,
      source: widget.saleMode ? _source : OrderSource.app,
      markPaid: widget.saleMode && _alreadyPaid,
    );

    final navigator = Navigator.of(context);
    final shellNav = widget.saleMode ? null : context.read<ShellNavigator>();
    final catalog = context.read<CatalogController>();
    try {
      final order = await context.read<OrdersController>().place(draft);
      cart.clear();
      catalog.refresh(); // stock levels changed
      if (!mounted) return;
      showSnack(context, 'Order ${order.code} placed!');
      _notes.clear();
      _customerName.clear();
      _customerPhone.clear();
      if (widget.saleMode) {
        navigator.popUntil((r) => r.isFirst);
      } else {
        shellNav!.go(2);
      }
      navigator.push(MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: order.id, openPayment: !widget.saleMode),
      ));
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final title = widget.saleMode ? 'New sale' : 'Your cart';

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: 'Your cart is empty',
          message: 'Browse our otak-otak and pepes and add something tasty.',
          action: FilledButton.icon(
            onPressed: () => widget.saleMode
                ? Navigator.pop(context)
                : context.read<ShellNavigator>().go(0),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Browse products'),
          ),
        ),
      );
    }

    final items = _CartItems(cart: cart);
    final checkout = _buildCheckout(context, cart);

    return Scaffold(
      appBar: AppBar(
        title: Text('$title (${cart.count})'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              if (await confirmDialog(context,
                  title: 'Clear cart?',
                  message: 'Remove all items from the cart?',
                  confirmLabel: 'Clear',
                  destructive: true)) {
                cart.clear();
              }
            },
            icon: const Icon(Icons.remove_shopping_cart_outlined),
            label: const Text('Clear'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [items])),
                  SizedBox(
                    width: 440,
                    child: ListView(padding: const EdgeInsets.all(16), children: [checkout]),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [ContentWidth(child: Column(children: [items, checkout]))],
              ),
      ),
    );
  }

  Widget _buildCheckout(BuildContext context, CartController cart) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final delivery = _fulfilment == Fulfilment.delivery;
    final km = _distanceKm;
    final deliverable = km == null || PricingPolicy.isDeliverable(km);
    final totals = PricingPolicy.totals(
      subtotal: cart.subtotal,
      delivery: delivery && km != null,
      distanceKm: km ?? 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.saleMode) ...[
          const SectionTitle('Customer'),
          TextFormField(
            controller: _customerName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Customer name', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => Validators.required(v, 'Customer name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone_outlined)),
            validator: (v) => (v == null || v.trim().isEmpty) ? null : Validators.phone(v),
          ),
          const SizedBox(height: 12),
          SegmentedButton<OrderSource>(
            segments: const [
              ButtonSegment(
                  value: OrderSource.whatsapp, label: Text('WhatsApp'), icon: Icon(Icons.chat_outlined)),
              ButtonSegment(
                  value: OrderSource.walkIn, label: Text('Walk-in'), icon: Icon(Icons.directions_walk)),
            ],
            selected: {_source},
            onSelectionChanged: (s) => setState(() => _source = s.first),
          ),
        ],
        const SectionTitle('Pickup or delivery'),
        SegmentedButton<Fulfilment>(
          segments: [
            for (final f in Fulfilment.values)
              ButtonSegment(value: f, label: Text(f.label), icon: Icon(f.icon)),
          ],
          selected: {_fulfilment},
          onSelectionChanged: (s) => setState(() => _fulfilment = s.first),
        ),
        const SizedBox(height: 12),
        if (delivery) ...[
          AddressPicker(value: _place, onChanged: (p) => setState(() => _place = p)),
          if (km != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  deliverable
                      ? 'Distance from our kitchen: ${km.toStringAsFixed(1)} km'
                      : 'Sorry, ${km.toStringAsFixed(1)} km is outside our '
                          '${PricingPolicy.maxDeliveryKm.round()} km delivery area. '
                          'Please choose self pickup.',
                  style: TextStyle(color: deliverable ? scheme.onSurfaceVariant : scheme.error),
                ),
              ),
            ),
        ] else
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Pickup at Boss Botak kitchen'),
              subtitle: Text('${ShopConfig.shopAddress} · we will WhatsApp you the exact location'),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(delivery ? 'Delivery date' : 'Pickup date'),
            subtitle: Text(formatDate(_date)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _pickDate,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notes,
          maxLines: 2,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Notes for Boss (optional)',
            hintText: 'e.g. Untuk open house hari Sabtu, nak ambil pukul 3 petang',
            prefixIcon: Icon(Icons.sticky_note_2_outlined),
          ),
        ),
        const SectionTitle('Payment'),
        Card(
          child: RadioGroup<PaymentMethod>(
            groupValue: _payment,
            onChanged: (m) => setState(() => _payment = m ?? _payment),
            child: Column(
              children: [
                for (final m in PaymentMethod.values)
                  RadioListTile<PaymentMethod>(
                    value: m,
                    secondary: Icon(m.icon),
                    title: Text(m.label),
                    subtitle: Text(m.description),
                  ),
              ],
            ),
          ),
        ),
        if (widget.saleMode)
          SwitchListTile(
            value: _alreadyPaid,
            onChanged: (v) => setState(() => _alreadyPaid = v),
            title: const Text('Customer has already paid'),
            secondary: const Icon(Icons.verified_outlined),
          ),
        const SectionTitle('Summary'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _line(context, 'Subtotal', rm(totals.subtotal)),
                if (totals.discount > 0)
                  _line(context, 'Open House discount (5%)', '- ${rm(totals.discount)}',
                      color: scheme.primary),
                if (delivery)
                  _line(
                    context,
                    'Delivery fee',
                    km == null ? 'Set address' : (totals.deliveryFee == 0 ? 'FREE' : rm(totals.deliveryFee)),
                  ),
                const Divider(height: 24),
                _line(context, 'Total', rm(totals.total), bold: true),
                ..._upsellHints(context, cart.subtotal, delivery),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        LoadingButton(
          label: widget.saleMode
              ? 'Record sale'
              : 'Place order & pay · ${rm(totals.total)}',
          icon: Icons.check_circle_outline,
          onPressed: () => _placeOrder(cart),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _upsellHints(BuildContext context, double subtotal, bool delivery) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant);
    final hints = <String>[];
    if (delivery && subtotal < PricingPolicy.freeDeliveryThreshold) {
      hints.add('Add ${rm(PricingPolicy.freeDeliveryThreshold - subtotal)} more for FREE delivery.');
    }
    if (subtotal < PricingPolicy.bulkDiscountThreshold &&
        subtotal >= PricingPolicy.bulkDiscountThreshold * 0.6) {
      hints.add('Add ${rm(PricingPolicy.bulkDiscountThreshold - subtotal)} more for 5% off.');
    }
    return [
      for (final h in hints)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            const Icon(Icons.local_offer_outlined, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(h, style: style)),
          ]),
        ),
    ];
  }

  Widget _line(BuildContext context, String label, String value, {bool bold = false, Color? color}) {
    final style = bold
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyLarge?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _CartItems extends StatelessWidget {
  const _CartItems({required this.cart});
  final CartController cart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final (index, item) in cart.items.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Dismissible(
              key: ValueKey(item.product.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
              ),
              onDismissed: (_) => _remove(context, item, index),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox.square(
                          dimension: 72,
                          child: ProductImage(
                              imageUrl: item.product.imageUrl,
                              semanticLabel: 'Photo of ${item.product.name}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.product.name, style: theme.textTheme.titleSmall),
                            Text('${rm(item.product.price)} · ${item.product.unit}',
                                style: theme.textTheme.bodySmall),
                            const SizedBox(height: 8),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                QuantityStepper(
                                  value: item.quantity,
                                  max: item.product.stock,
                                  label: 'Quantity of ${item.product.name}',
                                  onChanged: (v) => v == 0
                                      ? _remove(context, item, index)
                                      : cart.setQuantity(item.product, v),
                                ),
                                Text(rm(item.lineTotal), style: theme.textTheme.titleMedium),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Text('Swipe left on an item to remove it',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  void _remove(BuildContext context, CartItem item, int index) {
    cart.remove(item.product.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Removed ${item.product.name}'),
        persist: false,
        action: SnackBarAction(label: 'Undo', onPressed: () => cart.restore(item, index)),
      ));
  }
}
