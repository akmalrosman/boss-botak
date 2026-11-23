import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app.dart';
import '../../../config/shop_config.dart';
import '../../../core/theme.dart';
import '../../../core/validators.dart';
import '../../../data/backend.dart';
import '../../../data/demo_seed.dart';
import '../../../state/session_controller.dart';
import '../../widgets/common.dart';

/// Screen 1 - Sign in / Register.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final session = context.read<SessionController>();
    await runWithFeedback(context, () async {
      if (_register) {
        await session.signUp(
          fullName: _name.text,
          phone: _phone.text,
          email: _email.text,
          password: _password.text,
        );
      } else {
        await session.signIn(_email.text, _password.text);
      }
    });
  }

  Future<void> _demoLogin(String email, String password) async {
    final session = context.read<SessionController>();
    await runWithFeedback(context, () => session.signIn(email, password));
  }

  Future<void> _forgotPassword() async {
    final error = Validators.email(_email.text);
    if (error != null) {
      showSnack(context, 'Type your email above first, then tap "Forgot password".');
      return;
    }
    await runWithFeedback(
      context,
      () => context.read<SessionController>().sendPasswordReset(_email.text),
      success: 'Password reset link sent to ${_email.text.trim()}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDemo = context.read<Backend>().isDemo;
    final wide = MediaQuery.sizeOf(context).width >= 760;

    final header = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      decoration: const BoxDecoration(
        color: BrandColors.leafGreen,
        image: DecorationImage(
          image: AssetImage('assets/images/combo.jpg'),
          fit: BoxFit.cover,
          opacity: 0.25,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BrandMark(size: 72),
            const SizedBox(height: 16),
            Text('Boss Botak',
                style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w900)),
            Text('Otak-Otak & Pepes - order fresh, frozen & ready for your open house.',
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text(ShopConfig.tagline,
                style: theme.textTheme.titleSmall?.copyWith(
                    color: BrandColors.sunYellow, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );

    final form = Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Sign in'), icon: Icon(Icons.login)),
                ButtonSegment(
                    value: true, label: Text('Register'), icon: Icon(Icons.person_add_alt)),
              ],
              selected: {_register},
              onSelectionChanged: (s) => setState(() => _register = s.first),
            ),
            const SizedBox(height: 20),
            if (_register) ...[
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                    labelText: 'Full name', prefixIcon: Icon(Icons.badge_outlined)),
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                    labelText: 'Phone (WhatsApp)',
                    hintText: '012-3456789',
                    prefixIcon: Icon(Icons.phone_outlined)),
                validator: Validators.phone,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                  labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
              validator: Validators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: _register ? 'At least 8 characters with letters and numbers' : null,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: _register
                  ? Validators.newPassword
                  : (v) => Validators.required(v, 'Password'),
            ),
            if (!_register && !isDemo)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: _forgotPassword, child: const Text('Forgot password?')),
              ),
            const SizedBox(height: 16),
            LoadingButton(
              label: _register ? 'Create account' : 'Sign in',
              icon: _register ? Icons.person_add_alt : Icons.login,
              onPressed: _submit,
            ),
            if (isDemo) ...[
              const SizedBox(height: 24),
              Card(
                color: scheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.science_outlined, color: scheme.onSecondaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Demo mode',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: scheme.onSecondaryContainer)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        'No cloud keys configured - data is stored on this device. '
                        'Try the app as:',
                        style: TextStyle(color: scheme.onSecondaryContainer),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.shopping_bag_outlined),
                            label: const Text('Customer'),
                            onPressed: () => _demoLogin(
                                DemoSeed.customerEmail, DemoSeed.customerPassword),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text('Boss (owner)'),
                            onPressed: () =>
                                _demoLogin(DemoSeed.adminEmail, DemoSeed.adminPassword),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final formPane = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: form,
      ),
    );

    return Scaffold(
      body: wide
          ? Row(
              children: [
                Expanded(child: SizedBox.expand(child: header)),
                Expanded(child: SafeArea(child: Center(child: formPane))),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  header,
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: form,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
