import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../repositories/search_repository.dart';
import '../../profile/repositories/user_repository.dart';

enum TrendingFilter {
  allTrending('🔥 All Trending', 'all', 'trending'),
  trendingMovies('🎬 Movies', 'movie', 'trending'),
  trendingTv('📺 TV Shows', 'tv', 'trending'),
  popularMovies('⭐ Popular Movies', 'movie', 'popular'),
  popularTv('📺 Popular TV', 'tv', 'popular');

  final String label;
  final String mediaType;
  final String category; // 'trending' | 'popular'
  const TrendingFilter(this.label, this.mediaType, this.category);
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final TabController _tabController;

  List<MediaResult> _mediaResults = [];
  List<User> _userResults = [];
  List<MediaResult> _discoveryMedia = [];
  List<User> _suggestedUsers = [];
  List<Map<String, dynamic>> _communityBuzz = [];
  List<String> _recentSearches = [];

  TrendingFilter _selectedFilter = TrendingFilter.allTrending;
  bool _isSearching = false;
  bool _isDiscoveryLoading = true;
  bool _isSuggestedUsersLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialDiscovery();
  }

  Future<void> _loadInitialDiscovery() async {
    _loadDiscoveryMedia(_selectedFilter);
    _loadSuggestedUsers();
    _loadCommunityBuzz();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final list = await ref.read(searchRepositoryProvider).getRecentSearches();
    if (mounted) {
      setState(() => _recentSearches = list);
    }
  }

  Future<void> _loadCommunityBuzz() async {
    final list = await ref.read(searchRepositoryProvider).getCommunityTrending();
    if (mounted) {
      setState(() => _communityBuzz = list);
    }
  }

  Future<void> _loadDiscoveryMedia(TrendingFilter filter) async {
    setState(() {
      _selectedFilter = filter;
      _isDiscoveryLoading = true;
    });

    try {
      final repo = ref.read(searchRepositoryProvider);
      final List<MediaResult> results;

      if (filter.category == 'popular') {
        results = await repo.getPopular(type: filter.mediaType);
      } else {
        results = await repo.getTrending(mediaType: filter.mediaType, timeWindow: 'week');
      }

      if (mounted) {
        setState(() {
          _discoveryMedia = results;
          _isDiscoveryLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isDiscoveryLoading = false);
    }
  }

  Future<void> _loadSuggestedUsers() async {
    try {
      final results = await ref.read(searchRepositoryProvider).getSuggestedUsers();
      if (mounted) {
        setState(() {
          _suggestedUsers = results;
          _isSuggestedUsersLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSuggestedUsersLoading = false);
    }
  }

  Future<void> _search(String query) async {
    setState(() {
      _query = query;
      _mediaResults = [];
      _userResults = [];
    });
    if (query.trim().length < 2) return;

    setState(() => _isSearching = true);
    try {
      final futures = await Future.wait([
        ref.read(searchRepositoryProvider).searchMedia(query.trim()),
        ref.read(searchRepositoryProvider).searchUsers(query.trim()),
      ]);
      if (mounted) {
        setState(() {
          _mediaResults = futures[0] as List<MediaResult>;
          _userResults = futures[1] as List<User>;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSubmittedSearch(String query) {
    if (query.trim().isNotEmpty) {
      ref.read(searchRepositoryProvider).addRecentSearch(query.trim());
      _loadRecentSearches();
    }
    _search(query);
  }

  void _selectSearchTerm(String term) {
    _searchController.text = term;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: term.length),
    );
    _onSubmittedSearch(term);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showResults = _query.trim().length >= 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: _search,
          onSubmitted: _onSubmittedSearch,
          autofocus: false,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search movies, TV shows, cinephiles...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: AppColors.textMuted),
                    onPressed: () {
                      _searchController.clear();
                      _search('');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
        bottom: showResults
            ? TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                tabs: [
                  Tab(text: 'Media (${_mediaResults.length})'),
                  Tab(text: 'People (${_userResults.length})'),
                ],
              )
            : null,
      ),
      body: showResults
          ? _isSearching
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _MediaResultsList(
                      results: _mediaResults,
                      onSelectMedia: (m) => ref.read(searchRepositoryProvider).addRecentSearch(m.title),
                    ),
                    _UserResultsList(
                      users: _userResults,
                      onSelectUser: (u) => ref.read(searchRepositoryProvider).addRecentSearch(u.username),
                    ),
                  ],
                )
          : _DiscoveryView(
              discoveryMedia: _discoveryMedia,
              suggestedUsers: _suggestedUsers,
              communityBuzz: _communityBuzz,
              recentSearches: _recentSearches,
              selectedFilter: _selectedFilter,
              isDiscoveryLoading: _isDiscoveryLoading,
              isSuggestedUsersLoading: _isSuggestedUsersLoading,
              onFilterChanged: _loadDiscoveryMedia,
              onRefreshUsers: _loadSuggestedUsers,
              onSelectRecentSearch: _selectSearchTerm,
              onRemoveRecentSearch: (query) async {
                await ref.read(searchRepositoryProvider).removeRecentSearch(query);
                _loadRecentSearches();
              },
              onClearRecentSearches: () async {
                await ref.read(searchRepositoryProvider).clearRecentSearches();
                _loadRecentSearches();
              },
            ),
    );
  }
}

class _MediaResultsList extends StatelessWidget {
  final List<MediaResult> results;
  final Function(MediaResult) onSelectMedia;

  const _MediaResultsList({
    required this.results,
    required this.onSelectMedia,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.movie_filter_outlined, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('No movies or series found', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
            SizedBox(height: 4),
            Text('Try searching with another title', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final media = results[i];
        return _MediaTile(
          media: media,
          onTap: () {
            onSelectMedia(media);
            context.push('/details/${media.mediaType}/${media.id}');
          },
        );
      },
    );
  }
}

class _UserResultsList extends StatelessWidget {
  final List<User> users;
  final Function(User) onSelectUser;

  const _UserResultsList({
    required this.users,
    required this.onSelectUser,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.person_search_rounded, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('No users found', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
            SizedBox(height: 4),
            Text('Try searching with another username or name', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: users.length,
      itemBuilder: (context, i) {
        final user = users[i];
        return _UserTile(
          user: user,
          onTap: () {
            onSelectUser(user);
            context.push('/profile/${user.id}');
          },
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  final User user;
  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              WHAvatar(imageUrl: user.profilePictureUrl, name: user.name, radius: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isPrivate) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textMuted),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.bio!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryView extends StatelessWidget {
  final List<MediaResult> discoveryMedia;
  final List<User> suggestedUsers;
  final List<Map<String, dynamic>> communityBuzz;
  final List<String> recentSearches;
  final TrendingFilter selectedFilter;
  final bool isDiscoveryLoading;
  final bool isSuggestedUsersLoading;
  final Function(TrendingFilter) onFilterChanged;
  final VoidCallback onRefreshUsers;
  final Function(String) onSelectRecentSearch;
  final Function(String) onRemoveRecentSearch;
  final VoidCallback onClearRecentSearches;

  const _DiscoveryView({
    required this.discoveryMedia,
    required this.suggestedUsers,
    required this.communityBuzz,
    required this.recentSearches,
    required this.selectedFilter,
    required this.isDiscoveryLoading,
    required this.isSuggestedUsersLoading,
    required this.onFilterChanged,
    required this.onRefreshUsers,
    required this.onSelectRecentSearch,
    required this.onRemoveRecentSearch,
    required this.onClearRecentSearches,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // 1. Recent Searches Section (if any)
        if (recentSearches.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history_rounded, size: 18, color: AppColors.textMuted),
                      SizedBox(width: 6),
                      Text(
                        'Recent Searches',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: onClearRecentSearches,
                    child: const Text(
                      'Clear All',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recentSearches.length,
                itemBuilder: (context, i) {
                  final term = recentSearches[i];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: InputChip(
                      label: Text(
                        term,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onPressed: () => onSelectRecentSearch(term),
                      onDeleted: () => onRemoveRecentSearch(term),
                      deleteIcon: const Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted),
                    ),
                  );
                },
              ),
            ),
          ),
        ],

        // 2. Suggested Cinephiles Section
        if (suggestedUsers.isNotEmpty || isSuggestedUsersLoading) ...[
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Icon(Icons.stars_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Suggested Cinephiles 🐝',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSuggestedUsersLoading)
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            )
          else
            SliverToBoxAdapter(
              child: SizedBox(
                height: 148,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: suggestedUsers.length,
                  itemBuilder: (context, i) {
                    final user = suggestedUsers[i];
                    return _SuggestedUserCard(user: user, onRefresh: onRefreshUsers);
                  },
                ),
              ),
            ),
        ],

        // 3. Community Buzz Topics (if any)
        if (communityBuzz.isNotEmpty) ...[
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Buzzing in the Hive 🐝',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 42,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: communityBuzz.length,
                itemBuilder: (context, i) {
                  final item = communityBuzz[i];
                  final title = item['title']?.toString() ?? '';
                  final contextText = item['context']?.toString() ?? 'Trending';
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.bolt_rounded, size: 14, color: AppColors.primary),
                      label: Text(
                        '$title · $contextText',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onPressed: () => onSelectRecentSearch(title),
                    ),
                  );
                },
              ),
            ),
          ),
        ],

        // 4. Trending & Popular Media Section
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: Colors.deepOrangeAccent, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Trending & Popular',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (discoveryMedia.isNotEmpty)
                  Text(
                    '${discoveryMedia.length} titles',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Filter Chips Row
        SliverToBoxAdapter(
          child: SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: TrendingFilter.values.map((filter) {
                final isSelected = selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter.label),
                    selected: isSelected,
                    onSelected: (_) => onFilterChanged(filter),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.black : AppColors.textSecondary,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Discovery Media Grid
        if (isDiscoveryLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          )
        else if (discoveryMedia.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.movie_creation_outlined, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  const Text('No trending titles available', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => onFilterChanged(selectedFilter),
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 18),
                    label: const Text('Retry Loading', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemCount: discoveryMedia.length,
              itemBuilder: (context, i) {
                final media = discoveryMedia[i];
                return _MediaPosterCard(
                  media: media,
                  onTap: () {
                    onSelectRecentSearch(media.title);
                    context.push('/details/${media.mediaType}/${media.id}');
                  },
                );
              },
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }
}

class _SuggestedUserCard extends ConsumerStatefulWidget {
  final User user;
  final VoidCallback onRefresh;
  const _SuggestedUserCard({required this.user, required this.onRefresh});

  @override
  ConsumerState<_SuggestedUserCard> createState() => _SuggestedUserCardState();
}

class _SuggestedUserCardState extends ConsumerState<_SuggestedUserCard> {
  bool _isFollowing = false;
  bool _isLoading = false;

  Future<void> _toggleFollow() async {
    setState(() => _isLoading = true);
    try {
      if (_isFollowing) {
        await ref.read(userRepositoryProvider).unfollowUser(widget.user.id);
        setState(() => _isFollowing = false);
      } else {
        await ref.read(userRepositoryProvider).followUser(widget.user.id);
        setState(() => _isFollowing = true);
        if (mounted) {
          WHAlert.showSuccess(context, 'Followed @${widget.user.username}! ✨');
        }
      }
    } catch (e) {
      if (mounted) WHAlert.showError(context, 'Action failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/profile/${widget.user.id}'),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            WHAvatar(imageUrl: widget.user.profilePictureUrl, name: widget.user.name, radius: 22),
            const SizedBox(height: 6),
            Text(
              widget.user.name,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '@${widget.user.username}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 26,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing ? AppColors.surfaceElevated : AppColors.primary,
                  foregroundColor: _isFollowing ? AppColors.textPrimary : Colors.black,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isLoading ? null : _toggleFollow,
                child: _isLoading
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(
                        _isFollowing ? 'Following' : 'Follow',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPosterCard extends StatelessWidget {
  final MediaResult media;
  final VoidCallback onTap;
  const _MediaPosterCard({required this.media, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            TMDBPosterImage(
              posterPath: media.posterPath,
              width: double.infinity,
              height: double.infinity,
              borderRadius: 0,
            ),
            // Top badges (Media type & Rating)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      media.mediaType == 'tv' ? '📺 TV' : '🎬 MOVIE',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (media.voteAverage != null && media.voteAverage! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 10, color: Colors.black),
                          const SizedBox(width: 2),
                          Text(
                            media.voteAverage!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Bottom Gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.45, 1.0],
                  colors: [Colors.transparent, Color(0xEE000000)],
                ),
              ),
            ),
            // Title & Year
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    media.title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (media.year.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      media.year,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final MediaResult media;
  final VoidCallback onTap;
  const _MediaTile({required this.media, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            TMDBPosterImage(posterPath: media.posterPath, width: 56, height: 80),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.title,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${media.mediaType == "movie" ? "🎬 Movie" : "📺 TV Show"} · ${media.year}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  if (media.voteAverage != null && media.voteAverage! > 0) ...[
                    const SizedBox(height: 4),
                    WHRatingStars(rating: media.voteAverage),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

