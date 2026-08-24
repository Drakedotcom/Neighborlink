import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/input_validators.dart';
import '../../../data/models/community_post.dart';
import '../../../state/auth_controller.dart';
import '../../../state/feed_controller.dart';
import '../../../state/neighborhood_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/form_scaffold.dart';
import '../../widgets/stat_tile.dart';

///NiS
/// The community feed of the neighbourhood with a category filter.
class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    await context.read<FeedController>().load(user.neighborhoodId);
  }

  /// Opens the "create post" dialog.
  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreatePostDialog(),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dein Beitrag ist jetzt im Feed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedController>();
    final user = context.watch<AuthController>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Beitrag schreiben'),
      ),
      body: Column(
        children: <Widget>[
          _CategoryFilterBar(
            active: feed.activeFilter,
            counts: feed.categoryCounts,
            onSelect: (category) => feed.applyFilter(category),
          ),
          const Divider(height: 1),
          Expanded(
            child: Builder(
              builder: (context) {
                if (feed.isBusy) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (feed.posts.isEmpty) {
                  return EmptyState(
                    icon: Icons.forum_outlined,
                    title: feed.activeFilter == null
                        ? 'Noch keine Beiträge'
                        : 'Keine Beiträge in dieser Kategorie',
                    message: 'Schreib den ersten Beitrag und bring die '
                        'Nachbarschaft ins Gespräch.',
                    actionLabel: 'Beitrag schreiben',
                    onAction: _openCreateDialog,
                  );
                }

                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.gap * 1.5,
                      AppTheme.gap * 1.5,
                      AppTheme.gap * 1.5,
                      90,
                    ),
                    children: <Widget>[
                      if (feed.errorMessage != null)
                        ErrorBanner(message: feed.errorMessage!, onRetry: _load),
                      for (final post in feed.posts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PostCard(
                            post: post,
                            isOwnPost: post.authorId == user.id,
                            onDelete: () => _confirmDelete(post),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(CommunityPost post) async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Beitrag löschen?'),
        content: Text('"${post.title}" wird endgültig entfernt.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<FeedController>().deletePost(
      postId: post.id,
      authorId: user.id,
      neighborhoodId: user.neighborhoodId,
    );
  }
}

/// Horizontal chip bar to filter the feed by category.
class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.active,
    required this.counts,
    required this.onSelect,
  });

  final PostCategory? active;
  final Map<PostCategory, int> counts;
  final ValueChanged<PostCategory?> onSelect;

  @override
  Widget build(BuildContext context) {
    final totalCount = counts.values.fold<int>(0, (sum, value) => sum + value);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.gap * 1.5,
        vertical: 12,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            FilterChip(
              selected: active == null,
              label: Text('Alle ($totalCount)'),
              onSelected: (_) => onSelect(null),
              showCheckmark: false,
              avatar: Icon(
                Icons.apps,
                size: 16,
                color: active == null
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            for (final category in PostCategory.values) ...<Widget>[
              FilterChip(
                selected: active == category,
                showCheckmark: false,
                avatar: Icon(
                  category.icon,
                  size: 16,
                  color: active == category
                      ? category.color
                      : AppColors.textSecondary,
                ),
                label: Text('${category.label} (${counts[category] ?? 0})'),
                onSelected: (_) => onSelect(category),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single post in the feed.
class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isOwnPost,
    required this.onDelete,
  });

  final CommunityPost post;
  final bool isOwnPost;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gap * 1.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InitialsAvatar(
                  initials: _initialsOf(post.authorName),
                  color: post.category.color,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              post.authorName.isEmpty
                                  ? 'Nachbar:in'
                                  : post.authorName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isOwnPost) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Du',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        DateFormatter.relative(post.createdAt),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
                _CategoryChip(category: post.category),
                if (isOwnPost)
                  IconButton(
                    tooltip: 'Beitrag löschen',
                    iconSize: 18,
                    color: AppColors.textDisabled,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              post.description,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
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

/// Coloured category label.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final PostCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(category.icon, size: 13, color: category.color),
          const SizedBox(width: 5),
          Text(
            category.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: category.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog used to publish a new post.
class _CreatePostDialog extends StatefulWidget {
  const _CreatePostDialog();

  @override
  State<_CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<_CreatePostDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  PostCategory _category = PostCategory.general;
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
    final neighborIds = context.read<NeighborhoodController>().memberIds;

    setState(() => _isSubmitting = true);
    final success = await context.read<FeedController>().createPost(
      neighborhoodId: user.neighborhoodId,
      authorId: user.id,
      authorName: user.fullName,
      title: _titleController.text,
      description: _descriptionController.text,
      category: _category,
      neighborIds: neighborIds,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final message = context.read<FeedController>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'Der Beitrag konnte nicht gespeichert werden.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'Neuer Beitrag',
      subtitle: 'Teile eine Info mit deiner Nachbarschaft',
      icon: Icons.edit_outlined,
      formKey: _formKey,
      submitLabel: 'Veröffentlichen',
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
      fields: <Widget>[
        DropdownButtonFormField<PostCategory>(
          initialValue: _category,
          decoration: const InputDecoration(
            labelText: 'Kategorie',
            prefixIcon: Icon(Icons.category_outlined, size: 20),
          ),
          items: <DropdownMenuItem<PostCategory>>[
            for (final category in PostCategory.values)
              DropdownMenuItem<PostCategory>(
                value: category,
                child: Row(
                  children: <Widget>[
                    Icon(category.icon, size: 17, color: category.color),
                    const SizedBox(width: 9),
                    Text(category.label),
                  ],
                ),
              ),
          ],
          onChanged: (value) =>
              setState(() => _category = value ?? PostCategory.general),
        ),
        AppTextField(
          controller: _titleController,
          label: 'Titel',
          icon: Icons.title,
          validator: (value) =>
              InputValidators.minLength(value, 4, field: 'Der Titel'),
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
