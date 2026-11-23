import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../config/shop_config.dart';
import '../../../core/validators.dart';
import '../../../data/backend.dart';
import '../../../models/product.dart';
import '../../../state/catalog_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image.dart';

/// Add / edit product form (full-screen dialog opened from Inventory).
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Product _initial = widget.product ??
      const Product(
        id: '',
        name: '',
        category: 'Otak-Otak',
        price: 0,
        cost: 0,
        stock: 0,
        imageUrl: 'asset:otak_otak',
      );

  late final _name = TextEditingController(text: _initial.name);
  late final _unit = TextEditingController(text: _initial.unit);
  late final _description = TextEditingController(text: _initial.description);
  late final _price = TextEditingController(text: _initial.isNew ? '' : _initial.price.toStringAsFixed(2));
  late final _cost = TextEditingController(text: _initial.isNew ? '' : _initial.cost.toStringAsFixed(2));
  late final _stock = TextEditingController(text: '${_initial.stock}');
  late final _threshold = TextEditingController(text: '${_initial.lowStockThreshold}');
  late String _category = _initial.category;
  late String _imageUrl = _initial.imageUrl;
  late bool _active = _initial.isActive;
  bool _uploading = false;

  @override
  void dispose() {
    for (final c in [_name, _unit, _description, _price, _cost, _stock, _threshold]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _uploadPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final url = await context.read<CatalogController>().uploadImage(bytes, picked.name);
      setState(() => _imageUrl = url);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final price = double.parse(_price.text.trim());
    final cost = double.parse(_cost.text.trim());
    if (cost > price) {
      final ok = await confirmDialog(context,
          title: 'Selling below cost?',
          message: 'The cost is higher than the selling price, so each sale makes a loss. Save anyway?',
          confirmLabel: 'Save anyway');
      if (!ok || !mounted) return;
    }
    final product = _initial.copyWith(
      name: _name.text.trim(),
      unit: _unit.text.trim(),
      description: _description.text.trim(),
      category: _category,
      price: price,
      cost: cost,
      stock: int.parse(_stock.text.trim()),
      lowStockThreshold: int.parse(_threshold.text.trim()),
      imageUrl: _imageUrl,
      isActive: _active,
    );
    final navigator = Navigator.of(context);
    final ok = await runWithFeedback(
      context,
      () => context.read<CatalogController>().save(product),
      success: product.isNew ? 'Product added' : 'Product updated',
    );
    if (ok) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final canUpload = context.read<Backend>().supportsImageUpload;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_initial.isNew ? 'Add product' : 'Edit product'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ContentWidth(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(fit: StackFit.expand, children: [
                        ProductImage(imageUrl: _imageUrl, semanticLabel: 'Product photo'),
                        if (_uploading)
                          const ColoredBox(
                            color: Colors.black38,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Photo', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final e in ProductImage.bundled.entries)
                      ChoiceChip(
                        label: Text(e.value),
                        selected: _imageUrl == 'asset:${e.key}',
                        onSelected: (_) => setState(() => _imageUrl = 'asset:${e.key}'),
                      ),
                    if (canUpload)
                      ActionChip(
                        avatar: const Icon(Icons.upload_outlined),
                        label: const Text('Upload photo'),
                        onPressed: _uploading ? null : _uploadPhoto,
                      ),
                  ]),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Product name'),
                    validator: (v) => Validators.required(v, 'Name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: ShopConfig.productCategories.contains(_category) ? _category : null,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final c in ShopConfig.productCategories)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? _category),
                    validator: (v) => v == null ? 'Choose a category' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _unit,
                    decoration: const InputDecoration(
                        labelText: 'Pack size', hintText: 'e.g. 10 pcs / pack'),
                    validator: (v) => Validators.required(v, 'Pack size'),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Selling price (RM)'),
                        validator: Validators.money,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cost,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Cost per pack (RM)', helperText: 'For profit reports'),
                        validator: (v) => Validators.money(v, allowZero: true),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stock,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Stock (packs)'),
                        validator: Validators.wholeNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _threshold,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Low-stock alert at', helperText: 'Notify when stock ≤'),
                        validator: Validators.wholeNumber,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Visible in shop'),
                    subtitle: const Text('Turn off to hide without deleting'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                  const SizedBox(height: 16),
                  LoadingButton(
                    label: _initial.isNew ? 'Add product' : 'Save changes',
                    icon: Icons.save_outlined,
                    onPressed: _uploading ? null : _save,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
