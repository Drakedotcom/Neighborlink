import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/models/app_user.dart';
import '../../../state/auth_controller.dart';
import '../../../state/neighborhood_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stat_tile.dart';

///LuS
class NeighborhoodScreen extends StatefulWidget {
  const NeighborhoodScreen({super.key});

  @override
  State<NeighborhoodScreen> createState() => _NeighborhoodScreenState();
}

class _NeighborhoodScreenState extends State<NeighborhoodScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _searchController.addListener(
      () => setState(() => _searchTerm = _searchController.text.trim()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) return;
    await context.read<NeighborhoodController>().load(user.neighborhoodId);
  }

  ///filter over name and street
  List<AppUser> _filterMembers(List<AppUser> members) {
    if (_searchTerm.isEmpty) return members;
    final needle = _searchTerm.toLowerCase();
    return members
        .where(
          (member) =>
              member.fullName.toLowerCase().contains(needle) ||
              member.streetAddress.toLowerCase().contains(needle),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NeighborhoodController>();
    final user = context.watch<AuthController>().currentUser;
    if (user == null) return const SizedBox.shrink();

    if (controller.isBusy) {
      return const Center(child: CircularProgressIndicator());
    }

    final neighborhood = controller.neighborhood;
    final members = _filterMembers(controller.members);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.gap * 1.5),
        children: <Widget>[
          if (controller.errorMessage != null)
            ErrorBanner(message: controller.errorMessage!, onRetry: _load),

          ///header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.gap * 1.5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.holiday_village_outlined,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppTheme.gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          neighborhood?.displayName ?? user.postalCode,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          neighborhood?.description ??
                              'Alle Personen mit derselben Postleitzahl bilden '
                                  'eine Nachbarschaft.',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: <Widget>[
                            _Metric(
                              icon: Icons.groups_2_outlined,
                              label: 'Mitglieder',
                              value: '${controller.members.length}',
                            ),
                            _Metric(
                              icon: Icons.person_outline,
                              label: 'Nachbar:innen',
                              value: '${controller.otherMemberCount(user.id)}',
                            ),
                            if (neighborhood != null)
                              _Metric(
                                icon: Icons.flag_outlined,
                                label: 'Aktiv seit',
                                value: DateFormatter.prettyDate(
                                  DateFormatter.toIsoDate(
                                    neighborhood.createdAt,
                                  ),
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

          const SizedBox(height: AppTheme.gap * 1.5),

          ///member list
          SectionHeader(
            title: 'Mitglieder',
            subtitle: 'Wer wohnt sonst noch in ${user.postalCode}?',
          ),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Nach Name oder Straße suchen',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchTerm.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _searchController.clear,
                    ),
            ),
          ),
          const SizedBox(height: AppTheme.gap),

          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: EmptyState(
                icon: Icons.person_search_outlined,
                title: 'Keine Treffer',
                message: 'Zu dieser Suche gibt es keine Mitglieder.',
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 600
                    ? 2
                    : 1;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.7,
                  children: <Widget>[
                    for (final member in members)
                      _MemberCard(
                        member: member,
                        isCurrentUser: member.id == user.id,
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

///icon, value, label
class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.isCurrentUser});

  final AppUser member;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gap),
        child: Row(
          children: <Widget>[
            InitialsAvatar(
              initials: member.initials,
              size: 44,
              color: isCurrentUser ? AppColors.accent : AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          member.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isCurrentUser) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Du',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.streetAddress,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (member.aboutMe.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        member.aboutMe,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textDisabled,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}