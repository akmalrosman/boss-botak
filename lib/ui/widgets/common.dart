import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/backend.dart';
import '../../models/order.dart';

/// Shows a SnackBar. Errors use the error colour so they stand out.
void showSnack(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message,
          style: error ? TextStyle(color: scheme.onErrorContainer) : null),
      backgroundColor: error ? scheme.errorContainer : null,
      showCloseIcon: error,
      closeIconColor: error ? scheme.onErrorContainer : null,
    ));
}

/// Runs [action]; shows [success] or the error message as feedback.
Future<bool> runWithFeedback(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) showSnack(context, success);
    return true;
  } on AppException catch (e) {
    if (context.mounted) showSnack(context, e.message, error: true);
  } catch (e) {
    if (context.mounted) showSnack(context, 'Something went wrong: $e', error: true);
  }
  return false;
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error, foregroundColor: scheme.onError)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Filled button that shows a spinner and disables itself while [onPressed]
/// is running - instant visual feedback and no double submits.
class LoadingButton extends StatefulWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tonal = false,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final Future<void> Function()? onPressed;
  final bool tonal;
  final bool expand;

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed == null || _busy ? null : _run;
    final child = _busy
        ? const SizedBox.square(
            dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
        : Text(widget.label);
    final icon = _busy || widget.icon == null ? null : Icon(widget.icon);
    final button = widget.tonal
        ? (icon == null
            ? FilledButton.tonal(onPressed: onPressed, child: child)
            : FilledButton.tonalIcon(onPressed: onPressed, icon: icon, label: child))
        : (icon == null
            ? FilledButton(onPressed: onPressed, child: child)
            : FilledButton.icon(onPressed: onPressed, icon: icon, label: child));
    return Semantics(
      button: true,
      label: _busy ? '${widget.label}, loading' : null,
      child: widget.expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Icon(icon, size: 40, color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Thin banner telling the user that cached data is being shown.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.visible, this.onRetry});

  final bool visible;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Material(
                color: scheme.tertiaryContainer,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.cloud_off, color: scheme.onTertiaryContainer),
                  title: Text('You are offline - showing saved data',
                      style: TextStyle(color: scheme.onTertiaryContainer)),
                  trailing: onRetry == null
                      ? null
                      : TextButton(onPressed: onRetry, child: const Text('Retry')),
                ),
              ),
            ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.max = 999,
    this.min = 0,
    this.label = 'Quantity',
  });

  final int value;
  final int min;
  final int max;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label $value',
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Decrease $label',
              visualDensity: VisualDensity.compact,
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: Icon(value <= 1 && min == 0 ? Icons.delete_outline : Icons.remove),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 28),
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              tooltip: 'Increase $label',
              visualDensity: VisualDensity.compact,
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      OrderStatus.pending => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      OrderStatus.cancelled => (scheme.errorContainer, scheme.onErrorContainer),
      OrderStatus.completed => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      _ => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
    return _Pill(icon: status.icon, label: status.label, bg: bg, fg: fg);
  }
}

class PaymentChip extends StatelessWidget {
  const PaymentChip({super.key, required this.status});
  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (status) {
      PaymentStatus.paid => _Pill(
          icon: Icons.verified_outlined,
          label: status.label,
          bg: dark ? const Color(0xFF14391F) : const Color(0xFFDDF3E2),
          fg: dark ? const Color(0xFFA6E3B5) : BrandColors.success,
        ),
      PaymentStatus.pendingVerification => _Pill(
          icon: Icons.fact_check_outlined,
          label: 'Verifying receipt',
          bg: scheme.secondaryContainer,
          fg: scheme.onSecondaryContainer,
        ),
      PaymentStatus.unpaid => _Pill(
          icon: Icons.hourglass_bottom,
          label: status.label,
          bg: scheme.surfaceContainerHighest,
          fg: dark ? const Color(0xFFFFC58A) : BrandColors.warning,
        ),
    };
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.bg, required this.fg});
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Constrains content width on tablets / landscape so lines stay readable.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 900});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
