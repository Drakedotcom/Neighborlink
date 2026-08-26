import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/models/app_notification.dart';
import '../../../state/auth_controller.dart';
import '../../../state/notification_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

///LuS
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _showOnlyUnread = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    await context.read<NotificationController>().load(user.id);
  }

  Future<void> _confirmClearInbox() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Postfach leeren?'),
        content: const Text(
          'Alle Benachrichtigungen werden endgültig gelöscht.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leeren'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<NotificationController>().clearInbox(user.id);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationController>();
    final user = context.watch<AuthController>().currentUser;
    if (user == null) return const SizedBox.shrink();

    if (controller.isBusy) {
      return const Center(child: CircularProgressIndicator());
    }

    final visible = _showOnlyUnread
        ? controller.unreadNotifications
        : controller.notifications;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.gap * 1.5),
        children: <Widget>[
          SectionHeader(
            title: controller.unreadCount == 0
                ? 'Keine ungelesenen Nachrichten'
                : '${controller.unreadCount} ungelesen',
            subtitle: 'Alles, was in deiner Nachbarschaft für dich passiert.',
            trailing: Wrap(
              spacing: 6,
              children: <Widget>[
                if (controller.unreadCount > 0)
                  TextButton.icon(
                    onPressed: () => context
                        .read<NotificationController>()
                        .markAllAsRead(user.id),
                    icon: const Icon(Icons.done_all, size: 17),
                    label: const Text('Alle gelesen'),
                  ),
                if (controller.notifications.isNotEmpty)
                  TextButton.icon(
                    onPressed: _confirmClearInbox,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 17),
                    label: const Text('Leeren'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                  ),
              ],
            ),
          ),

          if (controller.errorMessage != null)
            ErrorBanner(message: controller.errorMessage!, onRetry: _load),

          // Filter toggle.
          Row(
            children: <Widget>[
              FilterChip(
                selected: !_showOnlyUnread,
                showCheckmark: false,
                label: Text('Alle (${controller.notifications.length})'),
                onSelected: (_) => setState(() => _showOnlyUnread = false),
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: _showOnlyUnread,
                showCheckmark: false,
                label: Text('Ungelesen (${controller.unreadCount})'),
                onSelected: (_) => setState(() => _showOnlyUnread = true),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.gap),

          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.notifications_none,
                title: 'Dein Postfach ist leer',
                message: 'Sobald jemand auf deine Angebote reagiert, '
                    'findest du es hier.',
              ),
            )
          else
            for (final notification in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NotificationTile(
                  notification: notification,
                  onMarkRead: () => context
                      .read<NotificationController>()
                      .markAsRead(notification.id, user.id),
                ),
              ),
        ],
      ),
    );
  }
}

///one entry
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onMarkRead,
  });

  final AppNotification notification;
  final VoidCallback onMarkRead;

  (IconData, Color) get _visuals => switch (notification.category) {
    NotificationCategory.request => (
      Icons.mark_email_unread_outlined,
      AppColors.categoryFurniture,
    ),
    NotificationCategory.reservation => (
      Icons.bookmark_added_outlined,
      AppColors.categoryFood,
    ),
    NotificationCategory.event => (
      Icons.celebration_outlined,
      AppColors.categoryEvent,
    ),
    NotificationCategory.ride => (
      Icons.directions_car_outlined,
      AppColors.categoryRide,
    ),
    NotificationCategory.care => (
      Icons.volunteer_activism_outlined,
      AppColors.categoryChildCare,
    ),
    NotificationCategory.system => (
      Icons.info_outline,
      AppColors.categoryGeneral,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _visuals;
    final bool isUnread = !notification.isRead;

    return Material(
      color: isUnread ? AppColors.accentSoft.withValues(alpha: 0.45) : AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: isUnread ? onMarkRead : null,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.gap),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: isUnread
                  ? AppColors.primaryLight.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          DateFormatter.relative(notification.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textDisabled,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 2,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            notification.category.label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        if (isUnread)
                          TextButton(
                            onPressed: onMarkRead,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Als gelesen markieren',
                              style: TextStyle(fontSize: 11.5),
                            ),
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
    );
  }
}