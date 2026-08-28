import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/input_validators.dart';
import '../../../data/models/neighborhood_event.dart';
import '../../../state/auth_controller.dart';
import '../../../state/event_controller.dart';
import '../../../state/neighborhood_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/form_scaffold.dart';
import '../../widgets/stat_tile.dart';

///NiS
/// "Events" — create neighbourhood events and manage participation.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    await context.read<EventController>().load(
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
    final controller = context.read<EventController>();
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
      builder: (_) => const _CreateEventDialog(),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event angelegt – deine Nachbarn wurden informiert.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = context.watch<EventController>();
    final user = context.watch<AuthController>().currentUser;
    if (user == null) return const SizedBox.shrink();

    final upcoming = events.events.where((event) => event.isUpcoming).toList();
    final past = events.events.where((event) => !event.isUpcoming).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Event anlegen'),
      ),
      body: events.isBusy
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
                    title: '${upcoming.length} kommende Events',
                    subtitle: 'Straßenfest, Gartentag, Spieleabend – '
                        'organisiert gemeinsam etwas.',
                  ),
                  if (events.errorMessage != null)
                    ErrorBanner(message: events.errorMessage!, onRetry: _load),
                  if (events.events.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.celebration_outlined,
                        title: 'Noch keine Events',
                        message: 'Ein gemeinsames Treffen ist der einfachste '
                            'Weg, die Nachbarschaft kennenzulernen.',
                        actionLabel: 'Event anlegen',
                        onAction: _openCreateDialog,
                      ),
                    ),
                  for (final event in upcoming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _EventCard(
                        event: event,
                        currentUserId: user.id,
                        onJoin: () => _runAction(
                          () => context.read<EventController>().joinEvent(
                            event: event,
                            currentUser: user,
                          ),
                          'Du bist dabei!',
                        ),
                        onLeave: () => _runAction(
                          () => context.read<EventController>().leaveEvent(
                            event: event,
                            currentUser: user,
                          ),
                          'Teilnahme zurückgezogen.',
                        ),
                        onDelete: () => _runAction(
                          () => context.read<EventController>().deleteEvent(
                            event: event,
                            organizer: user,
                          ),
                          'Event abgesagt.',
                        ),
                      ),
                    ),
                  if (past.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppTheme.gap),
                    const SectionHeader(
                      title: 'Vergangene Events',
                      subtitle: 'Was in der Nachbarschaft bereits stattfand',
                    ),
                    for (final event in past)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Opacity(
                          opacity: 0.6,
                          child: _EventCard(
                            event: event,
                            currentUserId: user.id,
                            onJoin: () {},
                            onLeave: () {},
                            onDelete: () => _runAction(
                              () => context.read<EventController>().deleteEvent(
                                event: event,
                                organizer: user,
                              ),
                              'Event gelöscht.',
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Card for a single event including the participant list.
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.currentUserId,
    required this.onJoin,
    required this.onLeave,
    required this.onDelete,
  });

  final NeighborhoodEvent event;
  final int currentUserId;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool isOrganizer = event.isOrganizedBy(currentUserId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gap * 1.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Calendar style date block.
                Container(
                  width: 58,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.categoryEvent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        DateFormatter.prettyDateShort(event.eventDate),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.categoryEvent,
                        ),
                      ),
                      Text(
                        event.eventTime,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.place_outlined,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    event.countdownLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text(
              event.description,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),

            //Participants
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.groups_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${event.participantCount} '
                  '${event.participantCount == 1 ? 'Teilnehmer:in' : 'Teilnehmende'}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                // Stacked avatars of the first participants.
                for (final name in event.participantNames.take(5))
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Tooltip(
                      message: name,
                      child: InitialsAvatar(
                        initials: _initialsOf(name),
                        size: 26,
                        color: AppColors.categoryEvent,
                      ),
                    ),
                  ),
                if (event.participantNames.length > 5)
                  Text(
                    '+${event.participantNames.length - 5}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textDisabled,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Organisiert von '
                '${isOrganizer ? 'dir' : event.organizerName}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textDisabled,
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (isOrganizer)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 17),
                    label: const Text('Event absagen'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                  )
                else if (!event.isUpcoming)
                  const Text(
                    'Dieses Event ist vorbei.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textDisabled,
                    ),
                  )
                else if (event.currentUserHasJoined) ...<Widget>[
                  const Text(
                    'Du nimmst teil.',
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
                    label: const Text('Absagen'),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: onJoin,
                    icon: const Icon(Icons.check, size: 17),
                    label: const Text('Teilnehmen'),
                  ),
              ],
            ),
          ],
        ),
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

/// Dialog to create a new event.
class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog();

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  DateTime _eventDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _eventTime = const TimeOfDay(hour: 17, minute: 0);
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String get _formattedTime =>
      '${_eventTime.hour.toString().padLeft(2, '0')}:'
      '${_eventTime.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = context.read<AuthController>().requireUser;
    final neighborIds = context.read<NeighborhoodController>().memberIds;

    setState(() => _isSubmitting = true);
    final success = await context.read<EventController>().createEvent(
      organizer: user,
      title: _titleController.text,
      location: _locationController.text,
      eventDate: DateFormatter.toIsoDate(_eventDate),
      eventTime: _formattedTime,
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
            context.read<EventController>().errorMessage ??
                'Das Event konnte nicht gespeichert werden.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'Event anlegen',
      subtitle: 'Wozu möchtest du deine Nachbarschaft einladen?',
      icon: Icons.celebration_outlined,
      formKey: _formKey,
      submitLabel: 'Event veröffentlichen',
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
      fields: <Widget>[
        AppTextField(
          controller: _titleController,
          label: 'Titel',
          hint: 'z. B. Straßenfest, Gartentag',
          icon: Icons.title,
          validator: (value) =>
              InputValidators.minLength(value, 4, field: 'Der Titel'),
        ),
        AppTextField(
          controller: _locationController,
          label: 'Ort',
          hint: 'z. B. Hinterhof Nordstraße 88',
          icon: Icons.place_outlined,
          validator: (value) =>
              InputValidators.minLength(value, 3, field: 'Der Ort'),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _eventDate,
                    firstDate: DateTime(now.year, now.month, now.day),
                    lastDate: now.add(const Duration(days: 730)),
                    helpText: 'Datum des Events',
                  );
                  if (picked != null) setState(() => _eventDate = picked);
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Datum',
                    prefixIcon: Icon(Icons.event_outlined, size: 20),
                  ),
                  child: Text(
                    DateFormatter.prettyDate(
                      DateFormatter.toIsoDate(_eventDate),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _eventTime,
                    helpText: 'Beginn',
                  );
                  if (picked != null) setState(() => _eventTime = picked);
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Beginn',
                    prefixIcon: Icon(Icons.schedule_outlined, size: 20),
                  ),
                  child: Text('$_formattedTime Uhr'),
                ),
              ),
            ),
          ],
        ),
        AppTextField(
          controller: _descriptionController,
          label: 'Beschreibung',
          icon: Icons.notes_outlined,
          maxLines: 5,
          validator: (value) =>
              InputValidators.minLength(value, 10, field: 'Die Beschreibung'),
        ),
      ],
    );
  }
}
