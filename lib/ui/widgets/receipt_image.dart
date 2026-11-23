import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/backend.dart';
import '../../models/order.dart';

/// Asks whether to take a photo or pick from the gallery, then returns a
/// compressed image (receipts are kept small: max ~1280 px, JPEG 70%).
Future<XFile?> pickReceiptImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose screenshot / photo'),
            subtitle: const Text('e.g. the receipt screenshot from your banking app'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return null;
  return ImagePicker().pickImage(source: source, maxWidth: 1280, imageQuality: 70);
}

/// Shows the DuitNow receipt attached to an order. Tap to view full screen.
class ReceiptImage extends StatefulWidget {
  const ReceiptImage({super.key, required this.order, this.height = 180});

  final Order order;
  final double height;

  @override
  State<ReceiptImage> createState() => _ReceiptImageState();
}

class _ReceiptImageState extends State<ReceiptImage> {
  late Future<String> _url;

  @override
  void initState() {
    super.initState();
    _url = context.read<Backend>().receiptImageUrl(widget.order);
  }

  @override
  void didUpdateWidget(ReceiptImage old) {
    super.didUpdateWidget(old);
    if (old.order.receiptUrl != widget.order.receiptUrl) {
      _url = context.read<Backend>().receiptImageUrl(widget.order);
    }
  }

  static Widget imageFor(String url, {BoxFit fit = BoxFit.cover}) {
    if (url.startsWith('data:')) {
      return Image.memory(UriData.parse(url).contentAsBytes(),
          fit: fit, semanticLabel: 'Payment receipt');
    }
    return Image.network(url, fit: fit, semanticLabel: 'Payment receipt');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snap) {
        Widget child;
        if (snap.connectionState != ConnectionState.done) {
          child = const Center(child: CircularProgressIndicator());
        } else if (snap.hasError || (snap.data ?? '').isEmpty) {
          child = Center(
            child: Text('Receipt could not be loaded',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          );
        } else {
          final url = snap.data!;
          child = InkWell(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog.fullscreen(
                child: Scaffold(
                  appBar: AppBar(title: Text('Receipt · ${widget.order.code}')),
                  body: InteractiveViewer(
                    maxScale: 5,
                    child: Center(child: imageFor(url, fit: BoxFit.contain)),
                  ),
                ),
              ),
            ),
            child: Stack(fit: StackFit.expand, children: [
              imageFor(url),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.zoom_in, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Tap to view', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ]),
                ),
              ),
            ]),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: widget.height,
            width: double.infinity,
            color: scheme.surfaceContainerHighest,
            child: child,
          ),
        );
      },
    );
  }
}
