import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../repositories/search_repository.dart';

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
  List<MediaResult> _trending = [];
  bool _isSearching = false;
  bool _isTrendingLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    try {
      final results = await ref.read(searchRepositoryProvider).getTrending();
      setState(() {
        _trending = results;
        _isTrendingLoading = false;
      });
    } catch (_) {
      setState(() => _isTrendingLoading = false);
    }
  }

  Future<void> _search(String query) async {
    setState(() {
      _query = query;
      _mediaResults = [];
      _userResults = [];
    });
    if (query.length < 2) return;

    setState(() => _isSearching = true);
    try {
      final futures = await Future.wait([
        ref.read(searchRepositoryProvider).searchMedia(query),
        ref.read(searchRepositoryProvider).searchUsers(query),
      ]);
      setState(() {
        _mediaResults = futures[0] as List<MediaResult>;
        _userResults = futures[1] as List<User>;
        _isSearching = false;
      });
    } catch (_) {
      setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showResults = _query.length >= 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: _search,
          autofocus: false,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search movies, shows, people...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    _MediaResultsList(results: _mediaResults),
                    _UserResultsList(users: _userResults),
                  ],
                )
          : _TrendingView(
              trending: _trending,
              isLoading: _isTrendingLoading,
            ),
    );
  }
}

class _MediaResultsList extends StatelessWidget {
  final List<MediaResult> results;
  const _MediaResultsList({required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Center(
        child: Text('No media found', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final media = results[i];
        return _MediaTile(
          media: media,
          onTap: () => context.push('/details/${media.mediaType}/${media.id}'),
        );
      },
    );
  }
}

class _UserResultsList extends StatelessWidget {
  final List<User> users;
  const _UserResultsList({required this.users});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(
        child: Text('No users found', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, i) {
        final user = users[i];
        return InkWell(
          onTap: () => context.push('/profile/${user.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                WHAvatar(imageUrl: user.profilePictureUrl, name: user.name, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text('@${user.username}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrendingView extends StatelessWidget {
  final List<MediaResult> trending;
  final bool isLoading;
  const _TrendingView({required this.trending, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Trending Now 🔥',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        if (isLoading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
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
              itemCount: trending.length,
              itemBuilder: (context, i) {
                final media = trending[i];
                return _MediaPosterCard(
                  media: media,
                  onTap: () => context.push('/details/${media.mediaType}/${media.id}'),
                );
              },
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
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
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            TMDBPosterImage(
              posterPath: media.posterPath,
              width: double.infinity,
              height: double.infinity,
              borderRadius: 0,
            ),
            // Gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.5, 1.0],
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
            ),
            // Title
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Text(
                media.title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
