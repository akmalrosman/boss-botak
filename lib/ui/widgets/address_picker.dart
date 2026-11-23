import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/backend.dart';
import '../../services/location_service.dart';
import 'common.dart';

/// Delivery address field backed by GPS + OpenStreetMap geocoding.
class AddressPicker extends StatefulWidget {
  const AddressPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.title = 'Delivery address',
  });

  final GeoPlace? value;
  final ValueChanged<GeoPlace> onChanged;
  final String title;

  @override
  State<AddressPicker> createState() => _AddressPickerState();
}

class _AddressPickerState extends State<AddressPicker> {
  bool _locating = false;

  Future<void> _useCurrentLocation() async {
    final service = context.read<LocationService>();
    setState(() => _locating = true);
    try {
      final pos = await service.currentPosition();
      final place = await service.reverseGeocode(pos.lat, pos.lng);
      widget.onChanged(place);
      if (mounted) showSnack(context, 'Location found');
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not get location: $e', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _search() async {
    final place = await showDialog<GeoPlace>(
      context: context,
      builder: (_) => _AddressSearchDialog(initial: widget.value?.address ?? ''),
    );
    if (place != null) widget.onChanged(place);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = widget.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.title, style: theme.textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                v?.address.isNotEmpty == true
                    ? v!.address
                    : 'No address yet. Use your current location or search for it.',
                style: v == null
                    ? theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
                    : theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox.square(
                          dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: Text(_locating ? 'Locating...' : 'Use my location'),
                ),
                OutlinedButton.icon(
                  onPressed: _locating ? null : _search,
                  icon: const Icon(Icons.search),
                  label: const Text('Search address'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Address data © OpenStreetMap contributors',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _AddressSearchDialog extends StatefulWidget {
  const _AddressSearchDialog({required this.initial});
  final String initial;

  @override
  State<_AddressSearchDialog> createState() => _AddressSearchDialogState();
}

class _AddressSearchDialogState extends State<_AddressSearchDialog> {
  late final _query = TextEditingController(text: widget.initial);
  List<GeoPlace> _results = [];
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_query.text.trim().length < 3) {
      setState(() => _message = 'Type at least 3 characters.');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final r = await context.read<LocationService>().search(_query.text);
      setState(() {
        _results = r;
        _message = r.isEmpty ? 'No matching address in Malaysia. Try a taman or postcode.' : null;
      });
    } on AppException catch (e) {
      setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search address'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _run(),
              decoration: InputDecoration(
                hintText: 'e.g. Taman Bukit Pasir, Batu Pahat',
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: _loading ? null : _run,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_message!),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in _results)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(r.address),
                      onTap: () => Navigator.pop(context, r),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}
