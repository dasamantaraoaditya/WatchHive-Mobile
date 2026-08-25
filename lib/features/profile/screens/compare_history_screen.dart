import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../entries/widgets/suggest_movie_modal.dart';
import '../repositories/user_repository.dart';

class CompareHistoryScreen extends ConsumerStatefulWidget {
  final String userId;
  final User? initialUser;

  const CompareHistoryScreen({
    super.key,
    required this.userId,
    this.initialUser,
  });

  @override
  ConsumerState<CompareHistoryScreen> createState() => _CompareHistoryScreenState();
}

class _CompareHistoryScreenState extends ConsumerState<CompareHistoryScreen> {
  Map<String, dynamic>? _compareData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCompareData();
  }

  Future<void> _fetchCompareData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(userRepositoryProvider);
      final data = await repo.compareWithUser(widget.userId);
      if (mounted) {
        setState(() {
          _compareData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value?.user;

    // Normalize response payload
    final root = _compareData?['data'] is Map<String, dynamic>
        ? _compareData!['data'] as Map<String, dynamic>
        : (_compareData ?? <String, dynamic>{});

    final user2Data = root['user2'] ?? root['targetUser'] ?? root['otherUser'] ?? root['user'];
    final Map<String, dynamic>? friendMap = user2Data is Map<String, dynamic> ? user2Data : null;

    final friendUsername = friendMap?['username'] as String? ??
        widget.initialUser?.username ??
        'Friend';
    final friendDisplayName = friendMap?['displayName'] as String? ??
        friendMap?['name'] as String? ??
        widget.initialUser?.displayName ??
        friendUsername;
    final friendAvatarUrl = friendMap?['profilePictureUrl'] as String? ??
        friendMap?['avatarUrl'] as String? ??
        widget.initialUser?.profilePictureUrl;

    final stats = root['stats'] is Map<String, dynamic> ? root['stats'] as Map<String, dynamic> : root;

    final rawEntries = (root['sharedEntries'] ?? root['commonEntries'] ?? root['shared'] ?? root['entries'] ?? stats['sharedEntries'] ?? stats['entries']) as List<dynamic>?;
    final sharedEntries = rawEntries ?? [];

    final overlapScore = (stats['overlapScore'] ??
            stats['overlapPercentage'] ??
            stats['score'] ??
            stats['matchScore'] ??
            root['overlapScore'] ??
            root['overlapPercentage'] ??
            (sharedEntries.isNotEmpty ? ((sharedEntries.length / 10).clamp(0.0, 1.0) * 100).toInt() : 0)) as num;

    final sharedCount = (stats['sharedCount'] ??
            stats['count'] ??
            stats['commonCount'] ??
            root['sharedCount'] ??
            sharedEntries.length) as num;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Compare Taste',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 52, color: AppColors.error),
                        const SizedBox(height: 14),
                        const Text(
                          'Unable to Load Comparison',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetchCompareData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Comparison Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Two Avatars with Match Bridge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Current User Avatar
                                Column(
                                  children: [
                                    WHAvatar(
                                      imageUrl: currentUser?.profilePictureUrl,
                                      name: currentUser?.name ?? 'You',
                                      radius: 32,
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'You',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '@${currentUser?.username ?? 'you'}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),

                                // Overlap Score Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.35),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${overlapScore.toInt()}%',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w900,
                                          fontSize: 26,
                                          color: Colors.black,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const Text(
                                        'MATCH',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w900,
                                          fontSize: 9,
                                          letterSpacing: 1.2,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Friend User Avatar
                                Column(
                                  children: [
                                    WHAvatar(
                                      imageUrl: friendAvatarUrl,
                                      name: friendDisplayName,
                                      radius: 32,
                                    ),
                                    const SizedBox(height: 6),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 80),
                                      child: Text(
                                        friendDisplayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '@$friendUsername',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: AppColors.primaryDark),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            const Divider(height: 1, color: AppColors.border),
                            const SizedBox(height: 14),

                            // Subtitle metric
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.movie_filter_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  '${sharedCount.toInt()} Shared Movies & Shows Watched',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Shared Watch History',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (sharedEntries.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${sharedEntries.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // List of Shared Entries or Empty State
                      if (sharedEntries.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.movie_outlined, size: 28, color: AppColors.primary),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No Shared Watches Yet',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'You and @$friendUsername haven\'t logged the same titles yet. Suggest a favorite movie to watch!',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                ),
                                onPressed: () {
                                  SuggestMovieModal.show(
                                    context,
                                    initialToUserId: widget.userId,
                                    initialToUserName: friendUsername,
                                  );
                                },
                                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                                label: const Text('Suggest a Movie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sharedEntries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final item = sharedEntries[i] is Map<String, dynamic>
                                ? sharedEntries[i] as Map<String, dynamic>
                                : <String, dynamic>{};

                            final title = item['title'] as String? ??
                                item['name'] as String? ??
                                item['entry']?['title'] as String? ??
                                'Shared Title';
                            final posterPath = item['posterPath'] as String? ??
                                item['poster_path'] as String? ??
                                item['entry']?['posterPath'] as String?;
                            final tmdbId = (item['tmdbId'] as num?)?.toInt() ??
                                (item['entry']?['tmdbId'] as num?)?.toInt() ??
                                0;
                            final mediaType = (item['type'] as String? ??
                                    item['mediaType'] as String? ??
                                    item['entry']?['type'] as String? ??
                                    'MOVIE')
                                .toUpperCase();

                            final rating1 = (item['user1Rating'] ??
                                    item['myRating'] ??
                                    item['userRating'] ??
                                    item['rating1'] ??
                                    item['rating']) as num?;
                            final rating2 = (item['user2Rating'] ??
                                    item['theirRating'] ??
                                    item['friendRating'] ??
                                    item['rating2'] ??
                                    item['otherRating']) as num?;

                            return GestureDetector(
                              onTap: () {
                                if (tmdbId > 0) {
                                  final typeSlug = mediaType == 'TV_SHOW' ? 'tv' : 'movie';
                                  context.push('/details/$typeSlug/$tmdbId');
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    // Movie Poster
                                    TMDBPosterImage(
                                      posterPath: posterPath,
                                      width: 48,
                                      height: 68,
                                      borderRadius: 8,
                                    ),
                                    const SizedBox(width: 14),

                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: mediaType == 'TV_SHOW'
                                                      ? Colors.purple.withOpacity(0.12)
                                                      : Colors.amber.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  mediaType == 'TV_SHOW' ? 'TV SERIES' : 'MOVIE',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    color: mediaType == 'TV_SHOW' ? Colors.purpleAccent : AppColors.primaryDark,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 8),

                                          // Ratings comparison row
                                          Row(
                                            children: [
                                              // You
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceHighest,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Text('You: ', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                                    const Icon(Icons.star_rounded, size: 12, color: AppColors.primary),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      rating1 != null ? rating1.toDouble().toStringAsFixed(1) : '–',
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Friend
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text('@$friendUsername: ', style: const TextStyle(fontSize: 10, color: AppColors.primaryDark)),
                                                    const Icon(Icons.star_rounded, size: 12, color: AppColors.primaryDark),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      rating2 != null ? rating2.toDouble().toStringAsFixed(1) : '–',
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }
}

