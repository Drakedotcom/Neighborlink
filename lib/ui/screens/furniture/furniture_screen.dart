import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/input_validators.dart';
import '../../../data/models/furniture_offer.dart';
import '../../../state/auth_controller.dart';
import '../../../state/furniture_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/form_scaffold.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/status_badge.dart';

/// LuL Publish items, collect requests, hand them over.
class FurnitureScreen extends StatefulWidget {
  const FurnitureScreen({super.key});

  @override
  State<FurnitureScreen> createState() => _FurnitureScreenState();
}

class _FurnitureScreenState extends State<FurnitureScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    await context.read<FurnitureController>().load(
      neighborhoodId: user.neighborhoodId,
      userId: user.id,
    );
  }

  Future<void> _runAction(
    Future<bool> Function() action,
    String successMessage,
  ) async {
    final success = await action();
    if (!mounted) return;
    final controller = context.read<FurnitureController>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? successMessage
              : (controller.errorMessage ?? 'Aktion fehlgeschlagen.'),
        ),
        backgroundColor: success ? null : AppColors.danger,
      ),
    );
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateFurnitureDialog(),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dein Gegenstand sucht jetzt ein neues Zuhause.')),
      );
    }
  }

  /// Opens the request dialog for a neighbour who wants the item.
  Future<void> _openRequestDialog(FurnitureOffer offer) async {
    final messageController = TextEditingController(
      text: 'Hallo, ich hätte Interesse an "${offer.title}".',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Anfrage senden'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: messageController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Nachricht an die anbietende Person',
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
            child: const Text('Anfrage senden'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      messageController.dispose();
      return;
    }

    final user = context.read<AuthController>().requireUser;
    await _runAction(
      () => context.read<FurnitureController>().sendRequest(
        offer: offer,
        currentUser: user,
        message: messageController.text,
      ),
      'Anfrage gesendet.',
    );
    messageController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final furniture = context.watch<FurnitureController>();
    final user = context.watch<AuthController>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Gegenstand verschenken'),
      ),
      body: furniture.isBusy
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
                    title: '${furniture.availableCount} Gegenstände verfügbar',
                    subtitle: 'Weitergeben statt wegwerfen – '
                        'gut für die Nachbarschaft und die Umwelt.',
                  ),
                  if (furniture.errorMessage != null)
                    ErrorBanner(
                      message: furniture.errorMessage!,
                      onRetry: _load,
                    ),
                  if (furniture.offers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.chair_outlined,
                        title: 'Noch nichts zu verschenken',
                        message: 'Ein Regal, ein Stuhl, eine Lampe – '
                            'jemand in der Nachbarschaft sucht bestimmt danach.',
                        actionLabel: 'Gegenstand verschenken',
                        onAction: _openCreateDialog,
                      ),
                    )
                  else
                    for (final offer in furniture.offers)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _FurnitureCard(
                          offer: offer,
                          currentUserId: user.id,
                          onRequest: () => _openRequestDialog(offer),
                          onWithdraw: () => _runAction(
                            () => context
                                .read<FurnitureController>()
                                .withdrawRequest(
                                  offer: offer,
                                  currentUser: user,
                                ),
                            'Anfrage zurückgezogen.',
                          ),
                          onMarkGivenAway: () => _runAction(
                            () => context
                                .read<FurnitureController>()
                                .markAsGivenAway(offer: offer, owner: user),
                            'Als vergeben markiert.',
                          ),
                          onDelete: () => _runAction(
                            () => context
                                .read<FurnitureController>()
                                .deleteOffer(offer: offer, owner: user),
                            'Angebot gelöscht.',
                          ),
                          onAcceptRequest: (request) => _runAction(
                            () => context
                                .read<FurnitureController>()
                                .acceptRequest(
                                  offer: offer,
                                  owner: user,
                                  request: request,
                                ),
                            '${request.requesterName} hat die Zusage erhalten.',
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

/// LuL Card for one furniture offer, including the expandable request list.
class _FurnitureCard extends StatefulWidget {
  const _FurnitureCard({
    required this.offer,
    required this.currentUserId,
    required this.onRequest,
    required this.onWithdraw,
    required this.onMarkGivenAway,
    required this.onDelete,
    required this.onAcceptRequest,
  });

  final FurnitureOffer offer;
  final int currentUserId;
  final VoidCallback onRequest;
  final VoidCallback onWithdraw;
  final VoidCallback onMarkGivenAway;
  final VoidCallback onDelete;
  final ValueChanged<FurnitureRequest> onAcceptRequest;

  @override
  State<_FurnitureCard> createState() => _FurnitureCardState();
}

class _FurnitureCardState extends State<_FurnitureCard> {
  bool _showRequests = false;

  /// Loads the request list the first time the owner expands it.
  Future<void> _toggleRequests() async {
    setState(() => _showRequests = !_showRequests);
    if (_showRequests) {
      await context.read<FurnitureController>().loadRequests(widget.offer.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final bool isOwner = offer.isOwnedBy(widget.currentUserId);
    final requests = context.watch<FurnitureController>().requestsFor(offer.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gap * 1.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.categoryFurniture.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chair_outlined,
                    color: AppColors.categoryFurniture,
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
                        '${isOwner ? 'Dein Angebot' : 'von ${offer.ownerName}'}'
                        ' · eingestellt ${DateFormatter.relative(offer.createdAt)}',
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

            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoPill(
                  icon: Icons.verified_outlined,
                  label: offer.conditionLabel,
                ),
                if (offer.reservedByName != null)
                  _InfoPill(
                    icon: Icons.person_outline,
                    label: '${offer.status == FurnitureStatus.givenAway ? 'vergeben an' : 'reserviert für'} '
                        '${offer.reservedByName}',
                    color: offer.status == FurnitureStatus.givenAway
                        ? AppColors.statusClosed
                        : AppColors.statusReserved,
                  ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            if (isOwner) ...<Widget>[
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  if (offer.openRequestCount > 0 || _showRequests)
                    TextButton.icon(
                      onPressed: _toggleRequests,
                      icon: Icon(
                        _showRequests ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                      ),
                      label: Text(
                        '${offer.openRequestCount} offene '
                        '${offer.openRequestCount == 1 ? 'Anfrage' : 'Anfragen'}',
                      ),
                    )
                  else
                    const Text(
                      'Noch keine Anfragen.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: const Text('Löschen'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                      ),
                      if (offer.status == FurnitureStatus.reserved)
                        FilledButton.icon(
                          onPressed: widget.onMarkGivenAway,
                          icon: const Icon(Icons.done_all, size: 17),
                          label: const Text('Übergabe bestätigen'),
                        ),
                    ],
                  ),
                ],
              ),
              if (_showRequests) ...<Widget>[
                const SizedBox(height: 8),
                if (requests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Es liegen keine Anfragen vor.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  )
                else
                  for (final request in requests)
                    _RequestRow(
                      request: request,
                      canAccept:
                          offer.status == FurnitureStatus.available &&
                          request.status == FurnitureRequestStatus.pending,
                      onAccept: () => widget.onAcceptRequest(request),
                    ),
              ],
            ]
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (offer.isClosed)
                    const Text(
                      'Dieser Gegenstand wurde bereits vergeben.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textDisabled,
                      ),
                    )
                  else if (offer.reservedById == widget.currentUserId)
                    const Text(
                      'Zugesagt! Meldet euch zur Übergabe.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.statusReserved,
                      ),
                    )
                  else if (offer.status == FurnitureStatus.reserved)
                    const Text(
                      'Bereits reserviert.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textDisabled,
                      ),
                    )
                  else if (offer.currentUserHasRequested)
                    OutlinedButton.icon(
                      onPressed: widget.onWithdraw,
                      icon: const Icon(Icons.undo, size: 17),
                      label: const Text('Anfrage zurückziehen'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: widget.onRequest,
                      icon: const Icon(Icons.send_outlined, size: 17),
                      label: const Text('Anfrage senden'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// One request row inside the owner's expanded list.
class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.request,
    required this.canAccept,
    required this.onAccept,
  });

  final FurnitureRequest request;
  final bool canAccept;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            initials: _initialsOf(request.requesterName),
            size: 32,
            color: AppColors.categoryFurniture,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      request.requesterName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormatter.relative(request.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                      ),
                    ),
                  ],
                ),
                if (request.message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      request.message,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (canAccept)
            FilledButton(
              onPressed: onAccept,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              ),
              child: const Text('Zusagen'),
            )
          else
            Chip(
              label: Text(request.status.label),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// LuL Small labelled pill.
class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label, this.color});

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

/// LuL Dialog to publish a new furniture offer.
class _CreateFurnitureDialog extends StatefulWidget {
  const _CreateFurnitureDialog();

  @override
  State<_CreateFurnitureDialog> createState() => _CreateFurnitureDialogState();
}

class _CreateFurnitureDialogState extends State<_CreateFurnitureDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  static const List<String> _conditions = <String>[
    'Neuwertig',
    'Gebraucht, sehr gut',
    'Gebraucht, gut',
    'Gebraucht, mit Gebrauchsspuren',
    'Bastlerstück',
  ];

  String _condition = _conditions[1];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = context.read<AuthController>().requireUser;
    setState(() => _isSubmitting = true);

    final success = await context.read<FurnitureController>().createOffer(
      owner: user,
      title: _titleController.text,
      description: _descriptionController.text,
      conditionLabel: _condition,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<FurnitureController>().errorMessage ??
                'Das Angebot konnte nicht gespeichert werden.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'Gegenstand verschenken',
      subtitle: 'Was soll ein neues Zuhause finden?',
      icon: Icons.chair_outlined,
      formKey: _formKey,
      submitLabel: 'Angebot einstellen',
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
      fields: <Widget>[
        AppTextField(
          controller: _titleController,
          label: 'Gegenstand',
          hint: 'z. B. Bücherregal, Schreibtisch',
          icon: Icons.chair_outlined,
          validator: (value) =>
              InputValidators.minLength(value, 3, field: 'Der Titel'),
        ),
        DropdownButtonFormField<String>(
          initialValue: _condition,
          decoration: const InputDecoration(
            labelText: 'Zustand',
            prefixIcon: Icon(Icons.verified_outlined, size: 20),
          ),
          items: <DropdownMenuItem<String>>[
            for (final condition in _conditions)
              DropdownMenuItem<String>(value: condition, child: Text(condition)),
          ],
          onChanged: (value) =>
              setState(() => _condition = value ?? _conditions.first),
        ),
        AppTextField(
          controller: _descriptionController,
          label: 'Beschreibung',
          hint: 'Maße, Farbe, Besonderheiten, Abholhinweise ...',
          icon: Icons.notes_outlined,
          maxLines: 5,
          validator: (value) =>
              InputValidators.minLength(value, 10, field: 'Die Beschreibung'),
        ),
      ],
    );
  }
}
