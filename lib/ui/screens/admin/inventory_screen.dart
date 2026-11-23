import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../models/product.dart';
import '../../../state/catalog_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image.dart';
import 'admin_shell.dart';
import 'product_form_screen.dart';

/// Screen 10 - Product & inventory management.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _lowOnly = false;

  void _openForm([Product? product]) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ProductFormScreen(product: product),
    ));
  }

  Future<void> _restock(Product p) async {
    final ctrl = TextEditingController(text: '10');
    final delta = await showDialog<int>(
      context: context,
      builder: (ctx) {
        var adding = true;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text('Update stock - ${p.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Current stock: ${p.stock}'),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Add'), icon: Icon(Icons.add)),
                    ButtonSegment(value: false, label: Text('Remove'), icon: Icon(Icons.remove)),
                  ],
                  selected: {adding},
                  onSelectionChanged: (s) => setLocal(() => adding = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: adding ? 'Packs produced / received' : 'Packs damaged / used',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final n = int.tryParse(ctrl.text.trim());
                  if (n == null || n <= 0) return;
                  Navigator.pop(ctx, adding ? n : -n);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    ctrl.dispose();
    if (delta == null || !mounted) return;
    await runWithFeedback(
      context,
      () => context.read<CatalogController>().adjustStock(p.id, delta),
      success: 'Stock updated for ${p.name}',
    );
  }

  Future<void> _toggleActive(Product p) => runWithFeedback(
        context,
        () => context.read<CatalogController>().save(p.copyWith(isActive: !p.isActive)),
        success: p.isActive ? '${p.name} hidden from customers' : '${p.name} is visible again',
      );

  Future<void> _delete(Product p) async {
    final ok = await confirmDialog(context,
        title: 'Delete ${p.name}?',
        message: 'Past orders keep their records. Tip: hide the product instead if you may sell it again.',
        confirmLabel: 'Delete',
        destructive: true);
    if (!ok || !mounted) return;
    await runWithFeedback(context, () => context.read<CatalogController>().delete(p.id),
        success: 'Product deleted');
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogController>();
    final theme = Theme.of(context);
    final all = catalog.products;
    final list = _lowOnly ? catalog.lowStock : all;
    final stockValue = all.fold<double>(0, (s, p) => s + p.cost * p.stock);
    final retailValue = all.fold<double>(0, (s, p) => s + p.price * p.stock);

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        title: const Text('Inventory'),
        bottom: catalog.loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-inventory',
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: RefreshIndicator(
        onRefresh: catalog.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OfflineBanner(visible: catalog.offline, onRetry: catalog.refresh),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _Mini(label: 'Products', value: '${all.length}'),
                      _Mini(label: 'Stock value (cost)', value: rm(stockValue)),
                      _Mini(label: 'Stock value (retail)', value: rm(retailValue)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Show low stock only (${catalog.lowStock.length})'),
                    value: _lowOnly,
                    onChanged: (v) => setState(() => _lowOnly = v),
                  ),
                  if (list.isEmpty)
                    const SizedBox(
                      height: 300,
                      child: EmptyState(
                          icon: Icons.inventory_2_outlined, title: 'Nothing to show here'),
                    ),
                  for (final p in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: InkWell(
                          onTap: () => _openForm(p),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox.square(
                                    dimension: 64,
                                    child: Opacity(
                                      opacity: p.isActive ? 1 : 0.4,
                                      child: ProductImage(
                                          imageUrl: p.imageUrl, semanticLabel: 'Photo of ${p.name}'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name, style: theme.textTheme.titleSmall),
                                      Text(
                                        '${rm(p.price)} · cost ${rm(p.cost)} · margin ${rm(p.margin)}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(spacing: 6, runSpacing: 4, children: [
                                        _StockBadge(product: p),
                                        if (!p.isActive)
                                          const _Tag(text: 'Hidden', icon: Icons.visibility_off_outlined),
                                      ]),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Update stock',
                                  onPressed: () => _restock(p),
                                  icon: const Icon(Icons.add_box_outlined),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'More actions',
                                  onSelected: (v) => switch (v) {
                                    'edit' => _openForm(p),
                                    'toggle' => _toggleActive(p),
                                    'delete' => _delete(p),
                                    _ => null,
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                        value: 'edit',
                                        child: ListTile(
                                            leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                                    PopupMenuItem(
                                        value: 'toggle',
                                        child: ListTile(
                                            leading: Icon(p.isActive
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined),
                                            title: Text(p.isActive ? 'Hide from shop' : 'Show in shop'))),
                                    const PopupMenuItem(
                                        value: 'delete',
                                        child: ListTile(
                                            leading: Icon(Icons.delete_outline), title: Text('Delete'))),
                                  ],
                                ),
                              ],
                            ),
                          ),
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

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              Text(value, style: theme.textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = product;
    if (p.isOutOfStock) {
      return _Tag(text: 'Out of stock', icon: Icons.error_outline, color: scheme.error);
    }
    if (p.isLowStock) {
      return _Tag(text: 'Low: ${p.stock} left', icon: Icons.warning_amber_rounded, color: BrandColors.warning);
    }
    return _Tag(text: '${p.stock} in stock', icon: Icons.check_circle_outline, color: scheme.primary);
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.icon, this.color});
  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: c),
      const SizedBox(width: 4),
      Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c)),
    ]);
  }
}
