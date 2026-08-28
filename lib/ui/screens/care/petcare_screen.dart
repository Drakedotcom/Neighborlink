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

/// LuL Organise pet sitting inside the neighbourhood.
class PetcareScreen extends StatefulWidget {
  const PetcareScreen({super.key});

  @override
  State<PetcareScreen> createState() => _PetcareScreenState();
}

class _PetcareScreenState extends State<PetcareScreen> {
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
      builder: (_) => const _CreatePetcareDialog(),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Betreuungsgesuch veröffentlicht.')),
      );
    }
  }

  Future<void> _offerHelp(PetcareRequest request) async {
    final message = await askForHelpMessage(
      context,
      title: 'Tierbetreuung anbieten',
      prefilledMessage: 'Hallo, ich kümmere mich gerne um ${request.petType}.',
    );
    if (message == null || !mounted) return;

    final user = context.read<AuthController>().requireUser;
    await _runAction(
      () => context.read<CareController>().offerPetcareHelp(
        request: request,
        helper: user,
        message: message,
      ),
      'Danke! Dein Angebot wurde weitergeleitet.',
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
        label: const Text('Betreuung suchen'),
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
                    title: '${care.openPetcareCount} offene Gesuche',
                    subtitle: 'Urlaub, Dienstreise oder Krankheit – '
                        'Tiere bleiben in guten Händen.',
                  ),
                  if (care.errorMessage != null)
                    ErrorBanner(message: care.errorMessage!, onRetry: _load),
                  if (care.petcareRequests.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.pets_outlined,
                        title: 'Keine Betreuungsgesuche',
                        message: 'Erstelle ein Gesuch, wenn dein Tier '
                            'vorübergehend Betreuung braucht.',
                        actionLabel: 'Betreuung suchen',
                        onAction: _openCreateDialog,
                      ),
                    )
                  else
                    for (final request in care.petcareRequests)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PetcareCard(
                          request: request,
                          currentUserId: user.id,
                          onOfferHelp: () => _offerHelp(request),
                          onWithdrawHelp: () => _runAction(
                            () => context
                                .read<CareController>()
                                .withdrawPetcareHelp(
                                  request: request,
                                  helper: user,
                                ),
                            'Angebot zurückgezogen.',
                          ),
                          onClose: () => _runAction(
                            () => context
                                .read<CareController>()
                                .closePetcareRequest(
                                  request: request,
                                  requester: user,
                                ),
                            'Gesuch als geklärt markiert.',
                          ),
                          onDelete: () => _runAction(
                            () => context
                                .read<CareController>()
                                .deletePetcareRequest(
                                  request: request,
                                  requester: user,
                                ),
                            'Gesuch gelöscht.',
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

/// LuL Card for one pet care request.
class _PetcareCard extends StatefulWidget {
  const _PetcareCard({
    required this.request,
    required this.currentUserId,
    required this.onOfferHelp,
    required this.onWithdrawHelp,
    required this.onClose,
    required this.onDelete,
  });

  final PetcareRequest request;
  final int currentUserId;
  final VoidCallback onOfferHelp;
  final VoidCallback onWithdrawHelp;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  @override
  State<_PetcareCard> createState() => _PetcareCardState();
}

class _PetcareCardState extends State<_PetcareCard> {
  bool _showOffers = false;

  Future<void> _toggleOffers() async {
    setState(() => _showOffers = !_showOffers);
    if (_showOffers) {
      await context.read<CareController>().loadOffers(
        widget.request.id,
        isChildcare: false,
      );
    }
  }

  /// Number of days the pet needs care, inclusive of both dates.
  int get _durationInDays {
    final start = DateFormatter.tryParseIsoDate(widget.request.startDate);
    final end = DateFormatter.tryParseIsoDate(widget.request.endDate);
    if (start == null || end == null) return 0;
    return end.difference(start).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final bool isOwner = request.isCreatedBy(widget.currentUserId);
    final offers = context.watch<CareController>().offersFor(
      request.id,
      isChildcare: false,
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
                    color: AppColors.categoryPetCare.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.pets_outlined,
                    color: AppColors.categoryPetCare,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        request.petType,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOwner
                            ? 'Dein Gesuch'
                            : 'Gesuch von ${request.requesterName}',
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
                CarePill(
                  icon: Icons.date_range_outlined,
                  label: '${DateFormatter.prettyDate(request.startDate)} – '
                      '${DateFormatter.prettyDate(request.endDate)}',
                ),
                CarePill(
                  icon: Icons.timelapse_outlined,
                  label: '$_durationInDays '
                      '${_durationInDays == 1 ? 'Tag' : 'Tage'}',
                ),
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
            // Wrap statt Row: auf schmalen Geräten rutschen die Schaltflächen
            // in die nächste Zeile, statt rechts aus der Karte zu laufen.
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
                accentColor: AppColors.categoryPetCare,
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
          'Dieses Gesuch ist bereits abgedeckt.',
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
        label: const Text('Betreuung anbieten'),
      ),
    ];
  }
}

/// LuL Dialog to create a pet care request.
class _CreatePetcareDialog extends StatefulWidget {
  const _CreatePetcareDialog();

  @override
  State<_CreatePetcareDialog> createState() => _CreatePetcareDialogState();
}

class _CreatePetcareDialogState extends State<_CreatePetcareDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _petTypeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  DateTime _startDate = DateTime.now().add(const Duration(days: 3));
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isSubmitting = false;

  @override
  void dispose() {
    _petTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Betreuungszeitraum',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = context.read<AuthController>().requireUser;
    final neighborIds = context.read<NeighborhoodController>().memberIds;

    setState(() => _isSubmitting = true);
    final success = await context.read<CareController>().createPetcareRequest(
      requester: user,
      petType: _petTypeController.text,
      startDate: DateFormatter.toIsoDate(_startDate),
      endDate: DateFormatter.toIsoDate(_endDate),
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
                'Das Gesuch konnte nicht gespeichert werden.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'Tierbetreuung suchen',
      subtitle: 'Wer soll betreut werden und wann?',
      icon: Icons.pets_outlined,
      formKey: _formKey,
      submitLabel: 'Gesuch veröffentlichen',
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
      fields: <Widget>[
        AppTextField(
          controller: _petTypeController,
          label: 'Tierart',
          hint: 'z. B. Hund (Labrador, 4 Jahre), zwei Katzen',
          icon: Icons.pets_outlined,
          validator: (value) =>
              InputValidators.minLength(value, 3, field: 'Die Tierart'),
        ),
        InkWell(
          onTap: _pickRange,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Zeitraum',
              prefixIcon: Icon(Icons.date_range_outlined, size: 20),
            ),
            child: Text(
              '${DateFormatter.prettyDate(DateFormatter.toIsoDate(_startDate))} '
              '– ${DateFormatter.prettyDate(DateFormatter.toIsoDate(_endDate))}',
            ),
          ),
        ),
        AppTextField(
          controller: _descriptionController,
          label: 'Beschreibung',
          hint: 'Fütterung, Spaziergänge, Eigenheiten ...',
          icon: Icons.notes_outlined,
          maxLines: 5,
          validator: (value) =>
              InputValidators.minLength(value, 10, field: 'Die Beschreibung'),
        ),
      ],
    );
  }
}
