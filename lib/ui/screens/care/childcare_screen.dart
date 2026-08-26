import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/input_validators.dart';
import '../../../data/models/care_request.dart';
import '../../../state/auth_controller.dart';
import '../../../state/care_controller.dart';
import '../../../state/neighborhood_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/form_scaffold.dart';
import '../../widgets/status_badge.dart';
import 'care_widgets.dart';

/// LuL Request support and offer help to neighbours.
class ChildcareScreen extends StatefulWidget {
  const ChildcareScreen({super.key});

  @override
  State<ChildcareScreen> createState() => _ChildcareScreenState();
}

class _ChildcareScreenState extends State<ChildcareScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    await context.read<CareController>().load(
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
    final controller = context.read<CareController>();
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
      builder: (_) => const _CreateChildcareDialog(),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anfrage veröffentlicht.')),
      );
    }
  }

  Future<void> _offerHelp(ChildcareRequest request) async {
    final message = await askForHelpMessage(
      context,
      title: 'Betreuung anbieten',
      prefilledMessage: 'Hallo, ich kann am '
          '${DateFormatter.prettyDate(request.careDate)} einspringen.',
    );
    if (message == null || !mounted) return;

    final user = context.read<AuthController>().requireUser;
    await _runAction(
      () => context.read<CareController>().offerChildcareHelp(
        request: request,
        helper: user,
        message: message,
      ),
      'Danke! Deine Hilfe wurde weitergeleitet.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final care = context.watch<CareController>();
    final user = context.watch<AuthController>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Betreuung anfragen'),
      ),
      body: care.isBusy
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
                    title: '${care.openChildcareCount} offene Anfragen',
                    subtitle: 'Kurzfristig ein Termin dazwischen? '
                        'Die Nachbarschaft hilft aus.',
                  ),
                  if (care.errorMessage != null)
                    ErrorBanner(message: care.errorMessage!, onRetry: _load),
                  if (care.childcareRequests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.child_care_outlined,
                        title: 'Keine Betreuungsanfragen',
                        message: 'Stelle eine Anfrage, wenn du kurzfristig '
                            'Unterstützung brauchst.',
                        actionLabel: 'Betreuung anfragen',
                        onAction: _openCreateDialog,
                      ),
                    )
                  else
                    for (final request in care.childcareRequests)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ChildcareCard(
                          request: request,
                          currentUserId: user.id,
                          onOfferHelp: () => _offerHelp(request),
                          onWithdrawHelp: () => _runAction(
                            () => context
                                .read<CareController>()
                                .withdrawChildcareHelp(
                                  request: request,
                                  helper: user,
                                ),
                            'Angebot zurückgezogen.',
                          ),
                          onClose: () => _runAction(
                            () => context
                                .read<CareController>()
                                .closeChildcareRequest(
                                  request: request,
                                  requester: user,
                                ),
                            'Anfrage als geklärt markiert.',
                          ),
                          onDelete: () => _runAction(
                            () => context
                                .read<CareController>()
                                .deleteChildcareRequest(
                                  request: request,
                                  requester: user,
                                ),
                            'Anfrage gelöscht.',
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

/// LuL Card for one child care request.
class _ChildcareCard extends StatefulWidget {
  const _ChildcareCard({
    required this.request,
    required this.currentUserId,
    required this.onOfferHelp,
    required this.onWithdrawHelp,
    required this.onClose,
    required this.onDelete,
  });

  final ChildcareRequest request;
  final int currentUserId;
  final VoidCallback onOfferHelp;
  final VoidCallback onWithdrawHelp;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  @override
  State<_ChildcareCard> createState() => _ChildcareCardState();
}

class _ChildcareCardState extends State<_ChildcareCard> {
  bool _showOffers = false;

  Future<void> _toggleOffers() async {
    setState(() => _showOffers = !_showOffers);
    if (_showOffers) {
      await context.read<CareController>().loadOffers(
        widget.request.id,
        isChildcare: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final bool isOwner = request.isCreatedBy(widget.currentUserId);
    final offers = context.watch<CareController>().offersFor(
      request.id,
      isChildcare: true,
    );

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
                    color: AppColors.categoryChildCare.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.child_care_outlined,
                    color: AppColors.categoryChildCare,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        DateFormatter.prettyDate(request.careDate),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOwner
                            ? 'Deine Anfrage'
                            : 'Anfrage von ${request.requesterName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge.forStatus(
                  label: request.status.label,
                  tone: request.status.tone,
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text(
              request.description,
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
                CarePill(icon: Icons.schedule_outlined, label: request.careTime),
                CarePill(
                  icon: Icons.volunteer_activism_outlined,
                  label: '${request.offerCount} '
                      '${request.offerCount == 1 ? 'Angebot' : 'Angebote'}',
                  color: request.offerCount > 0
                      ? AppColors.statusAvailable
                      : null,
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                if (request.offerCount > 0)
                  TextButton.icon(
                    onPressed: _toggleOffers,
                    icon: Icon(
                      _showOffers ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    label: Text(
                      _showOffers ? 'Angebote ausblenden' : 'Angebote ansehen',
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: _buildActions(isOwner: isOwner),
                ),
              ],
            ),
            if (_showOffers)
              CareOfferList(
                offers: offers,
                accentColor: AppColors.categoryChildCare,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions({required bool isOwner}) {
    final request = widget.request;

    if (isOwner) {
      return <Widget>[
        TextButton.icon(
          onPressed: widget.onDelete,
          icon: const Icon(Icons.delete_outline, size: 17),
          label: const Text('Löschen'),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
        ),
        if (request.isOpen)
          FilledButton.icon(
            onPressed: widget.onClose,
            icon: const Icon(Icons.check, size: 17),
            label: const Text('Als geklärt markieren'),
          ),
      ];
    }

    if (!request.isOpen) {
      return <Widget>[
        const Text(
          'Diese Anfrage ist bereits abgedeckt.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textDisabled),
        ),
      ];
    }

    if (request.currentUserHasOffered) {
      return <Widget>[
        const Text(
          'Du hast Hilfe angeboten.',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.statusAvailable,
          ),
        ),
        OutlinedButton.icon(
          onPressed: widget.onWithdrawHelp,
          icon: const Icon(Icons.undo, size: 17),
          label: const Text('Zurückziehen'),
        ),
      ];
    }

    return <Widget>[
      FilledButton.icon(
        onPressed: widget.onOfferHelp,
        icon: const Icon(Icons.volunteer_activism_outlined, size: 17),
        label: const Text('Hilfe anbieten'),
      ),
    ];
  }
}

/// LuL Dialog to create a child care request.
class _CreateChildcareDialog extends StatefulWidget {
  const _CreateChildcareDialog();

  @override
  State<_CreateChildcareDialog> createState() => _CreateChildcareDialogState();
}

class _CreateChildcareDialogState extends State<_CreateChildcareDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _timeController = TextEditingController(
    text: '16:00 – 19:00',
  );
  final TextEditingController _descriptionController = TextEditingController();

  DateTime _careDate = DateTime.now().add(const Duration(days: 2));
  bool _isSubmitting = false;

  @override
  void dispose() {
    _timeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = context.read<AuthController>().requireUser;
    final neighborIds = context.read<NeighborhoodController>().memberIds;

    setState(() => _isSubmitting = true);
    final success = await context.read<CareController>().createChildcareRequest(
      requester: user,
      careDate: DateFormatter.toIsoDate(_careDate),
      careTime: _timeController.text,
      description: _descriptionController.text,
      neighborIds: neighborIds,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<CareController>().errorMessage ??
                'Die Anfrage konnte nicht gespeichert werden.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'Kinderbetreuung anfragen',
      subtitle: 'Wann brauchst du Unterstützung?',
      icon: Icons.child_care_outlined,
      formKey: _formKey,
      submitLabel: 'Anfrage stellen',
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
      fields: <Widget>[
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _careDate,
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: now.add(const Duration(days: 365)),
              helpText: 'Datum der Betreuung',
            );
            if (picked != null) setState(() => _careDate = picked);
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Datum',
              prefixIcon: Icon(Icons.event_outlined, size: 20),
            ),
            child: Text(
              DateFormatter.prettyDate(DateFormatter.toIsoDate(_careDate)),
            ),
          ),
        ),
        AppTextField(
          controller: _timeController,
          label: 'Uhrzeit / Zeitraum',
          hint: 'z. B. 16:00 – 19:00',
          icon: Icons.schedule_outlined,
          validator: (value) =>
              InputValidators.required(value, field: 'Die Uhrzeit'),
        ),
        AppTextField(
          controller: _descriptionController,
          label: 'Beschreibung',
          hint: 'Alter der Kinder, Anlass, Besonderheiten ...',
          icon: Icons.notes_outlined,
          maxLines: 5,
          validator: (value) =>
              InputValidators.minLength(value, 10, field: 'Die Beschreibung'),
        ),
      ],
    );
  }
}
