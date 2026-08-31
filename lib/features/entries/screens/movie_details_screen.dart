import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../../shared/widgets/wh_alert.dart';
import '../../search/repositories/search_repository.dart';
import '../../entries/screens/add_entry_sheet.dart';
import '../../entries/screens/entries_screen.dart';
import '../../entries/repositories/entries_repository.dart';
import '../widgets/suggest_movie_modal.dart';
import '../repositories/watchlist_repository.dart';
import '../../rankings/widgets/add_to_stack_sheet.dart';

class MovieDetailsScreen extends ConsumerStatefulWidget {
  final String mediaType;
  final int tmdbId;
  final String? suggestedByUserId;
  final User? suggestedByUser;

  const MovieDetailsScreen({
    super.key,
    required this.mediaType,
    required this.tmdbId,
    this.suggestedByUserId,
    this.suggestedByUser,
  });

  @override
  ConsumerState<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends ConsumerState<MovieDetailsScreen> {
  Map<String, dynamic>? _details;
  List<MediaResult> _recommendations = [];
  bool _isLoading = true;
  String? _error;

  // Watchlist & Transition States
  bool _inWatchlist = false;
  bool _isWatchlistLoading = false;
  bool _isTransitioning = false;

  // TV Seasons Drill-Down State
  int? _selectedSeasonNumber;
  Map<String, dynamic>? _seasonDetails;
  bool _isSeasonLoading = false;
  final Map<int, Map<String, dynamic>> _seasonCache = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadDetails(),
      _checkWatchlistStatus(),
      _loadRecommendations(),
    ]);
  }

  Future<void> _checkWatchlistStatus() async {
    try {
      final inList = await ref.read(watchlistRepositoryProvider).isInWatchlist(widget.tmdbId);
      if (mounted) setState(() => _inWatchlist = inList);
    } catch (_) {}
  }

  Future<void> _loadRecommendations() async {
    try {
      final recs = await ref.read(searchRepositoryProvider).getRecommendations(
        widget.mediaType == 'tv' ? 'tv' : 'movie',
        widget.tmdbId,
      );
      if (mounted) setState(() => _recommendations = recs);
    } catch (_) {}
  }

  Future<void> _loadDetails() async {
    try {
      final repo = ref.read(searchRepositoryProvider);
      final details = widget.mediaType == 'tv'
          ? await repo.getTvDetails(widget.tmdbId)
          : await repo.getMovieDetails(widget.tmdbId);

      if (mounted) {
        setState(() {
          _details = details;
          _isLoading = false;
        });

        // Initialize first TV season if TV show
        if (widget.mediaType == 'tv' && details != null) {
          final seasons = details['seasons'] as List<dynamic>? ?? [];
          if (seasons.isNotEmpty) {
            final validSeason = seasons.firstWhere(
              (s) => ((s as Map<String, dynamic>)['season_number'] as num?)?.toInt() != 0,
              orElse: () => seasons.first,
            ) as Map<String, dynamic>;
            final sNum = (validSeason['season_number'] as num?)?.toInt() ?? 1;
            _selectSeason(sNum);
          }
        }
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

  Future<void> _selectSeason(int seasonNumber) async {
    setState(() {
      _selectedSeasonNumber = seasonNumber;
      _isSeasonLoading = true;
    });

    if (_seasonCache.containsKey(seasonNumber)) {
      setState(() {
        _seasonDetails = _seasonCache[seasonNumber];
        _isSeasonLoading = false;
      });
      return;
    }

    try {
      final data = await ref.read(searchRepositoryProvider).getTvSeasonDetails(widget.tmdbId, seasonNumber);
      if (mounted) {
        _seasonCache[seasonNumber] = data;
        setState(() {
          _seasonDetails = data;
          _isSeasonLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSeasonLoading = false);
    }
  }

  Future<void> _toggleWatchlist() async {
    if (_isWatchlistLoading || _details == null) return;
    setState(() => _isWatchlistLoading = true);

    final title = (_details?['title'] ?? _details?['name'] ?? 'Movie/Show').toString();
    try {
      if (_inWatchlist) {
        await ref.read(watchlistRepositoryProvider).removeFromWatchlistByTmdbId(widget.tmdbId);
        setState(() => _inWatchlist = false);
        if (mounted) {
          WHAlert.showSuccess(context, 'Removed "$title" from Watchlist');
        }
      } else {
        await ref.read(watchlistRepositoryProvider).addToWatchlist(
          tmdbId: widget.tmdbId,
          title: title,
          mediaType: widget.mediaType,
          posterPath: _details?['poster_path'] as String?,
          overview: _details?['overview'] as String?,
          suggestedByUserId: widget.suggestedByUserId ?? widget.suggestedByUser?.id,
        );
        setState(() => _inWatchlist = true);
        if (mounted) {
          WHAlert.showSuccess(context, 'Added "$title" to your Watchlist! 📌');
        }
      }
    } catch (e) {
      if (mounted) WHAlert.showError(context, 'Watchlist update failed: $e');
    } finally {
      if (mounted) setState(() => _isWatchlistLoading = false);
    }
  }

  Future<void> _handleStartWatching() async {
    if (_isTransitioning || _details == null) return;

    final title = (_details?['title'] ?? _details?['name'] ?? 'Movie/Show').toString();
    final confirmed = await WHAlert.confirm(
      context,
      title: 'Log as Currently Watching',
      message: 'Would you like to move "$title" to your active Watching log?',
      confirmText: 'Move to Watching',
      severity: WHAlertSeverity.primary,
    );

    if (!confirmed) return;

    setState(() => _isTransitioning = true);
    try {
      final entry = await ref.read(entriesRepositoryProvider).createEntry({
        'tmdbId': widget.tmdbId,
        'title': title,
        'type': widget.mediaType == 'tv' ? 'TV_SHOW' : 'MOVIE',
        'isWatching': true,
        'startedAt': DateTime.now().toIso8601String(),
        'suggestedByUserId': widget.suggestedByUserId ?? widget.suggestedByUser?.id,
      });

      ref.read(entriesProvider(true).notifier).addEntry(entry);

      // Remove from watchlist if it was in watchlist
      if (_inWatchlist) {
        try {
          await ref.read(watchlistRepositoryProvider).removeFromWatchlistByTmdbId(widget.tmdbId);
          setState(() => _inWatchlist = false);
        } catch (_) {}
      }


      if (mounted) {
        WHAlert.showSuccess(context, 'Moved "$title" to Currently Watching! 👁️');
      }
    } catch (e) {
      if (mounted) WHAlert.showError(context, 'Failed to update watching status: $e');
    } finally {
      if (mounted) setState(() => _isTransitioning = false);
    }
  }

  void _logEntry() {
    final details = _details;
    if (details == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: AddEntrySheet(
          prefillTmdbId: widget.tmdbId,
          prefillType: widget.mediaType == 'tv' ? 'TV_SHOW' : 'MOVIE',
          prefillSuggestor: widget.suggestedByUser,
          prefillSuggestedByUserId: widget.suggestedByUserId,
        ),
      ),
    );
  }

  void _openSuggestModal() {
    final title = (_details?['title'] ?? _details?['name'] ?? 'Movie/Show').toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SuggestMovieModal(
        tmdbId: widget.tmdbId,
        title: title,
        mediaType: widget.mediaType,
      ),
    );
  }

  void _shareMovie() {
    final title = (_details?['title'] ?? _details?['name'] ?? 'Movie/Show').toString();
    Share.share(
      'Check out "$title" on WatchHive! Track movies, series & anime together 🎬🐝',
      subject: 'WatchHive: $title',
    );
  }

  String _formatCategoryLabel() {
    if (_details == null) return widget.mediaType == 'tv' ? '📺 TV Series' : '🎬 Feature Film';
    final genres = (_details!['genres'] as List<dynamic>? ?? [])
        .map((g) => (g['name'] as String? ?? '').toLowerCase())
        .toList();
    final isAnimation = genres.contains('animation');
    final isDoc = genres.contains('documentary');
    final lang = (_details!['original_language'] as String? ?? '').toLowerCase();
    final countries = (_details!['origin_country'] as List<dynamic>? ?? [])
        .map((c) => c.toString())
        .toList();

    if (isDoc) return '📽️ Documentary';
    if (isAnimation && (lang == 'ja' || countries.contains('JP'))) return '🎌 Anime';
    if (widget.mediaType == 'tv' && (lang == 'ko' || countries.contains('KR'))) return '🇰🇷 K-Drama';
    if (widget.mediaType == 'tv' && (lang == 'ja' || countries.contains('JP')) && !isAnimation) return '🇯🇵 J-Drama';
    if (widget.mediaType == 'tv') {
      final seasons = (_details!['number_of_seasons'] as num?)?.toInt() ?? 1;
      if (seasons == 1) return '⚡ Miniseries / Limited';
      return '📺 TV Series';
    }
    return '🎬 Feature Film';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'TBA';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMMM d, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _launchProviderUrl(String providerName, String? fallbackLink, String title) async {
    final name = providerName.toLowerCase();
    final query = Uri.encodeComponent(title);
    String url = fallbackLink ?? 'https://www.google.com/search?q=$query+watch+online';

    if (name.contains('netflix')) {
      url = 'https://www.netflix.com/search?q=$query';
    } else if (name.contains('amazon') || name.contains('prime')) {
      url = 'https://www.primevideo.com/search/ref=atv_sr_sug_1?phrase=$query';
    } else if (name.contains('hotstar') || name.contains('disney')) {
      url = 'https://www.hotstar.com/in/explore?searchQuery=$query';
    } else if (name.contains('zee5')) {
      url = 'https://www.zee5.com/search?q=$query';
    } else if (name.contains('sonyliv')) {
      url = 'https://www.sonyliv.com/search?query=$query';
    } else if (name.contains('jiocinema')) {
      url = 'https://www.jiocinema.com/search?q=$query';
    } else if (name.contains('apple')) {
      url = 'https://tv.apple.com/in/search?q=$query';
    } else if (name.contains('youtube')) {
      url = 'https://www.youtube.com/results?search_query=$query+movie';
    }

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) WHAlert.showError(context, 'Could not open streaming link');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_error != null || _details == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.movie_creation_outlined, color: AppColors.error, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load cinematic details',
                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'The hive is a bit busy right now.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadInitialData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final details = _details!;
    final title = (details['title'] ?? details['name'] ?? 'Untitled').toString();
    final overview = details['overview'] as String? ?? '';
    final posterPath = details['poster_path'] as String?;
    final backdropPath = details['backdrop_path'] as String?;
    final releaseDate = (details['release_date'] ?? details['first_air_date']) as String? ?? '';
    final voteAverage = (details['vote_average'] as num?)?.toDouble();
    final voteCount = (details['vote_count'] as num?)?.toInt();
    final genres = (details['genres'] as List<dynamic>?)
            ?.map((g) => (g as Map<String, dynamic>)['name'] as String)
            .toList() ??
        [];
    final runtime = details['runtime'] as int? ??
        (details['episode_run_time'] is List && (details['episode_run_time'] as List).isNotEmpty
            ? ((details['episode_run_time'] as List).first as num?)?.toInt()
            : null);
    final tagline = details['tagline'] as String? ?? '';
    final awards = details['awards'] as String?;
    final criticRatings = details['critic_ratings'] as List<dynamic>? ?? [];
    final boxOffice = details['box_office'] as String?;

    // Star Cast
    final castList = (details['credits']?['cast'] ?? details['aggregate_credits']?['cast']) as List<dynamic>? ?? [];

    // Watch Providers
    final watchProvidersData = details['watch/providers']?['results'] as Map<String, dynamic>?;
    final localProviders = watchProvidersData != null
        ? (watchProvidersData['IN'] ?? watchProvidersData['US'] ?? (watchProvidersData.isNotEmpty ? watchProvidersData.values.first : null))
        : null;

    final streamProviders = (localProviders?['flatrate'] ?? localProviders?['free']) as List<dynamic>? ?? [];
    final rentProviders = localProviders?['rent'] as List<dynamic>? ?? [];
    final buyProviders = localProviders?['buy'] as List<dynamic>? ?? [];

    // Seasons List
    final seasons = details['seasons'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // 1. Cinematic Hero Backdrop Header
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.black.withOpacity(0.55),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black.withOpacity(0.55),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                      onPressed: _shareMovie,
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (backdropPath != null)
                    CachedNetworkImage(
                      imageUrl: 'https://image.tmdb.org/t/p/w780$backdropPath',
                      fit: BoxFit.cover,
                    )
                  else if (posterPath != null)
                    CachedNetworkImage(
                      imageUrl: 'https://image.tmdb.org/t/p/w780$posterPath',
                      fit: BoxFit.cover,
                    )
                  else
                    Container(color: AppColors.surface),

                  // Gradient Overlays
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC000000), AppColors.background],
                        stops: [0.3, 0.75, 1.0],
                      ),
                    ),
                  ),

                  // Hero bottom info
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Format Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
                            ],
                          ),
                          child: Text(
                            _formatCategoryLabel(),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                            shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (tagline.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '"$tagline"',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withOpacity(0.85),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (genres.isNotEmpty)
                              Text(
                                genres.take(2).join(' • '),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                              ),
                            if (genres.isNotEmpty && releaseDate.isNotEmpty)
                              const Text('  •  ', style: TextStyle(color: Colors.white38)),
                            if (releaseDate.isNotEmpty)
                              Text(
                                releaseDate.length >= 4 ? releaseDate.substring(0, 4) : releaseDate,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                              ),
                            if (runtime != null) ...[
                              const Text('  •  ', style: TextStyle(color: Colors.white38)),
                              Text(
                                '${runtime}m',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Main Content Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Bar (Web Parity)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Watchlist Toggle
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _inWatchlist ? AppColors.primary : AppColors.surfaceElevated,
                                  foregroundColor: _inWatchlist ? Colors.black : AppColors.textPrimary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: _toggleWatchlist,
                                icon: _isWatchlistLoading
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Icon(
                                        _inWatchlist ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                                        size: 18,
                                      ),
                                label: Text(
                                  _inWatchlist ? 'In Watchlist' : 'Add to Watchlist',
                                  style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Log Watch
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: _logEntry,
                                icon: const Icon(Icons.edit_note_rounded, size: 20),
                                label: const Text(
                                  'Log Watch',
                                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Currently Watching (if in watchlist or available)
                            if (_inWatchlist) ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: const BorderSide(color: AppColors.border),
                                    padding: const EdgeInsets.symmetric(vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: _handleStartWatching,
                                  icon: _isTransitioning
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.visibility_rounded, size: 16, color: AppColors.primary),
                                  label: const Text(
                                    'Log Currently Watching',
                                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 11),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],

                            // Suggest to Friends
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: const BorderSide(color: AppColors.border),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: _openSuggestModal,
                                icon: const Icon(Icons.send_rounded, size: 15, color: AppColors.primary),
                                label: const Text(
                                  'Suggest',
                                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 11),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Rank in Stack
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: const BorderSide(color: AppColors.border),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () {
                                  AddToStackSheet.show(
                                    context,
                                    tmdbId: widget.tmdbId,
                                    title: title,
                                    posterPath: posterPath,
                                    mediaType: widget.mediaType,
                                  );
                                },
                                icon: const Icon(Icons.format_list_numbered_rounded, size: 15, color: AppColors.primary),
                                label: const Text(
                                  'Rank 🏆',
                                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Accolades & Awards Section (if present)
                  if (awards != null && awards.isNotEmpty || criticRatings.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary.withOpacity(0.12), AppColors.surface],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('🏆', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Accolades & Reception',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (awards != null && awards.isNotEmpty)
                                      Text(
                                        awards,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (criticRatings.isNotEmpty || boxOffice != null) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...criticRatings.map((r) {
                                  final source = r['Source']?.toString() ?? 'Critic';
                                  final val = r['Value']?.toString() ?? '';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Text(
                                      '$source: $val',
                                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    ),
                                  );
                                }),
                                if (boxOffice != null && boxOffice.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      'Box Office: $boxOffice',
                                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Synopsis / Overview
                  const Text(
                    'Synopsis',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    overview.isNotEmpty ? overview : 'No synopsis available for this title.',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Metadata 4-Card Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                    children: [
                      _StatCard(
                        label: 'TMDB Score',
                        value: voteAverage != null && voteAverage > 0
                            ? '⭐ ${voteAverage.toStringAsFixed(1)}'
                            : 'N/A',
                        subtitle: voteCount != null ? '($voteCount votes)' : null,
                      ),
                      _StatCard(
                        label: 'Release Date',
                        value: _formatDate(releaseDate),
                      ),
                      _StatCard(
                        label: 'Runtime',
                        value: runtime != null ? '${runtime}m' : 'N/A',
                      ),
                      _StatCard(
                        label: 'Format',
                        value: _formatCategoryLabel(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Where to Watch (Streaming Providers)
                  if (streamProviders.isNotEmpty || rentProviders.isNotEmpty || buyProviders.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Where to Watch (India / Global)',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (streamProviders.isNotEmpty) ...[
                            _ProviderRow(
                              typeLabel: 'Stream:',
                              providers: streamProviders,
                              fallbackLink: localProviders?['link'] as String?,
                              title: title,
                              onTapProvider: _launchProviderUrl,
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (rentProviders.isNotEmpty) ...[
                            _ProviderRow(
                              typeLabel: 'Rent:',
                              providers: rentProviders,
                              fallbackLink: localProviders?['link'] as String?,
                              title: title,
                              onTapProvider: _launchProviderUrl,
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (buyProviders.isNotEmpty)
                            _ProviderRow(
                              typeLabel: 'Buy:',
                              providers: buyProviders,
                              fallbackLink: localProviders?['link'] as String?,
                              title: title,
                              onTapProvider: _launchProviderUrl,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Star Cast Carousel
                  if (castList.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cast & Performers',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${castList.length} members',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 156,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: castList.take(15).length,
                        itemBuilder: (context, i) {
                          final member = castList[i] as Map<String, dynamic>;
                          final name = member['name'] as String? ?? '';
                          final char = member['character'] as String? ?? '';
                          final profilePath = member['profile_path'] as String?;

                          return Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: AppColors.surfaceElevated,
                                  backgroundImage: profilePath != null
                                      ? CachedNetworkImageProvider('https://image.tmdb.org/t/p/w185$profilePath')
                                      : null,
                                  child: profilePath == null
                                      ? const Icon(Icons.person, color: AppColors.textMuted, size: 24)
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  name,
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                if (char.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    char,
                                    style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // TV Seasons & Episode Drill Down
                  if (widget.mediaType == 'tv' && seasons.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Seasons & Episode Guide',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Season Selector Tabs
                          SizedBox(
                            height: 38,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: seasons.length,
                              itemBuilder: (context, i) {
                                final s = seasons[i] as Map<String, dynamic>;
                                final sNum = (s['season_number'] as num?)?.toInt() ?? 1;
                                final sName = s['name'] as String? ?? 'Season $sNum';
                                final epCount = s['episode_count'] as int? ?? 0;
                                final isSelected = _selectedSeasonNumber == sNum;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text('$sName ($epCount eps)'),
                                    selected: isSelected,
                                    onSelected: (_) => _selectSeason(sNum),
                                    selectedColor: AppColors.primary,
                                    backgroundColor: AppColors.surfaceElevated,
                                    labelStyle: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.black : AppColors.textPrimary,
                                    ),
                                    side: BorderSide(
                                      color: isSelected ? AppColors.primary : AppColors.border,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Episodes List
                          if (_isSeasonLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(color: AppColors.primary),
                              ),
                            )
                          else if (_seasonDetails?['episodes'] != null && (_seasonDetails!['episodes'] as List).isNotEmpty)
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: (_seasonDetails!['episodes'] as List).length,
                              itemBuilder: (context, i) {
                                final ep = (_seasonDetails!['episodes'] as List)[i] as Map<String, dynamic>;
                                final epNum = ep['episode_number'] as int? ?? (i + 1);
                                final epName = ep['name'] as String? ?? 'Episode $epNum';
                                final epOverview = ep['overview'] as String? ?? '';
                                final epStill = ep['still_path'] as String?;
                                final epAirDate = ep['air_date'] as String?;
                                final epRating = (ep['vote_average'] as num?)?.toDouble();

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Episode Still / Thumbnail
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          width: 90,
                                          height: 60,
                                          child: epStill != null
                                              ? CachedNetworkImage(
                                                  imageUrl: 'https://image.tmdb.org/t/p/w300$epStill',
                                                  fit: BoxFit.cover,
                                                )
                                              : Container(
                                                  color: AppColors.surface,
                                                  child: const Icon(Icons.tv_rounded, color: AppColors.textMuted),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'EP $epNum',
                                                    style: const TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    epName,
                                                    style: const TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (epRating != null && epRating > 0) ...[
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '⭐ ${epRating.toStringAsFixed(1)}',
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (epAirDate != null && epAirDate.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatDate(epAirDate),
                                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                              ),
                                            ],
                                            if (epOverview.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                epOverview,
                                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: Text('No episode details available.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Recommendations Carousel
                  if (_recommendations.isNotEmpty) ...[
                    const Text(
                      'More Like This',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recommendations.length,
                        itemBuilder: (context, i) {
                          final rec = _recommendations[i];
                          return GestureDetector(
                            onTap: () {
                              context.push('/details/${rec.mediaType}/${rec.id}');
                            },
                            child: Container(
                              width: 110,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: TMDBPosterImage(
                                      posterPath: rec.posterPath,
                                      width: 110,
                                      height: 140,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    rec.title,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;

  const _StatCard({
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  final String typeLabel;
  final List<dynamic> providers;
  final String? fallbackLink;
  final String title;
  final Function(String, String?, String) onTapProvider;

  const _ProviderRow({
    required this.typeLabel,
    required this.providers,
    required this.fallbackLink,
    required this.title,
    required this.onTapProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            typeLabel,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: providers.map((p) {
                final logo = p['logo_path'] as String?;
                final name = p['provider_name'] as String? ?? 'Provider';

                return GestureDetector(
                  onTap: () => onTapProvider(name, fallbackLink, title),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Tooltip(
                      message: name,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: logo != null
                            ? CachedNetworkImage(
                                imageUrl: 'https://image.tmdb.org/t/p/w92$logo',
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 36,
                                height: 36,
                                color: AppColors.surfaceElevated,
                                child: const Icon(Icons.play_circle_outline, size: 20),
                              ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

