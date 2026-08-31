import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../rankings/models/ranking_stack.dart';
import '../../rankings/repositories/rankings_repository.dart';
import '../../rankings/providers/rankings_provider.dart';

class UserRankingsTab extends ConsumerStatefulWidget {
  final String userId;

  const UserRankingsTab({super.key, required this.userId});

  @override
  ConsumerState<UserRankingsTab> createState() => _UserRankingsTabState();
}

class _UserRankingsTabState extends ConsumerState<UserRankingsTab> {
  List<RankingStack> _stacks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRankings();
  }

  Future<void> _fetchRankings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(rankingsRepositoryProvider);
      final isCurrentUser = ref.read(authStateProvider).value?.user?.id == widget.userId;

      final stacks = isCurrentUser
          ? await repo.getMyRankingStacks()
          : await repo.getUserRankings(widget.userId);

      if (mounted) {
        setState(() {
          _stacks = stacks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authStateProvider).value?.user?.id;
    final isCurrentUser = currentUserId == widget.userId;

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
              const SizedBox(height: 8),
              Text('Failed to load ranking stacks: $_error', style: const TextStyle(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _fetchRankings,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_stacks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.format_list_numbered_rounded, size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              Text(
                isCurrentUser ? 'No Ranking Stacks Created' : 'No Public Rankings',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isCurrentUser
                    ? 'Create ordered lists to rank your absolute top films, director filmographies, or yearly favorites!'
                    : 'This user hasn\'t shared any public ranking stacks yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              if (isCurrentUser) ...[
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () async {
                    await context.push('/rankings');
                    _fetchRankings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create a Stack 🏆', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRankings,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _stacks.length + (isCurrentUser ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (ctx, i) {
          if (isCurrentUser && i == 0) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Manage & Reorder Stacks',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await context.push('/rankings');
                      _fetchRankings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Open Stacks 📚', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }

          final stackIndex = isCurrentUser ? i - 1 : i;
          final stack = _stacks[stackIndex];
          return _buildStackCard(stack, isCurrentUser);
        },
      ),
    );
  }

  Widget _buildStackCard(RankingStack stack, bool isCurrentUser) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              stack.name,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${stack.items.length} Items',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (stack.description != null && stack.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          stack.description!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (isCurrentUser)
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                    tooltip: 'Edit in Rankings',
                    onPressed: () async {
                      await context.push('/rankings', extra: stack.id);
                      _fetchRankings();
                    },
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Items Preview
          if (stack.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('No titles ranked in this stack yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: stack.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 64, color: AppColors.border),
              itemBuilder: (ctx, idx) {
                final item = stack.items[idx];
                final rank = idx + 1;
                final isTop3 = rank <= 3;

                Color badgeBg = isTop3
                    ? (rank == 1
                        ? const Color(0xFFFFD700)
                        : rank == 2
                            ? const Color(0xFFE0E0E0)
                            : const Color(0xFFCD7F32))
                    : AppColors.surfaceHighest;
                Color badgeText = (rank == 1 || rank == 2) ? Colors.black : Colors.white;

                return InkWell(
                  onTap: () {
                    context.push('/details/${item.mediaType}/${item.tmdbId}');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        // Rank Badge
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '#$rank',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: badgeText,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Poster Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: item.posterPath != null && item.posterPath!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: ApiEndpoints.tmdbPoster(item.posterPath!),
                                  width: 32,
                                  height: 46,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(width: 32, height: 46, color: AppColors.surfaceHighest),
                                  errorWidget: (_, __, ___) => Container(width: 32, height: 46, color: AppColors.surfaceHighest, child: const Icon(Icons.movie_rounded, size: 16, color: AppColors.textMuted)),
                                )
                              : Container(width: 32, height: 46, color: AppColors.surfaceHighest, child: const Icon(Icons.movie_creation_outlined, color: AppColors.primary, size: 16)),
                        ),
                        const SizedBox(width: 12),

                        // Title & Year
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title ?? 'Movie #${item.tmdbId}',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    item.mediaType == 'tv' ? 'TV SERIES' : 'MOVIE',
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                  if (item.year.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text(item.year, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                  if (item.localRating != null && item.localRating! > 0) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.star_rounded, size: 12, color: Colors.amber[400]),
                                    const SizedBox(width: 2),
                                    Text(
                                      item.localRating!.toStringAsFixed(1),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber[400]),
                                    ),
                                  ] else if (item.voteAverage != null && item.voteAverage! > 0) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.star_rounded, size: 12, color: AppColors.primary),
                                    const SizedBox(width: 2),
                                    Text(
                                      item.voteAverage!.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
