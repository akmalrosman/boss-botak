import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app.dart';
import '../../../config/shop_config.dart';
import '../../../core/format.dart';
import '../../../core/validators.dart';
import '../../../data/backend.dart';
import '../../../data/demo_backend.dart';
import '../../../services/contact_service.dart';
import '../../../services/location_service.dart';
import '../../../state/session_controller.dart';
import '../../../state/settings_controller.dart';
import '../../widgets/address_picker.dart';
import '../../widgets/common.dart';

/// Screen 7 - User profile, default address, app settings and sign out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.pushed = false});

  /// True when opened as its own page (owner's drawer) instead of a tab.
  final bool pushed;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  GeoPlace? _place;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<SessionController>().user!;
    _name = TextEditingController(text: u.fullName);
    _phone = TextEditingController(text: u.phone);
    if (u.hasLocation) _place = GeoPlace(address: u.address, lat: u.lat!, lng: u.lng!);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final session = context.read<SessionController>();
    final updated = session.user!.copyWith(
      fullName: _name.text.trim(),
      phone: _phone.text.trim(),
      address: _place?.address,
      lat: _place?.lat,
      lng: _place?.lng,
    );
    final ok = await runWithFeedback(context, () => session.updateProfile(updated),
        success: 'Profile saved');
    if (ok && mounted) setState(() => _dirty = false);
  }

  Future<void> _signOut() async {
    final ok = await confirmDialog(context,
        title: 'Sign out?', message: 'You will need to sign in again.', confirmLabel: 'Sign out');
    if (!ok || !mounted) return;
    await runWithFeedback(context, () => signOutAndReset(context));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    if (user == null) return const SizedBox.shrink();
    final settings = context.watch<SettingsController>();
    final backend = context.read<Backend>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.pushed ? 'Profile & settings' : 'Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ContentWidth(
            maxWidth: 640,
            child: Form(
              key: _formKey,
              onChanged: () => setState(() => _dirty = true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: scheme.primaryContainer,
                          child: Text(initials(user.fullName),
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(color: scheme.onPrimaryContainer)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.fullName, style: theme.textTheme.titleLarge),
                              Text(user.email, style: theme.textTheme.bodyMedium),
                              const SizedBox(height: 6),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(
                                    user.isAdmin ? Icons.storefront : Icons.person_outline,
                                    size: 18),
                                label: Text(user.isAdmin ? 'Owner / Admin' : 'Customer'),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SectionTitle('Personal details'),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Full name', prefixIcon: Icon(Icons.badge_outlined)),
                    validator: (v) => Validators.required(v, 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Phone (WhatsApp)', prefixIcon: Icon(Icons.phone_outlined)),
                    validator: Validators.phone,
                  ),
                  const SizedBox(height: 12),
                  AddressPicker(
                    title: user.isAdmin ? 'Address' : 'Default delivery address',
                    value: _place,
                    onChanged: (p) => setState(() {
                      _place = p;
                      _dirty = true;
                    }),
                  ),
                  const SizedBox(height: 16),
                  LoadingButton(
                    label: 'Save changes',
                    icon: Icons.save_outlined,
                    onPressed: _dirty ? _save : null,
                  ),
                  const SectionTitle('Appearance'),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.brightness_auto_outlined)),
                      ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode_outlined)),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode_outlined)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (s) => settings.setThemeMode(s.first),
                  ),
                  const SectionTitle('About'),
                  Card(
                    child: Column(children: [
                      ListTile(
                        leading: Icon(backend.isDemo ? Icons.phone_android : Icons.cloud_done_outlined),
                        title: Text(backend.isDemo ? 'Demo mode (on-device data)' : 'Cloud mode (Supabase)'),
                        subtitle: Text(backend.isDemo
                            ? 'Add Supabase keys in env/env.json to sync data online.'
                            : 'Encrypted HTTPS connection'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.chat_outlined),
                        title: const Text('Contact Boss Botak'),
                        subtitle: const Text('WhatsApp / Call ${ShopConfig.displayPhone}'),
                        onTap: () => runWithFeedback(
                            context, () => context.read<ContactService>().whatsappShop()),
                      ),
                      const ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Boss Botak app v1.0.0'),
                        subtitle: Text('BIM30603 Mobile Application Development project'),
                      ),
                      if (backend is DemoBackend && user.isAdmin)
                        ListTile(
                          leading: const Icon(Icons.restart_alt),
                          title: const Text('Reset demo data'),
                          subtitle: const Text('Restore the sample products, orders and expenses'),
                          onTap: () async {
                            final ok = await confirmDialog(context,
                                title: 'Reset demo data?',
                                message: 'All demo changes will be lost and you will be signed out.',
                                confirmLabel: 'Reset',
                                destructive: true);
                            if (!ok || !context.mounted) return;
                            await backend.resetDemoData();
                            if (context.mounted) await signOutAndReset(context);
                          },
                        ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: Icon(Icons.logout, color: scheme.error),
                    label: Text('Sign out', style: TextStyle(color: scheme.error)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
