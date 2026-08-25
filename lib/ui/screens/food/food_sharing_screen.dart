import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/input_validators.dart';
import '../../../data/models/food_share.dart';
import '../../../state/auth_controller.dart';
import '../../../state/food_controller.dart';
import '../../../state/notification_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/form_scaffold.dart';
import '../../widgets/status_badge.dart';

/// LuL Offer food, show interest, reserve, confirm pickup.
class FoodSharingScreen extends StatefulWidget {
  const FoodSharingScreen({super.key});

  @override
  State<FoodSharingScreen> createState() => _FoodSharingScreenState();
}

class _FoodSharingScreenState extends State<FoodSharingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    await context.read<FoodController>().load(
      neighborhoodId: user.neighborhoodId,
      userId: user.id,
    );
  }

  /// Runs a controller action and shows the outcome.
  Future<void> _runAction(
    Future<bool> Function() action,
    String successMessage,
  ) async {
    final success = await action();
    if (!mounted) return;

    final controller = context.read<FoodController>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? successMessage : (controller.errorMessage ?? 'Aktion fehlgeschlagen.'),
        ),
        backgroundColor: success ? null : AppColors.danger,
      ),
    );
    final user = context.read<AuthController>().currentUser;
    if (user != null) {
      await context.read<NotificationController>().refresh(user.id);
    }
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateFoodOfferDialog(),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dein Angebot ist online. Danke fürs Teilen!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = context.watch<FoodController>();
    final user = context.watch<AuthController>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Lebensmittel anbieten'),
      ),
      body: food.isBusy
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gap * 1.5,
                  AppTheme.gap * 1.5,
                  AppTheme.gap * 1.5,
                  90,
                ),
                children: <Widget>[
                  SectionHeader(
                    title: '${food.availableCount} verfügbare Angebote',
                    subtitle: 'Rette Lebensmittel, bevor sie im Müll landen.',
                    trailing: TextButton.icon(
                      onPressed: food.toggleClosedVisibility,
                      icon: Icon(
                        food.hideClosedOffers
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 17,
                      ),
                      label: Text(
                        food.hideClosedOffers
                            ? 'Abgeholte zeigen'
                            : 'Abgeholte ausblenden',
                      ),
                    ),
                  ),
                  if (food.errorMessage != null)
                    ErrorBanner(message: food.errorMessage!, onRetry: _load),
                  if (food.offers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.restaurant_outlined,
                        title: 'Noch keine Lebensmittel im Angebot',
                        message: 'Zu viel eingekauft oder gekocht? '
                            'Biete es deinen Nachbarn an.',
                        actionLabel: 'Lebensmittel anbieten',
                        onAction: _openCreateDialog,
                      ),
                    )
                  else
                    for (final offer in food.offers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _FoodOfferCard(
                          offer: offer,
                          currentUserId: user.id,
                          onShowInterest: () => _runAction(
                            () => context.read<FoodController>().toggleInterest(
                              offer: offer,
                              currentUser: user,
                            ),
                            offer.currentUserIsInterested
                                ? 'Interesse zurückgezogen.'
                                : 'Interesse gemeldet – die anbietende Person wurde informiert.',
                          ),
                          onReserve: () => _runAction(
                            () => context.read<FoodController>().reserve(
                              offer: offer,
                              currentUser: user,
                            ),
                            'Reserviert! Vereinbart jetzt die Abholung.',
                          ),
                          onCancelReservation: () => _runAction(
                            () => context
                                .read<FoodController>()
                                .cancelReservation(
                                  offer: offer,
                                  currentUser: user,
                                ),
                            'Reservierung aufgehoben.',
                          ),
                          onMarkPickedUp: () => _runAction(
                            () => context.read<FoodController>().markAsPickedUp(
                              offer: offer,
                              currentUser: user,
                            ),
                            'Als abgeholt markiert.',
                          ),
                          onDelete: () => _runAction(
                            () => context.read<FoodController>().deleteOffer(
                              offer: offer,
                              currentUser: user,
                            ),
                            'Angebot gelöscht.',
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

/// LuL Card representing one food offer with all its available actions.
class _FoodOfferCard extends StatelessWidget {
  const _FoodOfferCard({
    required this.offer,
    required this.currentUserId,
    required this.onShowInterest,
    required this.onReserve,
    required this.onCancelReservation,
    required this.onMarkPickedUp,
    required this.onDelete,
  });

  final FoodShare offer;
  final int currentUserId;
  final VoidCallback onShowInterest;
  final VoidCallback onReserve;
  final VoidCallback onCancelReservation;
  final VoidCallback onMarkPickedUp;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool isOwner = offer.isOwnedBy(currentUserId);
    final bool isHolder = offer.isReservedBy(currentUserId);
    final int? daysLeft = DateFormatter.daysFromToday(offer.expiresOn);
    final bool isExpiringSoon = daysLeft != null && daysLeft <= 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gap * 1.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // --- Header -------------------------------------------------
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.categoryFood.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.restaurant_outlined,
                    color: AppColors.categoryFood,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        offer.title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOwner
                            ? 'Dein Angebot'
                            : 'von ${offer.ownerName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge.forStatus(
                  label: offer.status.label,
                  tone: offer.status.tone,
                  icon: switch (offer.status) {
                    FoodShareStatus.available => Icons.check_circle_outline,
                    FoodShareStatus.reserved => Icons.lock_clock,
                    FoodShareStatus.pickedUp => Icons.done_all,
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text(
              offer.description,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),

            // --- Meta row -----------------------------------------------
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MetaChip(
                  icon: Icons.scale_outlined,
                  label: offer.quantity,
                ),
                _MetaChip(
                  icon: Icons.event_busy_outlined,
                  label: DateFormatter.expiryHint(offer.expiresOn),
                  color: isExpiringSoon ? AppColors.statusReserved : null,
                ),
                if (offer.interestedCount > 0)
                  _MetaChip(
                    icon: Icons.favorite_outline,
                    label: '${offer.interestedCount} '
                        '${offer.interestedCount == 1 ? 'Interessent:in' : 'Interessent:innen'}',
                  ),
                if (offer.reservedByName != null)
                  _MetaChip(
                    icon: Icons.person_outline,
                    label: 'reserviert für ${offer.reservedByName}',
                    color: AppColors.statusReserved,
                  ),
              ],
            ),

            // --- Actions ------------------------------------------------
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: _buildActions(isOwner: isOwner, isHolder: isHolder),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the action buttons that make sense for the current user + status.
  List<Widget> _buildActions({required bool isOwner, required bool isHolder}) {
    // Closed offers are read only.
    if (offer.isClosed) {
      return <Widget>[
        if (isOwner)
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 17),
            label: const Text('Löschen'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          )
        else
          const Text(
            'Dieses Angebot wurde bereits abgeholt.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textDisabled),
          ),
      ];
    }

    if (isOwner) {
      return <Widget>[
        TextButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 17),
          label: const Text('Löschen'),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
        ),
        if (offer.isReserved) ...<Widget>[
          OutlinedButton.icon(
            onPressed: onCancelReservation,
            icon: const Icon(Icons.undo, size: 17),
            label: const Text('Reservierung aufheben'),
          ),
          FilledButton.icon(
            onPressed: onMarkPickedUp,
            icon: const Icon(Icons.done_all, size: 17),
            label: const Text('Abholung bestätigen'),
          ),
        ],
      ];
    }

    if (isHolder) {
      return <Widget>[
        const Text(
          'Du hast dieses Angebot reserviert.',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.statusReserved,
            fontWeight: FontWeight.w600,
          ),
        ),
        OutlinedButton.icon(
          onPressed: onCancelReservation,
          icon: const Icon(Icons.undo, size: 17),
          label: const Text('Reservierung zurückziehen'),
        ),
      ];
    }

    if (offer.isReserved) {
      return <Widget>[
        const Text(
          'Bereits von jemand anderem reserviert.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textDisabled),
        ),
      ];
    }

    // Available offer, viewed by another neighbour.
    return <Widget>[
      OutlinedButton.icon(
        onPressed: onShowInterest,
        icon: Icon(
          offer.currentUserIsInterested
              ? Icons.favorite
              : Icons.favorite_outline,
          size: 17,
        ),
        label: Text(
          offer.currentUserIsInterested
              ? 'Interesse zurückziehen'
              : 'Interesse bekunden',
        ),
      ),
      FilledButton.icon(
        onPressed: onReserve,
        icon: const Icon(Icons.bookmark_outline, size: 17),
        label: const Text('Reservieren'),
      ),
    ];
  }
}

/// LuL Information chip used inside the offer cards.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.color});

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

/// Dialog to create a new food offer.
class _CreateFoodOfferDialog extends StatefulWidget {
  const _CreateFoodOfferDialog();

  @override
  State<_CreateFoodOfferDialog> createState() => _CreateFoodOfferDialogState();
}

class _CreateFoodOfferDialogState extends State<_CreateFoodOfferDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  DateTime _expiryDate = DateTime.now().add(const Duration(days: 3));
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Haltbar bis',
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = context.read<AuthController>().requireUser;
    setState(() => _isSubmitting = true);

    final success = await context.read<FoodController>().createOffer(
      owner: user,
      title: _titleController.text,
      description: _descriptionController.text,
      quantity: _quantityController.text,
      expiresOn: DateFormatter.toIsoDate(_expiryDate),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<FoodController>().errorMessage ??
                'Das Angebot konnte nicht gespeichert werden.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'Lebensmittel anbieten',
      subtitle: 'Was möchtest du mit deiner Nachbarschaft teilen?',
      icon: Icons.restaurant_outlined,
      formKey: _formKey,
      submitLabel: 'Angebot einstellen',
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
      fields: <Widget>[
        AppTextField(
          controller: _titleController,
          label: 'Was bietest du an?',
          hint: 'z. B. Sauerteigbrot, Tomaten aus dem Garten',
          icon: Icons.shopping_basket_outlined,
          validator: (value) =>
              InputValidators.minLength(value, 3, field: 'Der Titel'),
        ),
        AppTextField(
          controller: _quantityController,
          label: 'Menge',
          hint: 'z. B. 2 Laibe, 3 kg, 1 Blech',
          icon: Icons.scale_outlined,
          validator: (value) =>
              InputValidators.required(value, field: 'Die Menge'),
        ),
        AppTextField(
          controller: _descriptionController,
          label: 'Beschreibung',
          icon: Icons.notes_outlined,
          maxLines: 4,
          validator: (value) =>
              InputValidators.minLength(value, 5, field: 'Die Beschreibung'),
        ),
        InkWell(
          onTap: _pickExpiryDate,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Haltbar bis',
              prefixIcon: Icon(Icons.event_outlined, size: 20),
            ),
            child: Text(
              DateFormatter.prettyDate(DateFormatter.toIsoDate(_expiryDate)),
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
