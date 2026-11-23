import 'package:flutter/material.dart';

/// Shows a bundled photo (`asset:<name>`), a network photo, or a placeholder.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    required this.semanticLabel,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final String semanticLabel;
  final BoxFit fit;

  static const bundled = {
    'otak_otak': 'Otak-otak',
    'pepes': 'Pepes',
    'combo': 'Combo',
  };

  static String assetPath(String name) => 'assets/images/$name.jpg';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder([IconData icon = Icons.set_meal_outlined]) => Container(
          color: scheme.secondaryContainer,
          alignment: Alignment.center,
          child: Icon(icon, size: 40, color: scheme.onSecondaryContainer),
        );

    if (imageUrl.startsWith('asset:')) {
      return Image.asset(
        assetPath(imageUrl.substring(6)),
        fit: fit,
        semanticLabel: semanticLabel,
        errorBuilder: (_, _, _) => placeholder(),
      );
    }
    if (imageUrl.startsWith('https://')) {
      return Image.network(
        imageUrl,
        fit: fit,
        semanticLabel: semanticLabel,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Container(
                color: scheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
        errorBuilder: (_, _, _) => placeholder(Icons.broken_image_outlined),
      );
    }
    return Semantics(label: semanticLabel, image: true, child: placeholder());
  }
}
