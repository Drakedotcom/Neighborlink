import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/models/care_request.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_tile.dart';

/// LuL Small labelled pill used inside the care cards.
class CarePill extends StatelessWidget {
  const CarePill({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: effectiveColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// LuL Expandable list of the neighbours who offered to help.
class CareOfferList extends StatelessWidget {
  const CareOfferList({
    super.key,
    required this.offers,
    required this.accentColor,
  });

  final List<CareOffer> offers;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Bisher hat noch niemand Hilfe angeboten.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textDisabled),
        ),
      );
    }

    return Column(
      children: <Widget>[
        for (final offer in offers)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InitialsAvatar(
                  initials: initialsOf(offer.helperName),
                  size: 30,
                  color: accentColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            offer.helperName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormatter.relative(offer.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textDisabled,
                            ),
                          ),
                        ],
                      ),
                      if (offer.message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            offer.message,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Two letter initials of a full name; shared by both care screens.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

/// Asks the helper for an optional message before the offer is sent.
Future<String?> askForHelpMessage(
  BuildContext context, {
  required String title,
  required String prefilledMessage,
}) async {
  final controller = TextEditingController(text: prefilledMessage);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Nachricht (optional)',
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Hilfe anbieten'),
        ),
      ],
    ),
  );

  final message = confirmed == true ? controller.text : null;
  controller.dispose();
  return message;
}
