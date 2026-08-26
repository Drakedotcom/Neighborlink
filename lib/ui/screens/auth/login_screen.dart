import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/input_validators.dart';
import '../../../data/database/demo_data_seeder.dart';
import '../../../state/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/form_scaffold.dart';
import 'register_screen.dart';

///LuS
///entry point when no session exists
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const String routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  ///open session
  Future<void> _submit() async {
    final auth = context.read<AuthController>();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await auth.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Willkommen zurück, ${auth.requireUser.firstName}!')),
      );
    }
  }

  void _fillDemoCredentials() {
    _emailController.text = DemoDataSeeder.demoEmail;
    _passwordController.text = DemoDataSeeder.demoPassword;
    context.read<AuthController>().clearError();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.gap * 1.5),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _BrandHeader(),
                const SizedBox(height: AppTheme.gap * 1.5),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.gap * 1.5),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'Anmelden',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Melde dich an, um deine Nachbarschaft zu sehen.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppTheme.gap * 1.25),

                          AppTextField(
                            controller: _emailController,
                            label: 'E-Mail',
                            icon: Icons.alternate_email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: InputValidators.email,
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: _passwordController,
                            label: 'Passwort',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            validator: (value) => InputValidators.required(
                              value,
                              field: 'Passwort',
                            ),
                            suffix: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Passwort anzeigen'
                                  : 'Passwort verbergen',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),

                          if (auth.errorMessage != null) ...<Widget>[
                            const SizedBox(height: 14),
                            _InlineError(message: auth.errorMessage!),
                          ],

                          const SizedBox(height: AppTheme.gap * 1.25),
                          FilledButton(
                            onPressed: auth.isBusy ? null : _submit,
                            child: auth.isBusy
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Anmelden'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: auth.isBusy
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  ),
                            child: const Text('Noch kein Konto? Jetzt registrieren'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.gap),
                _DemoHint(onUse: auth.isBusy ? null : _fillDemoCredentials),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

///logo, name, slogan
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.diversity_3, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 14),
        const Text(
          'NeighborLink',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Gemeinsam. Lokal. Nachhaltig.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

///card for demo
class _DemoHint extends StatelessWidget {
  const _DemoHint({this.onUse});

  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.science_outlined, size: 20, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Demo-Zugang',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.primaryDark,
                  ),
                ),
                Text(
                  '${DemoDataSeeder.demoEmail} · ${DemoDataSeeder.demoPassword}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onUse, child: const Text('Übernehmen')),
        ],
      ),
    );
  }
}