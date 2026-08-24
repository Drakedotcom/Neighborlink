import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/input_validators.dart';
import '../../../data/models/neighborhood.dart';
import '../../../data/repositories/neighborhood_repository.dart';
import '../../../state/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/form_scaffold.dart';

///LuS
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const String routeName = '/register';

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordRepeatController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  final NeighborhoodRepository _neighborhoodRepository =
      const NeighborhoodRepository();

  bool _obscurePassword = true;
  Neighborhood? _matchingNeighborhood;

  @override
  void initState() {
    super.initState();
    _postalCodeController.addListener(_onPostalCodeChanged);
  }

  @override
  void dispose() {
    _postalCodeController.removeListener(_onPostalCodeChanged);
    for (final controller in <TextEditingController>[
      _nameController,
      _emailController,
      _passwordController,
      _passwordRepeatController,
      _streetController,
      _postalCodeController,
      _cityController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  ///on input check neighborhood
  Future<void> _onPostalCodeChanged() async {
    final postalCode = _postalCodeController.text.trim();
    if (postalCode.length != 5) {
      if (_matchingNeighborhood != null) {
        setState(() => _matchingNeighborhood = null);
      }
      return;
    }

    try {
      final all = await _neighborhoodRepository.loadAll();
      final match = all
          .where((neighborhood) => neighborhood.postalCode == postalCode)
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        _matchingNeighborhood = match;
        ///city pre fill
        if (match != null && _cityController.text.trim().isEmpty) {
          _cityController.text = match.cityName;
        }
      });
    } on Object {
      if (mounted) setState(() => _matchingNeighborhood = null);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthController>();
    final success = await auth.register(
      fullName: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      streetAddress: _streetController.text,
      postalCode: _postalCodeController.text,
      cityName: _cityController.text,
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konto erstellt. Willkommen in deiner Nachbarschaft!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konto erstellen'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.gap * 1.5),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.gap * 1.5),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Werde Teil deiner Nachbarschaft',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Deine Postleitzahl entscheidet, welcher Nachbarschaft '
                        'du zugeordnet wirst.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppTheme.gap * 1.25),

                      ///person
                      AppTextField(
                        controller: _nameController,
                        label: 'Vor- und Nachname',
                        icon: Icons.person_outline,
                        textInputAction: TextInputAction.next,
                        validator: (value) => InputValidators.minLength(
                          value,
                          3,
                          field: 'Der Name',
                        ),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _emailController,
                        label: 'E-Mail',
                        icon: Icons.alternate_email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: InputValidators.email,
                      ),

                      ///credentials
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _passwordController,
                        label: 'Passwort',
                        hint: 'Mindestens 8 Zeichen, Buchstaben und Ziffern',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        validator: InputValidators.password,
                        suffix: IconButton(
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
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _passwordRepeatController,
                        label: 'Passwort wiederholen',
                        icon: Icons.lock_reset_outlined,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        validator: (value) => InputValidators.matches(
                          value,
                          _passwordController.text,
                          field: 'Die Passwörter',
                        ),
                      ),

                      ///address
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _streetController,
                        label: 'Straße und Hausnummer',
                        icon: Icons.home_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (value) => InputValidators.minLength(
                          value,
                          4,
                          field: 'Die Adresse',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 150,
                            child: AppTextField(
                              controller: _postalCodeController,
                              label: 'PLZ',
                              icon: Icons.pin_drop_outlined,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              validator: InputValidators.postalCode,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _cityController,
                              label: 'Ort',
                              icon: Icons.location_city_outlined,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: (value) => InputValidators.required(
                                value,
                                field: 'Der Ort',
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      _NeighborhoodPreview(
                        postalCode: _postalCodeController.text.trim(),
                        neighborhood: _matchingNeighborhood,
                      ),

                      if (auth.errorMessage != null) ...<Widget>[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall,
                            ),
                          ),
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                            ),
                          ),
                        ),
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
                            : const Text('Registrieren'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

///live neighborhood search for postal code
class _NeighborhoodPreview extends StatelessWidget {
  const _NeighborhoodPreview({
    required this.postalCode,
    required this.neighborhood,
  });

  final String postalCode;
  final Neighborhood? neighborhood;

  @override
  Widget build(BuildContext context) {
    final bool hasValidPostalCode = postalCode.length == 5;
    final Neighborhood? match = neighborhood;

    final (IconData icon, String text, Color color) = switch ((
      hasValidPostalCode,
      match,
    )) {
      (false, _) => (
        Icons.info_outline,
        'Gib eine fünfstellige Postleitzahl ein, um deine Nachbarschaft zu finden.',
        AppColors.textSecondary,
      ),
      (true, null) => (
        Icons.auto_awesome_outlined,
        'Für $postalCode gibt es noch keine Nachbarschaft, du legst sie an!',
        AppColors.info,
      ),
      (true, final found) => (
        Icons.groups_2_outlined,
        '${found!.displayName}: ${found.memberCount} '
            '${found.memberCount == 1 ? 'Nachbar:in wartet' : 'Nachbar:innen warten'} '
            'schon auf dich.',
        AppColors.primary,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}