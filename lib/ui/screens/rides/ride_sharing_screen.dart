import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/input_validators.dart';
import '../../../data/models/ride.dart';
import '../../../state/auth_controller.dart';
import '../../../state/neighborhood_controller.dart';
import '../../../state/ride_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/form_scaffold.dart';

///NiS
/// "Fahrgemeinschaften" — create rides, join them, withdraw again.
class RideSharingScreen extends StatefulWidget {
  const RideSharingScreen({super.key});

  @override
  State<RideSharingScreen> createState() => _RideSharingScreenState();
}

class _RideSharingScreenState extends State<RideSharingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    await context.read<RideController>().load(
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
    final controller = context.read<RideController>();
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
      builder: (_) => const _CreateRideDialog(),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deine Fahrt ist eingetragen.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rides = context.watch<RideController>();
    final user = context.watch<AuthController>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add_road),
        label: const Text('Fahrt anbieten'),
      ),
      body: rides.isBusy
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
                    title: '${rides.ridesWithFreeSeats} Fahrten mit freien Plätzen',
                    subtitle: 'Gemeinsam fahren spart Geld, Parkplätze und CO₂.',
                    trailing: TextButton.icon(
                      onPressed: () => context
                          .read<RideController>()
                          .toggleUpcomingFilter(
                            neighborhoodId: user.neighborhoodId,
                            userId: user.id,
                          ),
                      icon: Icon(
                        rides.onlyUpcoming
                            ? Icons.history
                            : Icons.upcoming_outlined,
                        size: 17,
                      ),
                      label: Text(
                        rides.onlyUpcoming
                            ? 'Auch vergangene zeigen'
                            : 'Nur kommende zeigen',
                      ),
                    ),
                  ),
                  if (rides.errorMessage != null)
                    ErrorBanner(message: rides.errorMessage!, onRetry: _load),
                  if (rides.rides.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.directions_car_outlined,
                        title: 'Keine Fahrten eingetragen',
                        message: 'Fährst du regelmäßig zur Arbeit, zum Baumarkt '
                            'oder zum Bahnhof? Nimm jemanden mit.',
                        actionLabel: 'Fahrt anbieten',
                        onAction: _openCreateDialog,
                      ),
                    )
                  else
                    for (final ride in rides.rides)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RideCard(
                          ride: ride,
                          currentUserId: user.id,
                          onJoin: () => _runAction(
                            () => context.read<RideController>().joinRide(
                              ride: ride,
                              currentUser: user,
                            ),
                            'Du bist dabei! Die fahrende Person wurde informiert.',
                          ),
                          onLeave: () => _runAction(
                            () => context.read<RideController>().leaveRide(
                              ride: ride,
                              currentUser: user,
                            ),
                            'Mitfahrt zurückgezogen.',
                          ),
                          onDelete: () => _runAction(
                            () => context.read<RideController>().deleteRide(
                              ride: ride,
                              driver: user,
                            ),
                            'Fahrt gelöscht, Mitfahrende wurden informiert.',
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

/// Card for one ride, with a visual seat indicator.
class _RideCard extends StatelessWidget {
  const _RideCard({
    required this.ride,
    required this.currentUserId,
    required this.onJoin,
    required this.onLeave,
    required this.onDelete,
  });

  final Ride ride;
  final int currentUserId;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool isDriver = ride.isDrivenBy(currentUserId);
    final int? daysUntil = DateFormatter.daysFromToday(ride.departureDate);
    final bool isPast = daysUntil != null && daysUntil < 0;

    return Opacity(
      opacity: isPast ? 0.6 : 1,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gap * 1.25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // --- Route --------------------------------------------------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      const Icon(
                        Icons.trip_origin,
                        size: 14,
                        color: AppColors.categoryRide,
                      ),
                      Container(
                        width: 2,
                        height: 24,
                        color: AppColors.border,
                      ),
                      const Icon(
                        Icons.place,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          ride.origin,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          ride.destination,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SeatIndicator(
                    freeSeats: ride.freeSeats,
                    totalSeats: ride.totalSeats,
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _InfoPill(
                    icon: Icons.event_outlined,
                    label: '${DateFormatter.prettyDate(ride.departureDate)} · '
                        '${ride.departureTime} Uhr',
                    color: isPast ? AppColors.textDisabled : AppColors.primary,
                  ),
                  _InfoPill(
                    icon: Icons.person_outline,
                    label: isDriver ? 'Du fährst' : ride.driverName,
                  ),
                  if (ride.takenSeats > 0)
                    _InfoPill(
                      icon: Icons.groups_outlined,
                      label: '${ride.takenSeats} '
                          '${ride.takenSeats == 1 ? 'Mitfahrer:in' : 'Mitfahrende'}',
                    ),
                ],
              ),

              if (ride.note.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  ride.note,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],

              if (ride.participantNames.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  'Mit dabei: ${ride.participantNames.join(', ')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textDisabled,
                  ),
                ),
              ],

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _buildActions(isDriver: isDriver, isPast: isPast),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions({required bool isDriver, required bool isPast}) {
    if (isDriver) {
      return <Widget>[
        TextButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 17),
          label: const Text('Fahrt absagen'),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
        ),
      ];
    }
    if (isPast) {
      return <Widget>[
        const Text(
          'Diese Fahrt liegt in der Vergangenheit.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textDisabled),
        ),
      ];
    }
    if (ride.currentUserHasJoined) {
      return <Widget>[
        const Text(
          'Du fährst mit.',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.statusAvailable,
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: onLeave,
          icon: const Icon(Icons.undo, size: 17),
          label: const Text('Zurückziehen'),
        ),
      ];
    }
    if (ride.isFullyBooked) {
      return <Widget>[
        const Text(
          'Ausgebucht.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textDisabled),
        ),
      ];
    }
    return <Widget>[
      FilledButton.icon(
        onPressed: onJoin,
        icon: const Icon(Icons.event_seat_outlined, size: 17),
        label: const Text('Mitfahren'),
      ),
    ];
  }
}

/// Shows the free seats as filled and empty dots.
class _SeatIndicator extends StatelessWidget {
  const _SeatIndicator({required this.freeSeats, required this.totalSeats});

  final int freeSeats;
  final int totalSeats;

  @override
  Widget build(BuildContext context) {
    final Color color = freeSeats == 0
        ? AppColors.statusClosed
        : AppColors.statusAvailable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          '$freeSeats/$totalSeats',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const Text(
          'freie Plätze',
          style: TextStyle(fontSize: 10.5, color: AppColors.textDisabled),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // One icon per seat: filled = taken, outlined = still free.
            for (var seat = 0; seat < totalSeats.clamp(0, 6); seat++)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(
                  seat < (totalSeats - freeSeats)
                      ? Icons.person
                      : Icons.person_outline,
                  size: 14,
                  color: seat < (totalSeats - freeSeats)
                      ? AppColors.textDisabled
                      : color,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Small labelled pill (local copy so the ride module stays self contained).
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

/// Dialog to publish a new ride.
class _CreateRideDialog extends StatefulWidget {
  const _CreateRideDialog();

  @override
  State<_CreateRideDialog> createState() => _CreateRideDialogState();
}

class _CreateRideDialogState extends State<_CreateRideDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _seatsController = TextEditingController(text: '3');
  final TextEditingController _noteController = TextEditingController();

  DateTime _departureDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _departureTime = const TimeOfDay(hour: 8, minute: 0);
  bool _isSubmitting = false;

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _seatsController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Abfahrtsdatum',
    );
    if (picked != null) setState(() => _departureDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _departureTime,
      helpText: 'Abfahrtszeit',
    );
    if (picked != null) setState(() => _departureTime = picked);
  }

  String get _formattedTime =>
      '${_departureTime.hour.toString().padLeft(2, '0')}:'
      '${_departureTime.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = context.read<AuthController>().requireUser;
    final neighborIds = context.read<NeighborhoodController>().memberIds;

    setState(() => _isSubmitting = true);
    final success = await context.read<RideController>().createRide(
      driver: user,
      origin: _originController.text,
      destination: _destinationController.text,
      departureDate: DateFormatter.toIsoDate(_departureDate),
      departureTime: _formattedTime,
      totalSeats: int.tryParse(_seatsController.text.trim()) ?? 1,
      note: _noteController.text,
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
            context.read<RideController>().errorMessage ??
                'Die Fahrt konnte nicht gespeichert werden.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'Fahrt anbieten',
      subtitle: 'Wohin fährst du und wie viele Plätze sind frei?',
      icon: Icons.directions_car_outlined,
      formKey: _formKey,
      submitLabel: 'Fahrt eintragen',
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
      fields: <Widget>[
        AppTextField(
          controller: _originController,
          label: 'Startort',
          icon: Icons.trip_origin,
          validator: (value) =>
              InputValidators.minLength(value, 3, field: 'Der Startort'),
        ),
        AppTextField(
          controller: _destinationController,
          label: 'Zielort',
          icon: Icons.place_outlined,
          validator: (value) =>
              InputValidators.minLength(value, 3, field: 'Der Zielort'),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Datum',
                    prefixIcon: Icon(Icons.event_outlined, size: 20),
                  ),
                  child: Text(
                    DateFormatter.prettyDate(
                      DateFormatter.toIsoDate(_departureDate),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Uhrzeit',
                    prefixIcon: Icon(Icons.schedule_outlined, size: 20),
                  ),
                  child: Text('$_formattedTime Uhr'),
                ),
              ),
            ),
          ],
        ),
        AppTextField(
          controller: _seatsController,
          label: 'Verfügbare Plätze',
          icon: Icons.event_seat_outlined,
          keyboardType: TextInputType.number,
          validator: (value) =>
              InputValidators.positiveInteger(value, field: 'Die Platzanzahl'),
        ),
        AppTextField(
          controller: _noteController,
          label: 'Hinweis (optional)',
          hint: 'z. B. Rückfahrt möglich, Platz für Gepäck ...',
          icon: Icons.notes_outlined,
          maxLines: 3,
        ),
      ],
    );
  }
}
