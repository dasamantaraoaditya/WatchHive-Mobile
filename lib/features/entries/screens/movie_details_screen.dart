import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/navigation_extensions.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/user.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../search/repositories/search_repository.dart';
import '../../entries/screens/add_entry_sheet.dart';
import '../../entries/screens/entries_screen.dart';
import '../../entries/repositories/entries_repository.dart';
import '../../../core/api/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/suggest_movie_modal.dart';
import '../repositories/watchlist_repository.dart';
import '../../rankings/widgets/add_to_stack_sheet.dart';
import '../../feed/providers/feed_provider.dart';
import '../widgets/platform_logo_badge.dart';
import '../widgets/add_to_watchlist_sheet.dart';
import '../../profile/repositories/user_repository.dart';
import '../../scanner/widgets/movie_qr_dialog.dart';
import '../../onboarding/widgets/screen_guide_dialog.dart';
import '../../../core/utils/share_helper.dart';
import '../widgets/friends_watched_bar.dart';
import '../widgets/friends_who_watched_sheet.dart';
import '../widgets/post_log_success_dialog.dart';
import '../repositories/episode_repository.dart';
import '../providers/continue_watching_provider.dart';

class MovieDetailsScreen extends ConsumerStatefulWidget {
  final String mediaType;
  final int tmdbId;
  final Entry? initialEntry;
  final User? authorUser;
  final String? suggestedByUserId;
  final User? suggestedByUser;

  const MovieDetailsScreen({
    super.key,
    required this.mediaType,
    required this.tmdbId,
    this.initialEntry,
    this.authorUser,
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
  late bool _effectiveIsTv;

  bool get _isTv {
    final t = widget.mediaType.trim().toLowerCase();
    return t == 'tv' || t == 'tv_show' || t == 'series';
  }

  // Logged Watch Entry & Review State
  Entry? _loggedEntry;
  User? _authorUser;
  Entry? _myOwnEntry;
  List<Entry> _friendsEntries = [];

  // Watchlist & Transition States
  bool _inWatchlist = false;
  bool _isWatchlistLoading = false;
  bool _isTransitioning = false;
  User? _watchlistSuggestedByUser;
  String? _watchlistSuggestedByUserId;
  User? _suggestedByUser;
  String? _suggestedByUserId;

  User? get _effectiveSuggestor =>
      _suggestedByUser ?? widget.suggestedByUser ?? _watchlistSuggestedByUser;

  String? get _effectiveSuggestorId =>
      _suggestedByUserId ??
      widget.suggestedByUserId ??
      _watchlistSuggestedByUserId ??
      _effectiveSuggestor?.id;

  // TV Seasons Drill-Down State
  int? _selectedSeasonNumber;
  Map<String, dynamic>? _seasonDetails;
  bool _isSeasonLoading = false;
  final Map<int, Map<String, dynamic>> _seasonCache = {};
  ShowProgress? _showProgress;
  List<FriendShowProgress> _friendsShowProgress = [];
  String? _togglingEpisodeKey;

  @override
  void initState() {
    super.initState();
    _effectiveIsTv = _isTv;
    _loggedEntry = widget.initialEntry;
    _authorUser = widget.authorUser ?? widget.initialEntry?.user;
    _suggestedByUser = widget.suggestedByUser;
    _suggestedByUserId = widget.suggestedByUserId ?? widget.suggestedByUser?.id;
    if (_suggestedByUserId != null && _suggestedByUserId!.isNotEmpty) {
      if (_suggestedByUser == null || _suggestedByUser!.displayName == null) {
        _fetchSuggestorProfile(_suggestedByUserId!);
      }
    }
    _loadInitialData();
  }

  Future<void> _fetchSuggestorProfile(String userId) async {
    try {
      final user = await ref.read(userRepositoryProvider).getUserProfile(userId);
      if (mounted) {
        setState(() {
          _suggestedByUser = user;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadInitialData() async {
    _loadFriendsEntries();
    await Future.wait([
      _loadDetails(),
      _checkWatchlistStatus(),
      _loadRecommendations(),
      _fetchSocialEntries(),
    ]);
    await _checkUserEntry();
    _loadFriendsEntries();
  }

  Future<void> _fetchSocialEntries() async {
    try {
      final currentUser = ref.read(authStateProvider).value?.user;
      final social = await ref.read(entriesRepositoryProvider).getMediaSocialEntries(widget.tmdbId);

      if (!mounted) return;

      // 1. Resolve user entry if not already set or if user is viewing their own details
      if (social.userEntry != null) {
        if (_loggedEntry == null || _isMyEntry) {
          final effective = (social.userEntry!.suggestedByUser == null && widget.suggestedByUser != null)
              ? social.userEntry!.copyWith(
                  suggestedByUser: widget.suggestedByUser,
                  suggestedByUserId: widget.suggestedByUserId ?? widget.suggestedByUser?.id,
                )
              : social.userEntry!;
          setState(() {
            _loggedEntry = effective;
            _authorUser = effective.user ?? currentUser;
          });
        } else if (_loggedEntry != null && !_isMyEntry) {
          setState(() {
            _myOwnEntry = social.userEntry;
          });
        }
      }

      // 2. Resolve friends entries
      final Map<String, Entry> friendsMap = {};
      for (final fe in social.friendsEntries) {
        if (currentUser == null || fe.userId != currentUser.id) {
          friendsMap[fe.userId] = fe;
        }
      }

      // Preserve initialEntry if from a friend
      if (widget.initialEntry != null) {
        final uid = widget.initialEntry!.userId;
        if (currentUser == null || uid != currentUser.id) {
          var entry = widget.initialEntry!;
          if (entry.user == null && widget.authorUser != null) {
            entry = entry.copyWith(user: widget.authorUser);
          }
          if (!friendsMap.containsKey(uid) || friendsMap[uid]!.user == null) {
            friendsMap[uid] = entry;
          }
        }
      }

      // Preserve _loggedEntry if from someone else
      if (_loggedEntry != null) {
        final uid = _loggedEntry!.userId;
        if (currentUser == null || uid != currentUser.id) {
          var entry = _loggedEntry!;
          if (entry.user == null && _authorUser != null) {
            entry = entry.copyWith(user: _authorUser);
          }
          if (!friendsMap.containsKey(uid) || friendsMap[uid]!.user == null) {
            friendsMap[uid] = entry;
          }
        }
      }

      if (mounted) {
        setState(() {
          _friendsEntries = friendsMap.values.toList();
        });
      }
    } catch (_) {}
  }

  void _loadFriendsEntries() {
    final currentUser = ref.read(authStateProvider).value?.user;
    final Map<String, Entry> friendsMap = {};

    // 0. Seed with existing friends entries
    for (final e in _friendsEntries) {
      friendsMap[e.userId] = e;
    }

    // 1. Initial entry if from a friend
    if (widget.initialEntry != null) {
      final uid = widget.initialEntry!.userId;
      if (currentUser == null || uid != currentUser.id) {
        var entry = widget.initialEntry!;
        if (entry.user == null && widget.authorUser != null) {
          entry = entry.copyWith(user: widget.authorUser);
        }
        if (!friendsMap.containsKey(uid) || friendsMap[uid]!.user == null) {
          friendsMap[uid] = entry;
        }
      }
    }

    // 2. Scan feed entries matching this movie/show
    try {
      final feedEntries = ref.read(feedProvider).entries;
      final currentTitle = (_details?['title'] ?? _details?['name'] ?? '').toString().trim().toLowerCase();
      for (final entry in feedEntries) {
        final matchesTmdb = entry.tmdbId == widget.tmdbId;
        final matchesTitle = currentTitle.isNotEmpty &&
            entry.title.trim().toLowerCase() == currentTitle;

        if (matchesTmdb || matchesTitle) {
          final uid = entry.userId;
          if (currentUser == null || uid != currentUser.id) {
            if (!friendsMap.containsKey(uid) || (friendsMap[uid]!.user == null && entry.user != null)) {
              friendsMap[uid] = entry;
            }
          }
        }
      }
    } catch (_) {}

    // 3. Current _loggedEntry if it belongs to someone else
    if (_loggedEntry != null) {
      final uid = _loggedEntry!.userId;
      if (currentUser == null || uid != currentUser.id) {
        var entry = _loggedEntry!;
        if (entry.user == null && _authorUser != null) {
          entry = entry.copyWith(user: _authorUser);
        }
        if (!friendsMap.containsKey(uid) || (friendsMap[uid]!.user == null && entry.user != null)) {
          friendsMap[uid] = entry;
        }
      }
    }

    final list = friendsMap.values.toList();
    if (mounted) {
      setState(() {
        _friendsEntries = list;
      });
    }
  }

  Future<void> _checkUserEntry() async {
    try {
      final currentUser = ref.read(authStateProvider).value?.user;
      final title = _details?['title'] as String? ?? _details?['name'] as String?;

      if (_loggedEntry == null) {
        final entry = await ref.read(entriesRepositoryProvider).getEntryForTmdbId(
          widget.tmdbId,
          title: title,
        );
        if (mounted && entry != null) {
          final effectiveEntry = (entry.suggestedByUser == null && widget.suggestedByUser != null)
              ? entry.copyWith(
                  suggestedByUser: widget.suggestedByUser,
                  suggestedByUserId: widget.suggestedByUserId ?? widget.suggestedByUser?.id,
                )
              : entry;
          setState(() {
            _loggedEntry = effectiveEntry;
            _authorUser = effectiveEntry.user ?? currentUser;
          });
        }
      } else if (currentUser != null && _loggedEntry!.userId != currentUser.id) {
        final myEntry = await ref.read(entriesRepositoryProvider).getEntryForTmdbId(
          widget.tmdbId,
          userId: currentUser.id,
          title: title,
        );
        if (mounted && myEntry != null) {
          setState(() {
            _myOwnEntry = myEntry;
          });
        }
      }
    } catch (_) {}
    _loadFriendsEntries();
  }

  bool get _isMyEntry {
    final currentUser = ref.watch(authStateProvider).value?.user;
    if (_loggedEntry == null || currentUser == null) return false;
    if (_loggedEntry!.userId == currentUser.id) return true;
    if (_authorUser != null && _authorUser!.id == currentUser.id) return true;
    return false;
  }

  Future<void> _checkWatchlistStatus() async {
    try {
      final data = await ref.read(watchlistRepositoryProvider).getWatchlist();
      final items = data['items'] as List<dynamic>? ?? [];
      final match = items.firstWhere(
        (it) => (it['tmdbId'] as num?)?.toInt() == widget.tmdbId || it['tmdbId'].toString() == widget.tmdbId.toString(),
        orElse: () => null,
      );
      if (mounted) {
        setState(() {
          _inWatchlist = match != null;
          if (match != null) {
            final userMap = match['suggestedByUser'] as Map<String, dynamic>?;
            final uid = match['suggestedByUserId'] as String? ?? userMap?['id'] as String?;
            final uname = userMap?['username'] as String? ?? match['suggestedByUsername'] as String?;
            if (_watchlistSuggestedByUser == null && userMap != null) {
              try {
                _watchlistSuggestedByUser = User.fromJson(userMap);
              } catch (_) {
                _watchlistSuggestedByUser = User(
                  id: uid ?? '',
                  username: uname ?? '',
                  displayName: userMap['displayName'] as String?,
                  profilePictureUrl: userMap['profilePictureUrl'] as String?,
                  createdAt: DateTime.now(),
                );
              }
            } else if (_watchlistSuggestedByUser == null && uname != null && uname.isNotEmpty) {
              _watchlistSuggestedByUser = User(
                id: uid ?? '',
                username: uname,
                createdAt: DateTime.now(),
              );
            }
            if (_watchlistSuggestedByUserId == null && uid != null && uid.isNotEmpty) {
              _watchlistSuggestedByUserId = uid;
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRecommendations() async {
    try {
      final recs = await ref.read(searchRepositoryProvider).getRecommendations(
        _effectiveIsTv ? 'tv' : 'movie',
        widget.tmdbId,
      );
      if (mounted) setState(() => _recommendations = recs);
    } catch (_) {}
  }

  Future<void> _loadDetails() async {
    try {
      final repo = ref.read(searchRepositoryProvider);
      Map<String, dynamic> details;
      bool isTv = _effectiveIsTv;

      try {
        details = isTv
            ? await repo.getTvDetails(widget.tmdbId)
            : await repo.getMovieDetails(widget.tmdbId);
      } catch (initialError) {
        // Fallback: If requested type fails (e.g. 404 TMDb ID mismatch), attempt alternate media type
        try {
          details = isTv
              ? await repo.getMovieDetails(widget.tmdbId)
              : await repo.getTvDetails(widget.tmdbId);
          isTv = !isTv;
        } catch (_) {
          throw initialError;
        }
      }

      if (mounted) {
        setState(() {
          _effectiveIsTv = isTv;
          _details = details;
          _isLoading = false;
        });

        // Initialize first TV season if TV show
        if (isTv) {
          _loadEpisodeProgress();
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
          _error = AppErrorHandler.toUserFriendlyMessage(e, defaultMessage: 'Could not load details right now. Please try again.');
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

  Future<void> _loadEpisodeProgress() async {
    try {
      final prog = await ref.read(episodeRepositoryProvider).getShowProgress(widget.tmdbId);
      final friends = await ref.read(episodeRepositoryProvider).getFriendsProgress(widget.tmdbId);
      if (mounted) {
        setState(() {
          _showProgress = prog;
          _friendsShowProgress = friends;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleEpisodeWatch(int seasonNum, int epNum, {int? epId, String? epName}) async {
    final key = '$seasonNum-$epNum';
    if (_togglingEpisodeKey != null) return;
    HapticFeedback.lightImpact();

    setState(() => _togglingEpisodeKey = key);

    final isCurrentlyWatched = _showProgress?.watchedEpisodes.any(
          (w) => w.seasonNumber == seasonNum && w.episodeNumber == epNum,
        ) ??
        false;

    // Detect if marking this episode watched completes the entire season or entire series
    bool willCompleteSeries = false;
    bool willCompleteSeason = false;

    if (!isCurrentlyWatched) {
      final totalShowEpisodes = (_details?['number_of_episodes'] as num?)?.toInt() ??
          _showProgress?.totalEpisodesCount ??
          0;
      final totalWatchedBefore = _showProgress?.watchedEpisodes
              .where((w) => !(w.seasonNumber == seasonNum && w.episodeNumber == epNum))
              .length ??
          0;
      willCompleteSeries = totalShowEpisodes > 0 && (totalWatchedBefore + 1) >= totalShowEpisodes;

      int seasonTotalEpisodes = 0;
      if (_seasonDetails != null && (_seasonDetails!['season_number'] as num?)?.toInt() == seasonNum) {
        seasonTotalEpisodes = (_seasonDetails!['episodes'] as List<dynamic>?)?.length ?? 0;
      }
      if (seasonTotalEpisodes == 0 && _details?['seasons'] is List) {
        final seasonsList = _details!['seasons'] as List<dynamic>;
        for (final s in seasonsList) {
          if (s is Map && (s['season_number'] as num?)?.toInt() == seasonNum) {
            seasonTotalEpisodes = (s['episode_count'] as num?)?.toInt() ?? 0;
            break;
          }
        }
      }
      final watchedInSeason = _showProgress?.watchedEpisodes
              .where((w) => w.seasonNumber == seasonNum && w.episodeNumber != epNum)
              .length ??
          0;
      willCompleteSeason = seasonTotalEpisodes > 0 && (watchedInSeason + 1) >= seasonTotalEpisodes;
    }

    try {
      final res = await ref.read(episodeRepositoryProvider).toggleEpisodeWatch(
            tmdbId: widget.tmdbId,
            seasonNumber: seasonNum,
            episodeNumber: epNum,
            episodeId: epId,
            episodeName: epName,
            isWatched: !isCurrentlyWatched,
          );
      if (mounted) {
        setState(() => _showProgress = res);
        _checkUserEntry();
        ref.read(entriesProvider(true).notifier).refresh();
        ref.read(entriesProvider(false).notifier).refresh();
        ref.read(continueWatchingProvider.notifier).refresh();

        if (willCompleteSeries || willCompleteSeason) {
          final showTitle = (_details?['name'] ?? _details?['title'] ?? res.title).toString();
          final showPoster = _details?['poster_path']?.toString() ?? res.posterPath;
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddEntrySheet(
              prefillTmdbId: widget.tmdbId,
              prefillType: 'TV_SHOW',
              prefillTitle: showTitle,
              prefillPosterPath: showPoster,
              prefillSeason: seasonNum,
              prefillIsWatching: false,
              onSuccess: () {
                _checkUserEntry();
                ref.read(entriesProvider(true).notifier).refresh();
                ref.read(entriesProvider(false).notifier).refresh();
                ref.read(continueWatchingProvider.notifier).refresh();
              },
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to update episode.');
      }
    } finally {
      if (mounted) setState(() => _togglingEpisodeKey = null);
    }
  }

  Future<void> _catchUpToEpisode(int seasonNum, int epNum) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Catch Up to S$seasonNum E$epNum?',
          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Mark all episodes from Season 1 Episode 1 up to Season $seasonNum Episode $epNum as watched?',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark Watched', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ref.read(episodeRepositoryProvider).batchCatchUp(
              tmdbId: widget.tmdbId,
              upToSeason: seasonNum,
              upToEpisode: epNum,
            );
        if (mounted) {
          setState(() => _showProgress = res);
          _checkUserEntry();
          ref.read(entriesProvider(true).notifier).refresh();
          ref.read(entriesProvider(false).notifier).refresh();
          ref.read(continueWatchingProvider.notifier).refresh();

          // Check if this catch-up completed the season or series
          final totalShowEpisodes = (_details?['number_of_episodes'] as num?)?.toInt() ??
              res.totalEpisodesCount ??
              0;
          final isSeriesDone = totalShowEpisodes > 0 && res.totalEpisodesWatched >= totalShowEpisodes;

          int seasonTotalEpisodes = 0;
          if (_seasonDetails != null && (_seasonDetails!['season_number'] as num?)?.toInt() == seasonNum) {
            seasonTotalEpisodes = (_seasonDetails!['episodes'] as List<dynamic>?)?.length ?? 0;
          }
          if (seasonTotalEpisodes == 0 && _details?['seasons'] is List) {
            final seasonsList = _details!['seasons'] as List<dynamic>;
            for (final s in seasonsList) {
              if (s is Map && (s['season_number'] as num?)?.toInt() == seasonNum) {
                seasonTotalEpisodes = (s['episode_count'] as num?)?.toInt() ?? 0;
                break;
              }
            }
          }
          final isSeasonDone = seasonTotalEpisodes > 0 && epNum >= seasonTotalEpisodes;

          if (isSeriesDone || isSeasonDone) {
            final showTitle = (_details?['name'] ?? _details?['title'] ?? res.title).toString();
            final showPoster = _details?['poster_path'] as String? ?? res.posterPath;

            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useRootNavigator: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AddEntrySheet(
                prefillTmdbId: widget.tmdbId,
                prefillType: 'TV_SHOW',
                prefillTitle: showTitle,
                prefillPosterPath: showPoster,
                prefillSeason: seasonNum,
                prefillIsWatching: false,
                onSuccess: () {
                  _checkUserEntry();
                  ref.read(entriesProvider(true).notifier).refresh();
                  ref.read(entriesProvider(false).notifier).refresh();
                  ref.read(continueWatchingProvider.notifier).refresh();
                },
              ),
            );
          }

          if (mounted) {
            WHAlert.showSuccess(context, 'Caught up to Season $seasonNum Episode $epNum! 🐝');
          }
        }
      } catch (_) {
        if (mounted) {
          WHAlert.showError(context, 'Failed to catch up episodes.');
        }
      }
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
        final added = await AddToWatchlistSheet.show(
          context,
          tmdbId: widget.tmdbId,
          title: title,
          mediaType: _effectiveIsTv ? 'tv' : 'movie',
          posterPath: _details?['poster_path'] as String?,
          overview: _details?['overview'] as String?,
          prefillSuggestedByUserId: _effectiveSuggestorId,
          prefillSuggestedByUser: _effectiveSuggestor,
        );
        if (added == true && mounted) {
          setState(() => _inWatchlist = true);
        }
      }
    } catch (e) {
      if (mounted) WHAlert.showError(context, AppErrorHandler.toUserFriendlyMessage(e, action: 'Watchlist update failed'));
    } finally {
      if (mounted) setState(() => _isWatchlistLoading = false);
    }
  }

  Future<void> _handleStartWatching() async {
    if (_isTransitioning || _details == null) return;

    final rawTitle = (_details?['title'] ?? _details?['name'])?.toString().trim();
    final title = (rawTitle != null && rawTitle.isNotEmpty && rawTitle != 'Untitled')
        ? rawTitle
        : (_effectiveIsTv ? 'this TV show' : 'this movie');
    final confirmed = await WHAlert.confirm(
      context,
      title: 'Log as Currently Watching',
      message: _inWatchlist
          ? 'Would you like to move "$title" to your active Watching log?'
          : 'Would you like to add "$title" to your active Watching log?',
      confirmText: _inWatchlist ? 'Move to Watching' : 'Start Watching',
      severity: WHAlertSeverity.primary,
      icon: Icons.visibility_rounded,
    );

    if (!confirmed) return;

    setState(() => _isTransitioning = true);
    try {
      final entry = await ref.read(entriesRepositoryProvider).createEntry({
        'tmdbId': widget.tmdbId,
        'title': title,
        'type': _effectiveIsTv ? 'TV_SHOW' : 'MOVIE',
        'isWatching': true,
        'startedAt': DateTime.now().toUtc().toIso8601String(),
        if (_effectiveSuggestorId != null && _effectiveSuggestorId!.isNotEmpty)
          'suggestedByUserId': _effectiveSuggestorId,
      });

      ref.read(entriesProvider(true).notifier).addEntry(entry);
      ref.read(entriesProvider(true).notifier).refresh();
      ref.read(entriesProvider(false).notifier).refresh();
      ref.read(continueWatchingProvider.notifier).refresh();
      ref.read(feedProvider.notifier).prependEntry(entry);

      // Remove from watchlist if it was in watchlist
      if (_inWatchlist) {
        try {
          await ref.read(watchlistRepositoryProvider).removeFromWatchlistByTmdbId(widget.tmdbId);
          setState(() => _inWatchlist = false);
        } catch (_) {}
      }

      final currentUser = ref.read(authStateProvider).value?.user;
      setState(() {
        _myOwnEntry = entry;
        if (_isMyEntry || _loggedEntry == null) {
          _loggedEntry = entry;
          _authorUser = entry.user ?? currentUser;
        }
      });

      if (mounted) {
        final posterPath = _details?['poster_path']?.toString();
        final backdropPath = _details?['backdrop_path']?.toString();
        final relDate = (_details?['release_date'] ?? _details?['first_air_date'])?.toString();
        final year = (relDate != null && relDate.length >= 4) ? relDate.substring(0, 4) : null;

        PostLogSuccessDialog.show(
          context,
          title: title,
          tmdbId: widget.tmdbId,
          mediaType: _effectiveIsTv ? 'tv' : 'movie',
          posterPath: posterPath,
          backdropPath: backdropPath,
          releaseYear: year,
          isWatching: true,
          isEditing: false,
          userDisplayName: currentUser?.displayName ?? currentUser?.username,
          username: currentUser?.username,
          userAvatarUrl: currentUser?.profilePictureUrl,
        );
      }
    } catch (e) {
      if (mounted) WHAlert.showError(context, AppErrorHandler.toUserFriendlyMessage(e, action: 'Failed to update watching status'));
    } finally {
      if (mounted) setState(() => _isTransitioning = false);
    }
  }

  void _logEntry({bool completeWatch = false}) {
    final details = _details;
    if (details == null) return;

    final entryToEdit = _isMyEntry ? _loggedEntry : _myOwnEntry;
    final title = (details['title'] ?? details['name'] ?? details['original_title'] ?? details['original_name'])?.toString().trim();
    final posterPath = details['poster_path'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEntrySheet(
        editEntry: entryToEdit,
        prefillTmdbId: widget.tmdbId,
        prefillType: _effectiveIsTv ? 'TV_SHOW' : 'MOVIE',
        prefillTitle: title,
        prefillPosterPath: posterPath,
        prefillSuggestor: _effectiveSuggestor,
        prefillSuggestedByUserId: _effectiveSuggestorId,
        prefillIsWatching: completeWatch ? false : null,
        onSuccess: () {
          _checkUserEntry();
          ref.read(entriesProvider(true).notifier).refresh();
          ref.read(entriesProvider(false).notifier).refresh();
          ref.read(continueWatchingProvider.notifier).refresh();
        },
      ),
    );
  }

  Future<void> _deleteEntry() async {
    final entry = _isMyEntry ? _loggedEntry : _myOwnEntry;
    if (entry == null) return;

    final title = (_details?['title'] ?? _details?['name'] ?? 'Movie/Show').toString();
    final confirm = await WHAlert.confirm(
      context,
      title: 'Delete Watch Entry?',
      message: 'Are you sure you want to delete your logged entry and review for "$title"? This action cannot be undone.',
      confirmText: 'Delete',
      severity: WHAlertSeverity.danger,
      icon: Icons.delete_outline_rounded,
    );

    if (!confirm) return;

    try {
      await ref.read(entriesRepositoryProvider).deleteEntry(entry.id);
      ref.read(entriesProvider(true).notifier).removeEntry(entry.id);
      ref.read(entriesProvider(false).notifier).removeEntry(entry.id);
      ref.read(entriesProvider(true).notifier).refresh();
      ref.read(entriesProvider(false).notifier).refresh();
      ref.read(continueWatchingProvider.notifier).refresh();
      ref.read(feedProvider.notifier).removeEntry(entry.id);
      if (mounted) {
        setState(() {
          if (_isMyEntry) {
            _loggedEntry = null;
          } else {
            _myOwnEntry = null;
          }
        });
        WHAlert.showSuccess(context, 'Deleted watch entry for "$title"');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, AppErrorHandler.toUserFriendlyMessage(e, action: 'Failed to delete entry'));
      }
    }
  }

  void _openSuggestModal() {
    final title = (_details?['title'] ?? _details?['name'] ?? 'Movie/Show').toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SuggestMovieModal(
        tmdbId: widget.tmdbId,
        title: title,
        mediaType: _effectiveIsTv ? 'tv' : 'movie',
      ),
    );
  }

  void _showMovieQrCode() {
    final currentUser = ref.read(authStateProvider).value?.user;
    final title = (_details?['title'] ?? _details?['name'] ?? 'Movie/Show').toString();
    final posterPath = _details?['poster_path']?.toString();
    final releaseDate = (_details?['release_date'] ?? _details?['first_air_date'])?.toString();
    final releaseYear = (releaseDate != null && releaseDate.length >= 4)
        ? releaseDate.substring(0, 4)
        : null;

    MovieQrDialog.show(
      context,
      tmdbId: widget.tmdbId,
      mediaType: _effectiveIsTv ? 'tv' : 'movie',
      title: title,
      posterPath: posterPath,
      releaseYear: releaseYear,
      suggestedByUser: currentUser,
    );
  }

  void _shareStory() {
    final currentUser = ref.read(authStateProvider).value?.user;
    final title = (_details?['title'] ?? _details?['name'] ?? 'Movie/Show').toString();
    final posterPath = _details?['poster_path']?.toString();
    final backdropPath = _details?['backdrop_path']?.toString();
    final releaseDate = (_details?['release_date'] ?? _details?['first_air_date'])?.toString();
    final releaseYear = (releaseDate != null && releaseDate.length >= 4)
        ? releaseDate.substring(0, 4)
        : null;
    final voteAverage = (_details?['vote_average'] as num?)?.toDouble();

    // Check if the current user has logged or is currently watching this title
    final activeEntry = _isMyEntry ? _loggedEntry : _myOwnEntry;

    final StoryShareMode shareMode;
    final double? rating;
    final String? review;

    if (activeEntry != null) {
      if (activeEntry.isWatching) {
        shareMode = StoryShareMode.watching;
        rating = null;
        review = null;
      } else {
        shareMode = StoryShareMode.logged;
        rating = activeEntry.rating;
        review = activeEntry.review;
      }
    } else {
      shareMode = StoryShareMode.general;
      rating = voteAverage;
      review = null;
    }

    ShareHelper.showStoryShareModal(
      context,
      title: title,
      posterPath: posterPath,
      backdropPath: backdropPath,
      rating: rating,
      review: review,
      tmdbId: widget.tmdbId,
      mediaType: _effectiveIsTv ? 'tv' : 'movie',
      releaseYear: releaseYear,
      userDisplayName: currentUser?.displayName ?? currentUser?.username,
      username: currentUser?.username,
      userAvatarUrl: currentUser?.profilePictureUrl,
      shareMode: shareMode,
    );
  }

  String _formatCategoryLabel() {
    if (_details == null) return _effectiveIsTv ? 'TV Series' : 'Feature Film';
    final genres = (_details!['genres'] as List<dynamic>? ?? [])
        .map((g) => (g['name'] as String? ?? '').toLowerCase())
        .toList();
    final isAnimation = genres.contains('animation');
    final isDoc = genres.contains('documentary');
    final lang = (_details!['original_language'] as String? ?? '').toLowerCase();
    final countries = (_details!['origin_country'] as List<dynamic>? ?? [])
        .map((c) => c.toString())
        .toList();

    if (isDoc) return 'Documentary';
    if (isAnimation && (lang == 'ja' || countries.contains('JP'))) return 'Anime';
    if (_effectiveIsTv && (lang == 'ko' || countries.contains('KR'))) return 'K-Drama';
    if (_effectiveIsTv && (lang == 'ja' || countries.contains('JP')) && !isAnimation) return 'J-Drama';
    if (_effectiveIsTv) {
      final seasons = (_details!['number_of_seasons'] as num?)?.toInt() ?? 1;
      if (seasons == 1) return 'Limited Series';
      return 'TV Series';
    }
    return 'Feature Film';
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
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    String webUrl;
    final List<String> candidateUris = [];

    if (name.contains('netflix')) {
      webUrl = 'https://www.netflix.com/search?q=$query';
      if (isAndroid) {
        candidateUris.add('intent:#Intent;action=android.intent.action.SEARCH;package=com.netflix.mediaclient;S.query=$title;S.browser_fallback_url=${Uri.encodeComponent(webUrl)};end');
      } else if (isIOS) {
        candidateUris.add('nflx://www.netflix.com/search?q=$query');
      }
    } else if (name.contains('amazon') || name.contains('prime')) {
      webUrl = 'https://www.primevideo.com/search/ref=atv_nb_sr?phrase=$query';
      if (isAndroid) {
        candidateUris.add('intent:#Intent;action=android.intent.action.SEARCH;package=com.amazon.avod.thirdpartyclient;S.query=$title;S.browser_fallback_url=${Uri.encodeComponent(webUrl)};end');
        candidateUris.add('https://www.primevideo.com/search/ref=atv_nb_sr?phrase=$query');
        candidateUris.add('https://www.amazon.com/s?k=$query&i=instant-video');
      } else if (isIOS) {
        candidateUris.add('primevideo://search?phrase=$query');
      }
    } else if (name.contains('hotstar') || name.contains('disney')) {
      webUrl = 'https://www.hotstar.com/in/explore?q=$query';
      if (isAndroid) {
        candidateUris.add('intent:#Intent;action=android.intent.action.SEARCH;package=in.startv.hotstar;S.query=$title;S.browser_fallback_url=${Uri.encodeComponent(webUrl)};end');
      } else if (isIOS) {
        candidateUris.add('hotstar://explore?q=$query');
      }
    } else if (name.contains('jiocinema')) {
      webUrl = 'https://www.jiocinema.com/search/$query';
      if (isAndroid) {
        candidateUris.add('intent:#Intent;action=android.intent.action.VIEW;package=com.jio.media.ondemand;S.browser_fallback_url=${Uri.encodeComponent(webUrl)};end');
      }
    } else if (name.contains('zee5')) {
      webUrl = 'https://www.zee5.com/search?q=$query';
      if (isAndroid) {
        candidateUris.add('intent:#Intent;action=android.intent.action.SEARCH;package=com.graymatrix.did;S.query=$title;S.browser_fallback_url=${Uri.encodeComponent(webUrl)};end');
      }
    } else if (name.contains('sonyliv')) {
      webUrl = 'https://www.sonyliv.com/search?query=$query';
      if (isAndroid) {
        candidateUris.add('intent:#Intent;action=android.intent.action.SEARCH;package=com.sonyliv;S.query=$title;S.browser_fallback_url=${Uri.encodeComponent(webUrl)};end');
      }
    } else if (name.contains('apple')) {
      webUrl = 'https://tv.apple.com/search?q=$query';
      if (isIOS) {
        candidateUris.add('appletv://search?q=$query');
      }
    } else if (name.contains('youtube')) {
      webUrl = 'https://www.youtube.com/results?search_query=$query';
      candidateUris.add('vnd.youtube://results?search_query=$query');
    } else if (name.contains('google play') || name.contains('google tv')) {
      webUrl = 'https://play.google.com/store/search?q=$query&c=movies';
      if (isAndroid) {
        candidateUris.add('market://search?q=$query&c=movies');
      }
    } else if (name.contains('hulu')) {
      webUrl = 'https://www.hulu.com/search?q=$query';
    } else if (name.contains('max') || name.contains('hbo')) {
      webUrl = 'https://play.max.com/search?q=$query';
    } else if (name.contains('paramount')) {
      webUrl = 'https://www.paramountplus.com/search/?q=$query';
    } else if (name.contains('peacock')) {
      webUrl = 'https://www.peacocktv.com/watch/search?q=$query';
    } else if (name.contains('aha')) {
      webUrl = 'https://www.aha.video/search?q=$query';
    } else if (name.contains('mx player')) {
      webUrl = 'https://www.mxplayer.in/search?q=$query';
    } else if (name.contains('mubi')) {
      webUrl = 'https://mubi.com/search/films?query=$query';
    } else {
      webUrl = (fallbackLink != null && fallbackLink.isNotEmpty)
          ? fallbackLink
          : 'https://www.google.com/search?q=$query+watch+online';
    }

    bool launched = false;
    for (final candidate in candidateUris) {
      try {
        final uri = Uri.parse(candidate);
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) break;
        }
      } catch (_) {
        // Try next candidate or web fallback
      }
    }

    if (!launched) {
      try {
        await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) WHAlert.showError(context, 'Could not open streaming link');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const WHSkeletonMovieDetails();
    }

    if (_error != null || _details == null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          context.safePop();
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
              onPressed: () => context.safePop(),
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
                  _error ?? 'Unable to load cinematic details right now. Please try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.safePop();
      },
      child: Scaffold(
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
                    backgroundColor: Colors.black.withValues(alpha: 0.55),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      onPressed: () => context.safePop(),
                    ),
                  ),
                ),
              ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black.withValues(alpha: 0.55),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.share_outlined, color: Colors.white, size: 19),
                      tooltip: 'Share Story',
                      onPressed: _shareStory,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black.withValues(alpha: 0.55),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 20),
                      tooltip: 'Hive Code (QR)',
                      onPressed: _showMovieQrCode,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black.withValues(alpha: 0.55),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.help_outline_rounded, color: Colors.white, size: 20),
                      tooltip: 'About Title Details',
                      onPressed: () => ScreenGuideDialog.show(context, ScreenGuideType.movieDetails),
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
                            color: AppColors.primary.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
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
                              color: Colors.white.withValues(alpha: 0.85),
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
                  // Recommender Banner (e.g. from QR scan or watchlist attribution)
                  if (_effectiveSuggestor != null && !_isMyEntry) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          WHAvatar(
                            imageUrl: _effectiveSuggestor!.profilePictureUrl,
                            name: _effectiveSuggestor!.displayName ?? _effectiveSuggestor!.username,
                            radius: 14,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Recommended by ',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        '@${_effectiveSuggestor!.username}',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF2D2926),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                const Text(
                                  'Adding to watchlist or logging will credit this recommender',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'HIVE QR',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2D2926),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Action Bar (Web Parity)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 1. Primary Media Actions (Watchlist & Log Watch)
                        Row(
                          children: [
                            // Watchlist Toggle
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _inWatchlist ? AppColors.primary : AppColors.surfaceElevated,
                                  foregroundColor: _inWatchlist ? Colors.black : AppColors.textPrimary,
                                  elevation: 0,
                                  side: BorderSide(
                                    color: _inWatchlist ? AppColors.primary : AppColors.primary.withValues(alpha: 0.25),
                                    width: 1.2,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _toggleWatchlist();
                                },
                                icon: _isWatchlistLoading
                                    ? const WHBeeSpinner(size: 16)
                                    : Icon(
                                        _inWatchlist ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                                        size: 19,
                                        color: _inWatchlist ? Colors.black : const Color(0xFF2D2926),
                                      ),
                                label: Text(
                                  _inWatchlist ? 'In Watchlist' : 'Add to Watchlist',
                                  style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Log Watch, Edit Log, or Complete Watch
                            Builder(
                              builder: (context) {
                                final activeSelfEntry = _isMyEntry ? _loggedEntry : _myOwnEntry;
                                final isCurrentlyWatching = activeSelfEntry != null && activeSelfEntry.isWatching;
                                final isCompletedLog = activeSelfEntry != null && !activeSelfEntry.isWatching;
                                final selfRating = activeSelfEntry?.rating;

                                return Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isCurrentlyWatching
                                          ? AppColors.primary
                                          : (isCompletedLog
                                              ? AppColors.surfaceElevated
                                              : AppColors.textPrimary),
                                      foregroundColor: isCurrentlyWatching
                                          ? const Color(0xFF2D2926)
                                          : (isCompletedLog
                                              ? const Color(0xFF2D2926)
                                              : Colors.white),
                                      side: isCompletedLog
                                          ? BorderSide(color: const Color(0xFF2D2926).withValues(alpha: 0.25), width: 1.2)
                                          : null,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      if (isCurrentlyWatching) {
                                        _logEntry(completeWatch: true);
                                      } else {
                                        _logEntry();
                                      }
                                    },
                                    icon: Icon(
                                      isCurrentlyWatching
                                          ? Icons.task_alt_rounded
                                          : (isCompletedLog ? Icons.check_circle_rounded : Icons.edit_note_rounded),
                                      size: 20,
                                      color: isCurrentlyWatching
                                          ? const Color(0xFF2D2926)
                                          : (isCompletedLog ? const Color(0xFF2D2926) : AppColors.primary),
                                    ),
                                    label: Text(
                                      isCurrentlyWatching
                                          ? 'Complete Watch'
                                          : (isCompletedLog
                                              ? (selfRating != null && selfRating > 0
                                                  ? 'Logged (⭐ ${selfRating.toStringAsFixed(1)})'
                                                  : 'Logged ✓')
                                              : 'Log Watch'),
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: (isCurrentlyWatching || isCompletedLog)
                                            ? const Color(0xFF2D2926)
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        // 2. Currently Watching Action Card (visible for active watching or uncompleted titles)
                        Builder(
                          builder: (context) {
                            final activeSelfEntry = _isMyEntry ? _loggedEntry : _myOwnEntry;
                            final isCurrentlyWatching = activeSelfEntry != null && activeSelfEntry.isWatching;
                            final isCompletedLog = activeSelfEntry != null && !activeSelfEntry.isWatching;

                            // Once user has logged completed watch with rating/review, collapse this card
                            if (isCompletedLog) {
                              return const SizedBox.shrink();
                            }

                            return AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isTransitioning
                                        ? null
                                        : () {
                                            HapticFeedback.lightImpact();
                                            if (isCurrentlyWatching) {
                                              _logEntry(completeWatch: true);
                                            } else {
                                              _handleStartWatching();
                                            }
                                          },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isCurrentlyWatching
                                              ? AppColors.primary
                                              : AppColors.primary.withValues(alpha: 0.35),
                                          width: isCurrentlyWatching ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: isCurrentlyWatching
                                                  ? AppColors.primary
                                                  : AppColors.primary.withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: _isTransitioning
                                                ? const Center(
                                                    child: WHBeeSpinner(size: 14),
                                                  )
                                                : Icon(
                                                    isCurrentlyWatching
                                                        ? Icons.visibility_rounded
                                                        : Icons.play_arrow_rounded,
                                                    size: 20,
                                                    color: const Color(0xFF2D2926),
                                                  ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  isCurrentlyWatching
                                                      ? 'Currently Watching'
                                                      : (_inWatchlist
                                                          ? 'Started watching this?'
                                                          : 'Currently watching this?'),
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  isCurrentlyWatching
                                                      ? 'In your active Watching log'
                                                      : (_inWatchlist
                                                          ? 'Move from Watchlist to Watching log'
                                                          : 'Add to active Watching log'),
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 11,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius: BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.primary.withValues(alpha: 0.25),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  isCurrentlyWatching
                                                      ? 'Complete'
                                                      : 'Watching',
                                                  style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                Icon(
                                                  isCurrentlyWatching
                                                      ? Icons.task_alt_rounded
                                                      : Icons.arrow_forward_rounded,
                                                  size: 12,
                                                  color: Colors.black,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 10),

                        // 3. Community & Curation Utility Actions (Suggest & Rank in Stack)
                        Row(
                          children: [
                            // Suggest to Friends
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: const BorderSide(color: AppColors.border),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _openSuggestModal();
                                },
                                icon: const Icon(Icons.send_rounded, size: 15, color: Color(0xFF2D2926)),
                                label: const Text(
                                  'Suggest',
                                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Rank in Stack
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: const BorderSide(color: AppColors.border),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  AddToStackSheet.show(
                                    context,
                                    tmdbId: widget.tmdbId,
                                    title: title,
                                    posterPath: posterPath,
                                    mediaType: _effectiveIsTv ? 'tv' : 'movie',
                                  );
                                },
                                icon: const Icon(Icons.format_list_numbered_rounded, size: 16, color: Color(0xFF2D2926)),
                                label: const Text(
                                  'Rank',
                                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Friends Who Watched Bar (Social Proof: Max 3 avatars + '+N' badge & sheet modal)
                  if (_friendsEntries.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    FriendsWatchedBar(
                      friendsEntries: _friendsEntries,
                      movieTitle: title,
                      onTap: () {
                        final activeSelfEntry = _isMyEntry ? _loggedEntry : _myOwnEntry;
                        FriendsWhoWatchedSheet.show(
                          context,
                          movieTitle: title,
                          friendsEntries: _friendsEntries,
                          myEntry: activeSelfEntry,
                        );
                      },
                    ),
                  ],

                  // Personal Logged Watch Entry & Review Details (Only for current user's entry)
                  Builder(
                    builder: (context) {
                      final activeSelfEntry = _isMyEntry ? _loggedEntry : _myOwnEntry;
                      final currentUser = ref.watch(authStateProvider).value?.user;
                      if (activeSelfEntry == null) return const SizedBox.shrink();
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 20),
                          _buildLoggedReviewCard(
                            context: context,
                            entry: activeSelfEntry,
                            author: _isMyEntry ? _authorUser : currentUser,
                            isMe: true,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Accolades & Awards Section (if present)
                  if (awards != null && awards.isNotEmpty || criticRatings.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary.withValues(alpha: 0.12), AppColors.surface],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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
                                      color: Colors.green.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
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
                    Builder(
                      builder: (context) {
                        final currentUser = ref.watch(authStateProvider).value?.user;
                        final userPlatforms = currentUser?.savedStreamingPlatforms ?? const <String>[];
                        final matchingSubscribed = streamProviders.where((p) {
                          final name = (p['provider_name'] as String? ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                          return userPlatforms.any((up) {
                            final cleanUp = up.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                            return name.contains(cleanUp) || cleanUp.contains(name);
                          });
                        }).toList();

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Where to Watch',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (matchingSubscribed.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle_rounded, size: 12, color: AppColors.primary),
                                          SizedBox(width: 4),
                                          Text(
                                            'In Subscriptions',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              if (matchingSubscribed.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Included in your active subscriptions: ${matchingSubscribed.map((p) => p['provider_name']).join(', ')}',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              if (streamProviders.isNotEmpty) ...[
                                _ProviderRow(
                                  typeLabel: 'Stream:',
                                  providers: streamProviders,
                                  userPlatforms: userPlatforms,
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
                                  userPlatforms: userPlatforms,
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
                                  userPlatforms: userPlatforms,
                                  fallbackLink: localProviders?['link'] as String?,
                                  title: title,
                                  onTapProvider: _launchProviderUrl,
                                ),
                            ],
                          ),
                        );
                      },
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
                  if (_effectiveIsTv && seasons.isNotEmpty) ...[
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
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: WHSkeletonEpisodeList(count: 3),
                            )
                          else if (_seasonDetails?['episodes'] != null && (_seasonDetails!['episodes'] as List).isNotEmpty) ...[
                            // Season Progress Bar
                            Builder(
                              builder: (context) {
                                final epList = _seasonDetails!['episodes'] as List;
                                final totalInSeason = epList.length;
                                final watchedInSeason = epList.where((e) {
                                  final epNum = (e as Map<String, dynamic>)['episode_number'] as int? ?? 0;
                                  return _showProgress?.watchedEpisodes.any(
                                        (w) => w.seasonNumber == _selectedSeasonNumber && w.episodeNumber == epNum,
                                      ) ??
                                      false;
                                }).length;
                                final seasonPct = totalInSeason > 0 ? ((watchedInSeason / totalInSeason) * 100).round() : 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Season ${_selectedSeasonNumber ?? 1} Progress',
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            '$watchedInSeason / $totalInSeason eps ($seasonPct%)',
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: totalInSeason > 0 ? (watchedInSeason / totalInSeason).clamp(0.0, 1.0) : 0,
                                          backgroundColor: AppColors.border,
                                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                          minHeight: 5,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

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

                                final isWatched = _showProgress?.watchedEpisodes.any(
                                      (w) => w.seasonNumber == _selectedSeasonNumber && w.episodeNumber == epNum,
                                    ) ??
                                    false;
                                final isToggling = _togglingEpisodeKey == '$_selectedSeasonNumber-$epNum';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isWatched
                                        ? AppColors.primary.withValues(alpha: 0.08)
                                        : AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isWatched
                                          ? AppColors.primary.withValues(alpha: 0.35)
                                          : AppColors.border,
                                    ),
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
                                                    color: isWatched
                                                        ? AppColors.primary
                                                        : AppColors.primary.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'EP $epNum',
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                      color: isWatched ? Colors.black : AppColors.primary,
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
                                      const SizedBox(width: 8),

                                      // Episode Watch Actions
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GestureDetector(
                                            onTap: isToggling
                                                ? null
                                                : () => _toggleEpisodeWatch(
                                                      _selectedSeasonNumber ?? 1,
                                                      epNum,
                                                      epId: ep['id'] as int?,
                                                      epName: epName,
                                                    ),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isWatched ? AppColors.primary : AppColors.surface,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isWatched ? AppColors.primary : AppColors.border,
                                                ),
                                              ),
                                              child: isToggling
                                                  ? const WHBeeSpinner(size: 11)
                                                  : Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          isWatched ? Icons.check_rounded : Icons.add_rounded,
                                                          size: 13,
                                                          color: isWatched ? Colors.black : AppColors.textPrimary,
                                                        ),
                                                        const SizedBox(width: 2),
                                                        Text(
                                                          isWatched ? 'Watched' : 'Mark',
                                                          style: TextStyle(
                                                            fontFamily: 'Inter',
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w800,
                                                            color: isWatched ? Colors.black : AppColors.textPrimary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                          if (!isWatched) ...[
                                            const SizedBox(height: 4),
                                            GestureDetector(
                                              onTap: () => _catchUpToEpisode(_selectedSeasonNumber ?? 1, epNum),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surface,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: AppColors.border),
                                                ),
                                                child: const Icon(
                                                  Icons.fast_forward_rounded,
                                                  size: 12,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            // Friends Watching TV Progress
                            if (_friendsShowProgress.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Divider(height: 1, color: AppColors.border),
                              const SizedBox(height: 12),
                              const Text(
                                '🐝 Friends Watching This Show',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _friendsShowProgress.map((fp) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        WHAvatar(
                                          imageUrl: fp.user.profilePictureUrl,
                                          name: fp.user.name,
                                          radius: 10,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          fp.user.name,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (fp.currentSeason != null) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'S${fp.currentSeason} E${fp.currentEpisode}',
                                              style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ]
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
    ),
  );
}

  Widget _buildLoggedReviewCard({
    required BuildContext context,
    required Entry entry,
    required User? author,
    required bool isMe,
  }) {
    final rating = entry.rating;
    final moodInfo = rating != null && rating > 0 ? WHRatingPicker.getMoodInfo(rating) : null;
    final watchedDate = entry.watchedAt;
    final formattedDate = entry.isWatching
        ? 'Currently Watching since ${DateFormat('MMM d, yyyy').format(entry.startedAt ?? entry.createdAt)}'
        : 'Watched on ${DateFormat('MMM d, yyyy').format(watchedDate)}';
    final hasReview = entry.review != null && entry.review!.trim().isNotEmpty;
    final authorName = author?.displayName ?? author?.username ?? (isMe ? 'You' : 'User');
    final authorUsername = author?.username ?? (isMe ? 'you' : 'user');
    final authorAvatar = author?.profilePictureUrl;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMe ? AppColors.primary.withValues(alpha: 0.45) : AppColors.border,
          width: isMe ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Accent Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isMe
                    ? [
                        AppColors.primary.withValues(alpha: 0.25),
                        AppColors.primary.withValues(alpha: 0.05),
                      ]
                    : [
                        AppColors.surfaceElevated,
                        AppColors.surface,
                      ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border(
                bottom: BorderSide(
                  color: isMe
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.border,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  entry.isWatching
                      ? Icons.visibility_rounded
                      : (isMe ? Icons.rate_review_rounded : Icons.person_pin_rounded),
                  size: 16,
                  color: entry.isWatching
                      ? const Color(0xFF2D2926)
                      : (isMe ? const Color(0xFF2D2926) : AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.isWatching
                      ? (isMe ? 'Currently Watching' : "$authorName is Currently Watching")
                      : (isMe ? 'Your Watch Entry & Review' : "$authorName's Watch Entry"),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Color(0xFF2D2926),
                  ),
                ),
                const Spacer(),
                if (isMe)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (entry.isWatching) ...[
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _logEntry(completeWatch: true);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.task_alt_rounded, size: 13, color: Color(0xFF2D2926)),
                                SizedBox(width: 4),
                                Text('Complete', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2D2926))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _logEntry();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_outlined, size: 13, color: AppColors.textSecondary),
                              SizedBox(width: 4),
                              Text('Edit', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _deleteEntry();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.error),
                        ),
                      ),
                    ],
                  )
                else if (author != null && author.id.isNotEmpty)
                  GestureDetector(
                    onTap: () => context.push('/profile/${author.id}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('View Profile', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          SizedBox(width: 3),
                          Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author Profile & Date Row
                Row(
                  children: [
                    GestureDetector(
                      onTap: (!isMe && author != null && author.id.isNotEmpty)
                          ? () => context.push('/profile/${author.id}')
                          : null,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.surfaceElevated,
                        backgroundImage: (authorAvatar != null && authorAvatar.isNotEmpty)
                            ? CachedNetworkImageProvider(authorAvatar.startsWith('http')
                                ? authorAvatar
                                : '${ApiEndpoints.baseUrl}$authorAvatar')
                            : null,
                        child: (authorAvatar == null || authorAvatar.isEmpty)
                            ? Text(
                                authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  authorName,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!isMe && authorUsername.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '@$authorUsername',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textMuted),
                              const SizedBox(width: 5),
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Rating & Sentiment Highlights
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      // Score
                      if (rating != null && rating > 0) ...[
                        Text(
                          '⭐ ${rating.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          ' / 10',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(height: 18, width: 1, color: AppColors.border),
                        const SizedBox(width: 10),
                      ] else if (entry.isWatching) ...[
                        const Icon(Icons.visibility_rounded, size: 18, color: Color(0xFF2D2926)),
                        const SizedBox(width: 6),
                        const Text(
                          'Currently Watching',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(height: 18, width: 1, color: AppColors.border),
                        const SizedBox(width: 10),
                      ] else ...[
                        const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.success),
                        const SizedBox(width: 6),
                        const Text(
                          'Watched',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(height: 18, width: 1, color: AppColors.border),
                        const SizedBox(width: 10),
                      ],

                      // Mood / Sentiment Badge
                      if (moodInfo != null)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: moodInfo.bgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: moodInfo.borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(moodInfo.icon, size: 13, color: moodInfo.color),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    moodInfo.text,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: moodInfo.color,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (entry.isRewatch) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.repeat_rounded, size: 12, color: Color(0xFF2D2926)),
                              SizedBox(width: 4),
                              Text('Rewatch', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2D2926))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Review Text Box
                if (hasReview) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.format_quote_rounded, size: 18, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'Review & Thoughts',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.review!.trim(),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isMe) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _logEntry();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(Icons.add_comment_outlined, size: 14, color: Color(0xFF2D2926)),
                          SizedBox(width: 6),
                          Text(
                            'Add a written review to this entry...',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D2926),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Metadata Chips (Location, Tags, Suggested By)
                if ((entry.watchLocation != null && entry.watchLocation!.isNotEmpty) ||
                    entry.tags.isNotEmpty ||
                    entry.suggestedByUser != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (entry.watchLocation != null && entry.watchLocation!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PlatformBrandLogo(
                                platform: entry.watchLocation!,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                entry.watchLocation!,
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ...entry.tags.map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '#$tag',
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2D2926)),
                          ),
                        ),
                      ),
                      if (entry.suggestedByUser != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFF2D2926)),
                              const SizedBox(width: 5),
                              Text(
                                'Suggested by @${entry.suggestedByUser!.username}',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2D2926)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],

                // Comparison Banner (If viewing a friend's review and you also logged it)
                if (!isMe && _myOwnEntry != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _myOwnEntry!.isWatching ? Icons.visibility_rounded : Icons.check_circle_rounded,
                          size: 16,
                          color: const Color(0xFF2D2926),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _myOwnEntry!.isWatching
                              ? 'You are currently watching this'
                              : 'You also watched this: ⭐ ${_myOwnEntry!.rating != null ? _myOwnEntry!.rating!.toStringAsFixed(1) : 'Watched'}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (_myOwnEntry!.isWatching) {
                              _logEntry(completeWatch: true);
                            } else {
                              _logEntry();
                            }
                          },
                          child: Text(
                            _myOwnEntry!.isWatching ? 'Complete Watch' : 'Edit Yours',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2D2926),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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
  final List<String> userPlatforms;
  final String? fallbackLink;
  final String title;
  final Function(String, String?, String) onTapProvider;

  const _ProviderRow({
    required this.typeLabel,
    required this.providers,
    this.userPlatforms = const [],
    required this.fallbackLink,
    required this.title,
    required this.onTapProvider,
  });

  bool _isSubscribed(String providerName) {
    if (userPlatforms.isEmpty) return false;
    final cleanP = providerName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final up in userPlatforms) {
      final cleanU = up.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (cleanP.contains(cleanU) || cleanU.contains(cleanP)) return true;
    }
    return false;
  }

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
                final isSub = _isSubscribed(name);

                return GestureDetector(
                  onTap: () => onTapProvider(name, fallbackLink, title),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Tooltip(
                      message: isSub ? '$name (In Your Subscriptions)' : name,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          border: isSub
                              ? Border.all(color: AppColors.primary, width: 2)
                              : null,
                          boxShadow: isSub
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(isSub ? 9 : 10),
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

