import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// LuL modal dialog with title, scrollable form body, actions.
class FormDialog extends StatelessWidget {
  const FormDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.formKey,
    required this.fields,
    required this.submitLabel,
    required this.onSubmit,
    this.isSubmitting = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final String submitLabel;
  final VoidCallback onSubmit;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppTheme.gap),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildHeader(context),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.gap * 1.25),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _withSpacing(fields),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.gap * 1.25),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.gap),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          TextButton(
            onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: isSubmitting ? null : onSubmit,
            child: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(submitLabel),
          ),
        ],
      ),
    );
  }

  /// consistent vertical gap between form fields
  List<Widget> _withSpacing(List<Widget> widgets) {
    final spaced = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      spaced.add(widgets[i]);
      if (i < widgets.length - 1) spaced.add(const SizedBox(height: 14));
    }
    return spaced;
  }
}

/// LuL text field with default decoration.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.readOnly = false,
    this.onTap,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: obscureText ? 1 : maxLines,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      readOnly: readOnly,
      onTap: onTap,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        suffixIcon: suffix,
      ),
    );
  }
}
