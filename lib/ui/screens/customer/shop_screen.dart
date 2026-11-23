import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/shop_config.dart';
import '../../../core/format.dart';
import '../../../core/pricing.dart';
import '../../../core/theme.dart';
import '../../../models/product.dart';
import '../../../services/contact_service.dart';
import '../../../state/cart_controller.dart';
import '../../../state/catalog_controller.dart';
import '../../../state/session_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';

/// Screen 2 - Product catalogue with search and category filter.
///
/// [saleMode] is used by the owner to record a WhatsApp / walk-in sale.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.saleMode = false});

  final bool saleMode;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Product> _filter(List<Product> all) {
    final q = _query.trim().toLowerCase();
    return all.where((p) {
      if (_category != null && p.category != _category) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q);
    }).toList();
  }

  void _add(Product p) {
    final added = context.read<CartController>().add(p);
    showSnack(
      context,
      added > 0 ? 'Added ${p.name} to cart' : 'No more stock available for ${p.name}',
      error: added == 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogController>();
    final user = context.watch<SessionController>().user;
    final products = _filter(catalog.activeProducts);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final cartCount = context.select<CartController, int>((c) => c.count);

    final firstName = (user?.fullName ?? '').split(' ').first;

    final content = RefreshIndicator(
      onRefresh: catalog.refresh,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: Text(widget.saleMode
                ? 'New sale - pick products'
                : (firstName.isEmpty ? 'Boss Botak' : 'Hi, $firstName!')),
            actions: [
              if (!widget.saleMode)
                IconButton(
                  tooltip: 'Chat with Boss Botak on WhatsApp',
                  icon: const Icon(Icons.chat_outlined),
                  onPressed: () => runWithFeedback(
                    context,
                    () => context.read<ContactService>().whatsappShop(
                        message: 'Hi Boss Botak, saya nak tanya pasal tempahan.'),
                  ),
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: OfflineBanner(visible: catalog.offline, onRetry: catalog.refresh),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.list(children: [
              SearchBar(
                controller: _search,
                hintText: 'Search otak-otak, pepes...',
                leading: const Icon(Icons.search),
                elevation: const WidgetStatePropertyAll(0),
                trailing: [
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
                ],
                onChanged: (v) => setState(() => _query = v),
              ),
              if (!widget.saleMode) ...[
                const SizedBox(height: 16),
                const _PromoBanner(),
              ],
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in [null, ...ShopConfig.productCategories])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c ?? 'All'),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ]),
          ),
          if (catalog.loading && catalog.products.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (catalog.error != null && catalog.products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.wifi_off,
                title: 'Could not load products',
                message: catalog.error,
                action: FilledButton(onPressed: catalog.refresh, child: const Text('Try again')),
              ),
            )
          else if (products.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.search_off,
                title: 'No products found',
                message: 'Try another keyword or category.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // Grows with the user's font size so text never overflows.
                  mainAxisExtent: 130 + 128 * textScale.clamp(1.0, 2.2),
                ),
                itemCount: products.length,
                itemBuilder: (context, i) => _ProductCard(
                  product: products[i],
                  onAdd: () => _add(products[i]),
                  onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: products[i]),
                  )),
                ),
              ),
            ),
        ],
      ),
    );

    if (!widget.saleMode) return Scaffold(body: SafeArea(bottom: false, child: content));

    return Scaffold(
      body: SafeArea(bottom: false, child: content),
      floatingActionButton: cartCount == 0
          ? null
          : FloatingActionButton.extended(
        heroTag: 'fab-sale-checkout',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const CartScreen(saleMode: true),
              )),
              icon: Badge.count(count: cartCount, child: const Icon(Icons.shopping_cart_checkout)),
              label: const Text('Checkout'),
            ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'Promotion',
      child: Container(
        decoration: BoxDecoration(
          color: BrandColors.sunYellow,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: BrandColors.chilli,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('OPEN TEMPAHAN',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    Text('Khas untuk open house!',
                        style: theme.textTheme.titleLarge?.copyWith(
                            color: BrandColors.onSunYellow, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      'Free delivery above ${rm(PricingPolicy.freeDeliveryThreshold)} · '
                      '${(PricingPolicy.bulkDiscountRate * 100).round()}% off above '
                      '${rm(PricingPolicy.bulkDiscountThreshold)}. Pre-order early!',
                      style: theme.textTheme.bodyMedium?.copyWith(color: BrandColors.onSunYellow),
                    ),
                  ],
                ),
              ),
            ),
            ExcludeSemantics(
              child: SizedBox(
                width: 110,
                height: 130,
                child: Image.asset('assets/images/pepes.jpg', fit: BoxFit.cover),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onAdd, required this.onOpen});

  final Product product;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 130,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'product-${product.id}',
                    child: ProductImage(
                        imageUrl: product.imageUrl, semanticLabel: 'Photo of ${product.name}'),
                  ),
                  if (product.isOutOfStock || product.isLowStock)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: product.isOutOfStock ? scheme.error : BrandColors.chilli,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.isOutOfStock ? 'Sold out' : 'Only ${product.stock} left',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(product.unit,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(rm(product.price),
                              style: theme.textTheme.titleMedium?.copyWith(
                                  color: scheme.primary, fontWeight: FontWeight.w800)),
                        ),
                        IconButton.filled(
                          tooltip: 'Add ${product.name} to cart',
                          onPressed: product.isOutOfStock ? null : onAdd,
                          icon: const Icon(Icons.add_shopping_cart),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
