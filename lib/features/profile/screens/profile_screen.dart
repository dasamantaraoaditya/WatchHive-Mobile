import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';
import '../../entries/repositories/entries_repository.dart';

// ─── Profile Repository ───────────────────────────────────────────────────────

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.read(apiClientProvider));
});

class ProfileRepository {
  final ApiClient _api;

  ProfileRepository(this._api);

  Future<({User user, bool isFollowing, int followersCount, int followingCount})> getUserProfile(String userId) async {
    final response = await _api.get(ApiEndpoints.user(userId));
    final data = response.data as Map<String, dynamic>;

    // Backend returns user fields at top-level (not nested under 'user')
    final userData = data.containsKey('user')
        ? data['user'] as Map<String, dynamic>
        : data;

    final countData = data['_count'] as Map<String, dynamic>?;

    return (
      user: User.fromJson(userData),
      isFollowing: data['isFollowing'] as bool? ?? false,
      followersCount: countData?['followers'] as int? ??
          data['followersCount'] as int? ?? 0,
      followingCount: countData?['following'] as int? ??
          data['followingCount'] as int? ?? 0,
    );
  }

  Future<void> followUser(String userId) async {
    await _api.post(ApiEndpoints.followUser(userId));
  }

  Future<void> unfollowUser(String userId) async {
    await _api.delete(ApiEndpoints.followUser(userId));
  }

  Future<Map<String, dynamic>> getStats(String userId) async {
    final response = await _api.get(ApiEndpoints.entryStats);
    final data = response.data as Map<String, dynamic>;
    return data['stats'] as Map<String, dynamic>;
  }
}

// ─── Own Profile Screen ───────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  List<Entry> _entries = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = ref.read(authStateProvider).value?.user;
      if (user == null) return;

      final futures = await Future.wait([
        ref.read(entriesRepositoryProvider).getEntries(limit: 6),
        ref.read(entriesRepositoryProvider).getStats(),
      ]);

      setState(() {
        _entries = (futures[0] as ({List<Entry> entries, dynamic pagination})).entries;
        _stats = futures[1] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value?.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(user?.username ?? 'Profile'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: () => ref.read(authStateProvider.notifier).logout(),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _ProfileHeader(user: user!, showFollowButton: false),
                      const SizedBox(height: 24),
                      if (_stats != null) ...[
                        _StatsRow(stats: _stats!),
                        const SizedBox(height: 24),
                      ],
                      if (_entries.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recent Watches',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            TextButton(
                              onPressed: () => context.go('/entries'),
                              child: const Text('See all'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _EntryRow(entry: entry),
                            )),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Other User Profile Screen ────────────────────────────────────────────────

class UserProfileScreenBody extends ConsumerStatefulWidget {
  final String userId;

  const UserProfileScreenBody({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreenBody> createState() => _UserProfileScreenBodyState();
}

class _UserProfileScreenBodyState extends ConsumerState<UserProfileScreenBody> {
  User? _user;
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;
  List<Entry> _entries = [];
  bool _isLoading = true;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final profileData = await ref.read(profileRepositoryProvider).getUserProfile(widget.userId);
      final entriesResult = await ref.read(entriesRepositoryProvider).getEntries(userId: widget.userId, limit: 6);

      setState(() {
        _user = profileData.user;
        _isFollowing = profileData.isFollowing;
        _followersCount = profileData.followersCount;
        _followingCount = profileData.followingCount;
        _entries = entriesResult.entries;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _isFollowLoading = true);
    try {
      if (_isFollowing) {
        await ref.read(profileRepositoryProvider).unfollowUser(widget.userId);
        setState(() {
          _isFollowing = false;
          _followersCount = _followersCount > 0 ? _followersCount - 1 : 0;
        });
      } else {
        await ref.read(profileRepositoryProvider).followUser(widget.userId);
        setState(() {
          _isFollowing = true;
          _followersCount++;
        });
      }
    } catch (_) {}
    setState(() => _isFollowLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(_user?.username ?? ''),
                  floating: true,
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _ProfileHeader(
                        user: _user!,
                        showFollowButton: true,
                        isFollowing: _isFollowing,
                        isFollowLoading: _isFollowLoading,
                        followersCount: _followersCount,
                        followingCount: _followingCount,
                        onFollow: _toggleFollow,
                      ),
                      const SizedBox(height: 24),
                      if (_entries.isNotEmpty) ...[
                        const Text(
                          'Watch History',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        ..._entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _EntryRow(entry: entry),
                            )),
                      ] else ...[
                        const Center(
                          child: Text(
                            'No public entries',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Shared Profile Sub-Widgets ───────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final User user;
  final bool showFollowButton;
  final bool isFollowing;
  final bool isFollowLoading;
  final int followersCount;
  final int followingCount;
  final VoidCallback? onFollow;

  const _ProfileHeader({
    required this.user,
    required this.showFollowButton,
    this.isFollowing = false,
    this.isFollowLoading = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        WHAvatar(imageUrl: user.profilePictureUrl, name: user.name, radius: 36),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Text('@${user.username}', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
              if (user.bio != null && user.bio!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(user.bio!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (showFollowButton) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      height: 34,
                      child: ElevatedButton(
                        onPressed: isFollowLoading ? null : onFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing ? AppColors.surfaceHighest : AppColors.primary,
                          foregroundColor: isFollowing ? AppColors.textPrimary : Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: isFollowLoading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : Text(isFollowing ? 'Following' : 'Follow', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$followersCount followers · $followingCount following', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatCell(label: 'Total', value: '${stats['totalEntries'] ?? 0}'),
          _StatCell(label: 'Movies', value: '${stats['movieCount'] ?? 0}'),
          _StatCell(label: 'Shows', value: '${stats['tvShowCount'] ?? 0}'),
          _StatCell(
            label: 'Avg Rating',
            value: stats['averageRating'] != null ? (stats['averageRating'] as num).toStringAsFixed(1) : '–',
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  final Entry entry;
  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(entry.type == 'MOVIE' ? '🎬' : '📺', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.title,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (entry.rating != null) WHRatingStars(rating: entry.rating, size: 13),
        ],
      ),
    );
  }
}
