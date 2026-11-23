import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../models/product.dart';
import '../../../state/cart_controller.dart';
import '../../../state/catalog_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image.dart';

/// Screen 3 - Product details and add-to-cart.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    // Use the freshest copy from the catalogue (stock may have changed).
    final product =
        context.watch<CatalogController>().byId(widget.product.id) ?? widget.product;
    final inCart = context.select<CartController, int>((c) => c.quantityOf(product.id));
    final available = (product.stock - inCart).clamp(0, 999);
    final qty = _qty.clamp(available == 0 ? 0 : 1, available == 0 ? 0 : available);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 720;

    final image = Hero(
      tag: 'product-${product.id}',
      child: ProductImage(imageUrl: product.imageUrl, semanticLabel: 'Photo of ${product.name}'),
    );

    final details = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 8, children: [
            Chip(label: Text(product.category), avatar: const Icon(Icons.category_outlined, size: 18)),
            Chip(
              avatar: Icon(Icons.ac_unit, size: 18, color: scheme.primary),
              label: const Text('Frozen'),
            ),
          ]),
          const SizedBox(height: 8),
          Text(product.name, style: theme.textTheme.headlineSmall),
          Text(product.unit,
              style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Text(rm(product.price),
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              product.isOutOfStock
                  ? 'Sold out - WhatsApp us to pre-order'
                  : product.isLowStock
                      ? 'Hurry! Only ${product.stock} packs left'
                      : 'In stock (${product.stock} packs)',
              style: theme.textTheme.titleSmall?.copyWith(
                  color: product.isOutOfStock || product.isLowStock ? scheme.error : scheme.primary),
            ),
          ),
          const SectionTitle('About this product'),
          Text(product.description.isEmpty ? 'Homemade by Boss Botak.' : product.description,
              style: theme.textTheme.bodyLarge),
          const SectionTitle('Cooking & storage tips'),
          Card(
            child: Column(children: const [
              ListTile(
                leading: Icon(Icons.kitchen_outlined),
                title: Text('Keep frozen at -18°C'),
                subtitle: Text('Best within 3 months. Do not refreeze after thawing.'),
              ),
              ListTile(
                leading: Icon(Icons.outdoor_grill_outlined),
                title: Text('Grill, steam or air-fry from frozen'),
                subtitle: Text('About 8-12 minutes until hot and fragrant.'),
              ),
            ]),
          ),
          if (inCart > 0) ...[
            const SizedBox(height: 16),
            Text('You already have $inCart in your cart.',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );

    return Scaffold(
      appBar: wide ? AppBar(title: Text(product.name)) : null,
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SizedBox.expand(child: image)),
                Expanded(child: SingleChildScrollView(child: details)),
              ],
            )
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(background: image),
                ),
                SliverToBoxAdapter(child: details),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              QuantityStepper(
                value: qty,
                min: available == 0 ? 0 : 1,
                max: available,
                onChanged: (v) => setState(() => _qty = v),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: available == 0
                      ? null
                      : () {
                          context.read<CartController>().add(product, qty);
                          showSnack(context, 'Added $qty x ${product.name} to cart');
                          setState(() => _qty = 1);
                        },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(available == 0
                      ? (product.isOutOfStock ? 'Sold out' : 'Max in cart')
                      : 'Add ${rm(product.price * qty)}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
