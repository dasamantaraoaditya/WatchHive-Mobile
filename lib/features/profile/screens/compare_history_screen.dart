import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../entries/widgets/suggest_movie_modal.dart';
import '../models/compare_result.dart';
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
  CompareResult? _result;
  bool _isLoading = true;
  bool _isPrivacyRestricted = false;
  String? _error;
  int _selectedTabIndex = 0; // 0: In Common, 1: Only You, 2: Only Friend
  final Map<int, String> _posters = {};

  @override
  void initState() {
    super.initState();
    _fetchCompareData();
  }

  Future<void> _fetchCompareData() async {
    setState(() {
      _isLoading = true;
      _isPrivacyRestricted = false;
      _error = null;
    });
    try {
      final repo = ref.read(userRepositoryProvider);
      final rawData = await repo.compareWithUser(widget.userId);
      final result = CompareResult.fromJson(rawData);

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
        _fetchPostersForItems(result);
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        if (msg.startsWith('PRIVACY_RESTRICTED:')) {
          setState(() {
            _isPrivacyRestricted = true;
            _error = msg.replaceFirst('PRIVACY_RESTRICTED:', '');
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = msg;
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _fetchPostersForItems(CompareResult result) async {
    final repo = ref.read(userRepositoryProvider);
    final allItems = <({int tmdbId, String type, String? posterPath})>[
      ...result.commonItems.map((e) => (tmdbId: e.tmdbId, type: e.type, posterPath: e.posterPath)),
      ...result.userAOnlyItems.map((e) => (tmdbId: e.tmdbId, type: e.type, posterPath: e.posterPath)),
      ...result.userBOnlyItems.map((e) => (tmdbId: e.tmdbId, type: e.type, posterPath: e.posterPath)),
    ];

    final toFetch = allItems.take(40).where((item) {
      return (item.posterPath == null || item.posterPath!.isEmpty) && !_posters.containsKey(item.tmdbId);
    }).toList();

    if (toFetch.isEmpty) return;

    await Future.wait(
      toFetch.map((item) async {
        try {
          final path = await repo.getTmdbPoster(item.tmdbId, item.type);
          if (path != null && mounted) {
            setState(() {
              _posters[item.tmdbId] = path;
            });
          }
        } catch (_) {}
      }),
    );
  }

  void _onMovieTap(int tmdbId, String type) {
    if (tmdbId <= 0) return;
    final typeSlug = type.toUpperCase() == 'TV_SHOW' || type.toLowerCase() == 'tv' ? 'tv' : 'movie';
    context.push('/details/$typeSlug/$tmdbId');
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value?.user;
    final friendUser = _result?.userB;

    final friendUsername = friendUser?.username.isNotEmpty == true
        ? friendUser!.username
        : (widget.initialUser?.username ?? 'friend');
    final friendDisplayName = friendUser?.displayName.isNotEmpty == true
        ? friendUser!.displayName
        : (widget.initialUser?.displayName ?? friendUsername);
    final friendFirstName = friendDisplayName.split(' ').first;
    final friendAvatarUrl = friendUser?.profilePictureUrl ?? widget.initialUser?.profilePictureUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Watch Comparison',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Swarm Viewing Intelligence',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          if (_result != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '🔥 ${_result!.stats.matchPercentage}% MATCH',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Cross-referencing viewing histories...',
                    style: TextStyle(fontFamily: 'Inter', color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : _isPrivacyRestricted
              ? _buildPrivacyRestrictedView()
              : _error != null
                  ? _buildErrorView()
                  : _buildComparisonContent(currentUser, friendFirstName, friendDisplayName, friendUsername, friendAvatarUrl),
    );
  }

  Widget _buildPrivacyRestrictedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: 18),
              const Text(
                'Privacy Restricted',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'This user has restricted access to their watch history.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Return to Profile', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 14),
            const Text(
              'Comparison Unavailable',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Comparison', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonContent(
    User? currentUser,
    String friendFirstName,
    String friendDisplayName,
    String friendUsername,
    String? friendAvatarUrl,
  ) {
    final result = _result!;
    final stats = result.stats;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
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
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top Row: User A vs User B
                Row(
                  children: [
                    // User A (You)
                    Expanded(
                      child: Row(
                        children: [
                          WHAvatar(
                            imageUrl: currentUser?.profilePictureUrl,
                            name: currentUser?.name ?? 'You',
                            radius: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'YOU',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  currentUser?.name ?? 'You',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Center VS Lightning Icon
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Center(
                        child: Text(
                          '⚡',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    // User B (Friend)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'FRIEND',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textMuted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  friendDisplayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          WHAvatar(
                            imageUrl: friendAvatarUrl,
                            name: friendDisplayName,
                            radius: 24,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 16),

                // 3-Column Stats Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildStatColumn(
                        count: stats.totalCommon,
                        label: 'In Common',
                        isPrimary: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatColumn(
                        count: stats.totalUserAOnly,
                        label: 'Only You',
                        isPrimary: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatColumn(
                        count: stats.totalUserBOnly,
                        label: 'Only $friendFirstName',
                        isPrimary: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3 Segmented Filter Tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    index: 0,
                    label: '🤝 Common',
                    count: stats.totalCommon,
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    index: 1,
                    label: '👤 Only You',
                    count: stats.totalUserAOnly,
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    index: 2,
                    label: '👥 $friendFirstName',
                    count: stats.totalUserBOnly,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Content List
          if (_selectedTabIndex == 0)
            _buildCommonList(result.commonItems, friendFirstName, friendUsername)
          else if (_selectedTabIndex == 1)
            _buildUserAOnlyList(result.userAOnlyItems)
          else
            _buildUserBOnlyList(result.userBOnlyItems, friendFirstName),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required int count,
    required String label,
    required bool isPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primary.withValues(alpha: 0.1) : AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrimary ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isPrimary ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isPrimary ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required int count,
  }) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.black : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black.withValues(alpha: 0.15) : AppColors.surfaceHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.black : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommonList(List<CommonItem> items, String friendFirstName, String friendUsername) {
    if (items.isEmpty) {
      return Container(
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('🍿', style: TextStyle(fontSize: 24))),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Shared Watches Yet',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'You and $friendFirstName haven\'t logged the same titles yet. Suggest a favorite to get started!',
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
              label: const Text('Suggest a Movie', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final item = items[i];
        final posterPath = item.posterPath ?? _posters[item.tmdbId];
        final ratingA = item.entryA.rating;
        final ratingB = item.entryB.rating;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onMovieTap(item.tmdbId, item.type),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                TMDBPosterImage(
                  posterPath: posterPath,
                  width: 48,
                  height: 70,
                  borderRadius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.type == 'TV_SHOW' || item.type == 'TV'
                                  ? Colors.purple.withValues(alpha: 0.15)
                                  : AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.type == 'TV_SHOW' || item.type == 'TV' ? 'TV' : 'MOVIE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: item.type == 'TV_SHOW' || item.type == 'TV' ? Colors.purpleAccent : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
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

                      // Side-by-Side Scores
                      Row(
                        children: [
                          // You
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'YOU: ',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primary),
                                ),
                                if (ratingA != null) ...[
                                  const Icon(Icons.star_rounded, size: 12, color: AppColors.primary),
                                  const SizedBox(width: 2),
                                  Text(
                                    ratingA.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                ] else
                                  const Text(
                                    'Watched',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Friend
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${friendFirstName.toUpperCase()}: ',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textMuted),
                                ),
                                if (ratingB != null) ...[
                                  const Icon(Icons.star_rounded, size: 12, color: AppColors.primary),
                                  const SizedBox(width: 2),
                                  Text(
                                    ratingB.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                ] else
                                  const Text(
                                    'Watched',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted),
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
    );
  }

  Widget _buildUserAOnlyList(List<SingleItem> items) {
    if (items.isEmpty) {
      return Container(
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('🎬', style: TextStyle(fontSize: 24))),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Unique Titles',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'You haven\'t watched any unique titles compared to this friend.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final item = items[i];
        final posterPath = item.posterPath ?? _posters[item.tmdbId];

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onMovieTap(item.tmdbId, item.type),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                TMDBPosterImage(
                  posterPath: posterPath,
                  width: 48,
                  height: 70,
                  borderRadius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.type == 'TV_SHOW' || item.type == 'TV'
                                  ? Colors.purple.withValues(alpha: 0.15)
                                  : AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.type == 'TV_SHOW' || item.type == 'TV' ? 'TV' : 'MOVIE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: item.type == 'TV_SHOW' || item.type == 'TV' ? Colors.purpleAccent : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text('Your Score: ', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          if (item.rating != null) ...[
                            const Icon(Icons.star_rounded, size: 13, color: AppColors.primary),
                            const SizedBox(width: 2),
                            Text(
                              item.rating!.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ] else
                            const Text('Watched', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
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
    );
  }

  Widget _buildUserBOnlyList(List<SingleItem> items, String friendFirstName) {
    if (items.isEmpty) {
      return Container(
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('📺', style: TextStyle(fontSize: 24))),
            ),
            const SizedBox(height: 14),
            Text(
              'No Unique Titles for $friendFirstName',
              style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              '$friendFirstName hasn\'t watched any unique titles yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final item = items[i];
        final posterPath = item.posterPath ?? _posters[item.tmdbId];

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onMovieTap(item.tmdbId, item.type),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                TMDBPosterImage(
                  posterPath: posterPath,
                  width: 48,
                  height: 70,
                  borderRadius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.type == 'TV_SHOW' || item.type == 'TV'
                                  ? Colors.purple.withValues(alpha: 0.15)
                                  : AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.type == 'TV_SHOW' || item.type == 'TV' ? 'TV' : 'MOVIE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: item.type == 'TV_SHOW' || item.type == 'TV' ? Colors.purpleAccent : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('$friendFirstName\'s Score: ', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          if (item.rating != null) ...[
                            const Icon(Icons.star_rounded, size: 13, color: AppColors.primary),
                            const SizedBox(width: 2),
                            Text(
                              item.rating!.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ] else
                            const Text('Watched', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
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
    );
  }
}


