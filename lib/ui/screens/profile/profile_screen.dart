import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/input_validators.dart';
import '../../../state/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/form_scaffold.dart';
import '../../widgets/stat_tile.dart';

///LuS
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _streetController;
  late final TextEditingController _aboutController;

  bool _showLog = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().currentUser;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _streetController = TextEditingController(text: user?.streetAddress ?? '');
    _aboutController = TextEditingController(text: user?.aboutMe ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthController>();
    final success = await auth.updateProfile(
      fullName: _nameController.text,
      streetAddress: _streetController.text,
      aboutMe: _aboutController.text,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Profil gespeichert.'
              : (auth.errorMessage ?? 'Speichern fehlgeschlagen.'),
        ),
        backgroundColor: success ? null : AppColors.danger,
      ),
    );
  }

  Future<void> _openPasswordDialog() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwort geändert.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(AppTheme.gap * 1.5),
      children: <Widget>[
        ///identity header
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.gap * 1.5),
            child: Row(
              children: <Widget>[
                InitialsAvatar(initials: user.initials, size: 64),
                const SizedBox(width: AppTheme.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.fullName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _ProfilePill(
                            icon: Icons.pin_drop_outlined,
                            label: '${user.postalCode} · ${user.streetAddress}',
                          ),
                          _ProfilePill(
                            icon: Icons.calendar_today_outlined,
                            label: 'Mitglied seit '
                                '${DateFormatter.prettyDate(DateFormatter.toIsoDate(user.createdAt))}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppTheme.gap * 1.5),

        ///editable data
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.gap * 1.5),
            child: Form(
              key: _profileFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SectionHeader(
                    title: 'Persönliche Daten',
                    subtitle: 'Diese Angaben sehen deine Nachbar:innen.',
                  ),
                  AppTextField(
                    controller: _nameController,
                    label: 'Vor- und Nachname',
                    icon: Icons.person_outline,
                    validator: (value) =>
                        InputValidators.minLength(value, 3, field: 'Der Name'),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _streetController,
                    label: 'Straße und Hausnummer',
                    icon: Icons.home_outlined,
                    validator: (value) => InputValidators.minLength(
                      value,
                      4,
                      field: 'Die Adresse',
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _aboutController,
                    label: 'Über mich (optional)',
                    hint: 'Was möchtest du deiner Nachbarschaft mitteilen?',
                    icon: Icons.notes_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  ///postal and email immutable
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'E-Mail-Adresse und Postleitzahl können nicht '
                            'geändert werden – sie bestimmen deinen Login und '
                            'deine Nachbarschaft.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.gap),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: _openPasswordDialog,
                        icon: const Icon(Icons.key_outlined, size: 17),
                        label: const Text('Passwort ändern'),
                      ),
                      FilledButton.icon(
                        onPressed: auth.isBusy ? null : _saveProfile,
                        icon: const Icon(Icons.save_outlined, size: 17),
                        label: const Text('Speichern'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: AppTheme.gap * 1.5),

        ///developer/presentation tools
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.gap * 1.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(
                  title: 'Anwendungsprotokoll',
                  subtitle: 'Die letzten Log-Einträge der laufenden Sitzung.',
                  trailing: TextButton.icon(
                    onPressed: () => setState(() => _showLog = !_showLog),
                    icon: Icon(
                      _showLog ? Icons.visibility_off_outlined : Icons.terminal,
                      size: 17,
                    ),
                    label: Text(_showLog ? 'Ausblenden' : 'Anzeigen'),
                  ),
                ),
                if (_showLog) _LogViewer(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LogViewer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final records = AppLogger.instance.records.reversed.take(60).toList();

    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Es wurden noch keine Log-Einträge erzeugt.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textDisabled),
        ),
      );
    }

    return Container(
      height: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14201B),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: ListView.builder(
        itemCount: records.length,
        itemBuilder: (context, index) {
          final record = records[index];
          final color = switch (record.level) {
            LogLevel.error => const Color(0xFFFF8A80),
            LogLevel.warning => const Color(0xFFFFD180),
            LogLevel.info => const Color(0xFFA5D6A7),
            LogLevel.debug => const Color(0xFF8FA69B),
          };
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              record.toString(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: color,
                height: 1.35,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _repeatController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    final auth = context.read<AuthController>();
    final success = await auth.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Änderung fehlgeschlagen.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'Passwort ändern',
      subtitle: 'Zur Sicherheit brauchen wir dein aktuelles Passwort.',
      icon: Icons.key_outlined,
      formKey: _formKey,
      submitLabel: 'Passwort ändern',
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
      fields: <Widget>[
        AppTextField(
          controller: _currentController,
          label: 'Aktuelles Passwort',
          icon: Icons.lock_outline,
          obscureText: true,
          validator: (value) =>
              InputValidators.required(value, field: 'Das aktuelle Passwort'),
        ),
        AppTextField(
          controller: _newController,
          label: 'Neues Passwort',
          icon: Icons.lock_reset_outlined,
          obscureText: true,
          validator: InputValidators.password,
        ),
        AppTextField(
          controller: _repeatController,
          label: 'Neues Passwort wiederholen',
          icon: Icons.lock_reset_outlined,
          obscureText: true,
          validator: (value) => InputValidators.matches(
            value,
            _newController.text,
            field: 'Die Passwörter',
          ),
        ),
      ],
    );
  }
}
