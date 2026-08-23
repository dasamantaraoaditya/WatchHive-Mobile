import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/user.dart';
import '../../../shared/models/suggestion.dart';
import '../repositories/entries_repository.dart';
import '../repositories/suggestions_repository.dart';
import 'entries_screen.dart';
import '../../search/repositories/search_repository.dart';

class _LocationPreset {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _LocationPreset({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

const _locationPresets = [
  _LocationPreset(label: 'Cinema', value: 'Cinema', icon: Icons.theaters_rounded, color: Color(0xFFE53935)),
  _LocationPreset(label: 'Home', value: 'Home', icon: Icons.chair_rounded, color: Color(0xFFF39C12)),
  _LocationPreset(label: 'Netflix', value: 'Netflix', icon: Icons.play_circle_fill_rounded, color: Color(0xFFE50914)),
  _LocationPreset(label: 'Disney+', value: 'Disney+', icon: Icons.auto_awesome_rounded, color: Color(0xFF3B82F6)),
  _LocationPreset(label: 'Prime', value: 'Prime Video', icon: Icons.ondemand_video_rounded, color: Color(0xFF00A8E8)),
  _LocationPreset(label: 'Mobile', value: 'On the Go', icon: Icons.smartphone_rounded, color: Color(0xFF00D2D3)),
];

class AddEntrySheet extends ConsumerStatefulWidget {
  final Entry? editEntry;
  final int? prefillTmdbId;
  final String? prefillType;
  final User? prefillSuggestor;
  final String? prefillSuggestedByUserId;
  final VoidCallback? onSuccess;

  const AddEntrySheet({
    super.key,
    this.editEntry,
    this.prefillTmdbId,
    this.prefillType,
    this.prefillSuggestor,
    this.prefillSuggestedByUserId,
    this.onSuccess,
  });

  @override
  ConsumerState<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<AddEntrySheet> {
  final _titleController = TextEditingController();
  final _reviewController = TextEditingController();
  final _searchController = TextEditingController();
  final _suggestedByController = TextEditingController();
  final _locationController = TextEditingController();
  final _tagController = TextEditingController();
  final _ratingInputController = TextEditingController();

  int _tmdbId = 0;
  String _type = 'MOVIE';
  double _rating = 0;
  bool _isRewatch = false;
  bool _isWatching = false;
  bool _isLoading = false;
  String _watchLocation = '';
  List<String> _tags = [];
  bool _showRatingGuide = false;

  List<MediaResult> _searchResults = [];
  bool _isSearching = false;
  MediaResult? _selectedMedia;
  Map<String, dynamic>? _mediaDetails;

  // ── Friend Suggestion State ──
  String? _suggestedByUserId;
  String? _suggestorUsername;
  String? _suggestorDisplayName;
  String? _suggestorAvatar;
  List<User> _friendResults = [];
  bool _isSearchingFriends = false;
  bool _showFriendPicker = false;

  bool get isEditing => widget.editEntry != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final e = widget.editEntry!;
      _tmdbId = e.tmdbId;
      _titleController.text = e.title;
      _reviewController.text = e.review ?? '';
      _suggestedByUserId = e.suggestedByUserId ?? e.suggestedByUser?.id;
      _suggestorUsername = e.suggestedByUser?.username;
      _suggestorDisplayName = e.suggestedByUser?.displayName;
      _suggestorAvatar = e.suggestedByUser?.profilePictureUrl;
      _type = e.type;
      _rating = e.rating ?? 0;
      if (_rating > 0) {
        _ratingInputController.text = _rating.toStringAsFixed(1);
      }
      _isRewatch = e.isRewatch;
      _isWatching = e.isWatching;
      _watchLocation = e.watchLocation ?? '';
      _locationController.text = _watchLocation;
      _tags = List<String>.from(e.tags);
      if (_tmdbId > 0) _loadMediaDetails(_tmdbId, _type);
    } else {
      if (widget.prefillTmdbId != null) {
        _tmdbId = widget.prefillTmdbId!;
      }
      if (widget.prefillType != null) {
        _type = widget.prefillType == 'tv' ? 'TV_SHOW' : widget.prefillType!;
      }
      if (widget.prefillSuggestor != null) {
        _suggestedByUserId = widget.prefillSuggestor!.id;
        _suggestorUsername = widget.prefillSuggestor!.username;
        _suggestorDisplayName = widget.prefillSuggestor!.displayName;
        _suggestorAvatar = widget.prefillSuggestor!.profilePictureUrl;
      } else if (widget.prefillSuggestedByUserId != null) {
        _suggestedByUserId = widget.prefillSuggestedByUserId;
      }

      if (_tmdbId > 0) {
        _loadMediaDetails(_tmdbId, _type);
        if (_suggestedByUserId == null) {
          _checkSuggestionsForTmdbId(_tmdbId);
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _reviewController.dispose();
    _searchController.dispose();
    _suggestedByController.dispose();
    _locationController.dispose();
    _tagController.dispose();
    _ratingInputController.dispose();
    super.dispose();
  }

  Future<void> _loadMediaDetails(int tmdbId, String type) async {
    try {
      final mediaType = (type == 'TV_SHOW' || type == 'tv') ? 'tv' : 'movie';
      final details = mediaType == 'tv'
          ? await ref.read(searchRepositoryProvider).getTvDetails(tmdbId)
          : await ref.read(searchRepositoryProvider).getMovieDetails(tmdbId);
      if (mounted) {
        setState(() {
          _mediaDetails = details;
          if (_titleController.text.isEmpty) {
            _titleController.text = (details['title'] as String?) ?? (details['name'] as String?) ?? '';
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _checkSuggestionsForTmdbId(int tmdbId) async {
    try {
      final groups = await ref.read(suggestionsRepositoryProvider).getMySuggestions();
      final matches = groups.where((g) => g.tmdbId == tmdbId).toList();
      if (matches.isNotEmpty && matches.first.suggestors.isNotEmpty && mounted) {
        final s = matches.first.suggestors.first;
        setState(() {
          _suggestedByUserId = s.id;
          _suggestorUsername = s.username;
          _suggestorDisplayName = s.displayName;
          _suggestorAvatar = s.profilePictureUrl;
        });
      }
    } catch (_) {}
  }

  Future<void> _searchMedia(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await ref.read(searchRepositoryProvider).searchMedia(query);
      setState(() => _searchResults = results.take(5).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _searchFriends(String query) async {
    setState(() {
      _isSearchingFriends = true;
      _showFriendPicker = true;
    });
    try {
      final results = await ref.read(searchRepositoryProvider).searchUsers(query.isNotEmpty ? query : 'a');
      if (mounted) {
        setState(() {
          _friendResults = results;
          _isSearchingFriends = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingFriends = false);
    }
  }

  void _addTag() {
    final t = _tagController.text.trim();
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() {
        _tags.add(t);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  ({IconData icon, Color color, String text}) _getRatingMoodInfo(double rating) {
    if (rating == 0) {
      return (
        icon: Icons.rate_review_rounded,
        color: AppColors.textMuted,
        text: 'Select a rating to record your thoughts',
      );
    }
    if (rating <= 2.0) {
      return (
        icon: Icons.sentiment_very_dissatisfied_rounded,
        color: Colors.redAccent,
        text: 'Disaster / Complete Waste of Time 🗑️',
      );
    }
    if (rating <= 4.0) {
      return (
        icon: Icons.sentiment_dissatisfied_rounded,
        color: Colors.orangeAccent,
        text: 'Poor / Not Recommended 👎',
      );
    }
    if (rating <= 5.5) {
      return (
        icon: Icons.sentiment_neutral_rounded,
        color: Colors.amber,
        text: 'Mediocre / Average 🍿',
      );
    }
    if (rating <= 7.0) {
      return (
        icon: Icons.sentiment_satisfied_rounded,
        color: Colors.lightGreenAccent,
        text: 'Decent / Enjoyable 👍',
      );
    }
    if (rating <= 8.5) {
      return (
        icon: Icons.sentiment_very_satisfied_rounded,
        color: Colors.greenAccent,
        text: 'Excellent / Highly Recommended 🔥',
      );
    }
    if (rating <= 9.5) {
      return (
        icon: Icons.grade_rounded,
        color: AppColors.primary,
        text: 'Outstanding / Near Flawless 🌟',
      );
    }
    return (
      icon: Icons.emoji_events_rounded,
      color: Colors.amberAccent,
      text: 'Absolute Masterpiece / Cinematic Perfection 🏆',
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or select a title'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        'tmdbId': _tmdbId > 0 ? _tmdbId : (_selectedMedia?.id ?? 0),
        'title': title,
        'type': _type,
        'rating': _rating > 0 ? _rating : null,
        'review': _reviewController.text.trim().isNotEmpty ? _reviewController.text.trim() : null,
        'isRewatch': _isRewatch,
        'isWatching': _isWatching,
        'watchLocation': _watchLocation.isNotEmpty ? _watchLocation : null,
        'tags': _tags,
        'watchedAt': DateTime.now().toIso8601String(),
        if (_suggestedByUserId != null && _suggestedByUserId!.isNotEmpty)
          'suggestedByUserId': _suggestedByUserId,
      };

      if (isEditing) {
        final updated = await ref.read(entriesRepositoryProvider).updateEntry(widget.editEntry!.id, data);
        ref.read(entriesProvider.notifier).updateEntry(updated);
      } else {
        final entry = await ref.read(entriesRepositoryProvider).createEntry(data);
        ref.read(entriesProvider.notifier).addEntry(entry);
      }

      if (mounted) {
        widget.onSuccess?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final posterPath = _mediaDetails?['poster_path'] as String? ?? _selectedMedia?.posterPath;
    final posterUrl = ApiEndpoints.tmdbPoster(posterPath);
    final overview = _mediaDetails?['overview'] as String?;
    final releaseDate = _mediaDetails?['release_date'] as String? ?? _mediaDetails?['first_air_date'] as String? ?? _selectedMedia?.year;
    final year = releaseDate != null && releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
    final tmdbVote = (_mediaDetails?['vote_average'] as num?)?.toDouble();

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(isEditing ? Icons.edit_note_rounded : Icons.movie_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  isEditing ? 'Edit Your Entry' : 'Log a Watch',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // ── Selected / Editing Movie Banner Header ──
                  if (_tmdbId > 0 || _selectedMedia != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 64,
                              height: 94,
                              child: posterUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: posterUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: AppColors.surfaceHighest),
                                      errorWidget: (_, __, ___) => const Icon(Icons.movie_outlined, color: AppColors.textMuted),
                                    )
                                  : Container(color: AppColors.surfaceHighest, child: const Icon(Icons.movie_outlined)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _titleController.text.isNotEmpty ? _titleController.text : 'Media Title',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _type == 'TV_SHOW' ? '📺 TV Show' : '🎬 Movie',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                    ),
                                    if (year.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text('• $year', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    ],
                                    if (tmdbVote != null && tmdbVote > 0) ...[
                                      const SizedBox(width: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star_rounded, color: AppColors.primary, size: 13),
                                          const SizedBox(width: 2),
                                          Text(
                                            tmdbVote.toStringAsFixed(1),
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                if (overview != null && overview.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    overview,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted, height: 1.3),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!isEditing)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 18),
                              onPressed: () {
                                setState(() {
                                  _tmdbId = 0;
                                  _selectedMedia = null;
                                  _mediaDetails = null;
                                  _titleController.clear();
                                  _searchController.clear();
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Search Media Field (If Not Editing & No Selection) ──
                  if (!isEditing && _tmdbId == 0 && _selectedMedia == null) ...[
                    const _SectionLabel('What did you watch?'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppColors.textPrimary),
                      onChanged: _searchMedia,
                      decoration: InputDecoration(
                        hintText: 'Search movie or TV show title…',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                              )
                            : null,
                      ),
                    ),
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: _searchResults.map((media) => _SearchResultTile(
                            media: media,
                            onTap: () {
                              setState(() {
                                _selectedMedia = media;
                                _tmdbId = media.id;
                                _titleController.text = media.title;
                                _type = media.mediaType == 'movie' ? 'MOVIE' : 'TV_SHOW';
                                _searchResults.clear();
                              });
                              _loadMediaDetails(media.id, _type);
                              _checkSuggestionsForTmdbId(media.id);
                            },
                          )).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // ── Rating Section with 0.1 Precision & Rating Guide Breakdown ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionLabel('Rate this Cinematic Experience'),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showRatingGuide = !_showRatingGuide;
                          });
                        },
                        child: Row(
                          children: [
                            Icon(
                              _showRatingGuide ? Icons.info_rounded : Icons.info_outline_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showRatingGuide ? 'Hide Scale' : 'Rating Scale Guide',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Rating Container Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Star Bar + 0.1 Precision Number Field Box
                        Row(
                          children: [
                            // 5-Star Row (interactive 0.5 step touch)
                            Expanded(
                              child: RatingBar.builder(
                                initialRating: _rating / 2,
                                minRating: 0,
                                maxRating: 5,
                                allowHalfRating: true,
                                itemSize: 28,
                                unratedColor: AppColors.surfaceHighest,
                                itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: AppColors.primary),
                                onRatingUpdate: (rating) => setState(() {
                                  final val = (rating * 20).round() / 10;
                                  _rating = val;
                                  _ratingInputController.text = val > 0 ? val.toStringAsFixed(1) : '';
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Direct 0.1 Precision Input Field Box (e.g. 4.6, 8.9, 9.7)
                            Container(
                              width: 86,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _ratingInputController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        hintText: '0.0',
                                        hintStyle: TextStyle(color: AppColors.textMuted),
                                      ),
                                      onChanged: (val) {
                                        final parsed = double.tryParse(val);
                                        if (parsed != null) {
                                          final clamped = (parsed.clamp(0.0, 10.0) * 10).round() / 10;
                                          setState(() => _rating = clamped);
                                        }
                                      },
                                    ),
                                  ),
                                  const Text(
                                    '/ 10',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Smooth 0.1 Precision Slider (0.0 to 10.0)
                        Row(
                          children: [
                            const Text('0', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  activeTrackColor: AppColors.primary,
                                  inactiveTrackColor: AppColors.surfaceHighest,
                                  thumbColor: AppColors.primary,
                                  overlayColor: AppColors.primary.withValues(alpha: 0.2),
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                ),
                                child: Slider(
                                  value: _rating.clamp(0.0, 10.0),
                                  min: 0.0,
                                  max: 10.0,
                                  divisions: 100, // 0.1 precision increments!
                                  label: _rating.toStringAsFixed(1),
                                  onChanged: (val) {
                                    final step = (val * 10).round() / 10;
                                    setState(() {
                                      _rating = step;
                                      _ratingInputController.text = step > 0 ? step.toStringAsFixed(1) : '';
                                    });
                                  },
                                ),
                              ),
                            ),
                            const Text('10', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Dynamic Mood Banner Box
                        Builder(builder: (_) {
                          final mood = _getRatingMoodInfo(_rating);
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: mood.color.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                Icon(mood.icon, color: mood.color, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    mood.text,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: mood.color == AppColors.textMuted ? AppColors.textMuted : Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        // Rating Scale Breakdown Guide (Expandable)
                        if (_showRatingGuide) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 12),
                          const Text(
                            '📜 WatchHive Cinephile Rating Scale Breakdown',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const _RatingScaleRow(range: '9.6 – 10.0', label: 'Masterpiece / Cinematic Perfection 🏆', color: Colors.amberAccent),
                          const _RatingScaleRow(range: '8.6 – 9.5', label: 'Outstanding / Near Flawless 🌟', color: AppColors.primary),
                          const _RatingScaleRow(range: '7.1 – 8.5', label: 'Excellent / Highly Recommended 🔥', color: Colors.greenAccent),
                          const _RatingScaleRow(range: '5.6 – 7.0', label: 'Decent / Enjoyable 👍', color: Colors.lightGreenAccent),
                          const _RatingScaleRow(range: '4.1 – 5.5', label: 'Mediocre / Average 🍿', color: Colors.amber),
                          const _RatingScaleRow(range: '2.1 – 4.0', label: 'Poor / Not Recommended 👎', color: Colors.orangeAccent),
                          const _RatingScaleRow(range: '0.1 – 2.0', label: 'Disaster / Complete Waste of Time 🗑️', color: Colors.redAccent),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Review Field ──
                  const _SectionLabel('Write a Review or Log Thoughts'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reviewController,
                    maxLines: 3,
                    maxLength: 5000,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Pour your cinematic critique here… how was the acting, direction, cinematography, or soundtrack?',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Watch Location Presets ──
                  const _SectionLabel('Where did you watch it?'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _locationPresets.map((preset) {
                      final isSelected = _watchLocation == preset.value;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _watchLocation = isSelected ? '' : preset.value;
                          _locationController.text = _watchLocation;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? preset.color.withValues(alpha: 0.2) : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? preset.color : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                preset.icon,
                                size: 16,
                                color: isSelected ? preset.color : AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                preset.label,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _locationController,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary),
                    onChanged: (val) => setState(() => _watchLocation = val),
                    decoration: const InputDecoration(
                      hintText: 'Or type custom location (e.g. IMAX, Flight, Living Room)…',
                      prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary, size: 18),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Suggested By Friend Interactive Picker ──
                  const _SectionLabel('💡 Suggested By (Tag a friend who recommended this)'),
                  const SizedBox(height: 8),
                  if (_suggestedByUserId != null && _suggestedByUserId!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary,
                            backgroundImage: _suggestorAvatar != null && _suggestorAvatar!.isNotEmpty
                                ? NetworkImage(_suggestorAvatar!)
                                : null,
                            child: _suggestorAvatar == null || _suggestorAvatar!.isEmpty
                                ? Text((_suggestorUsername ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _suggestorDisplayName ?? '@${_suggestorUsername ?? "user"}',
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                if (_suggestorUsername != null)
                                  Text(
                                    '@$_suggestorUsername',
                                    style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Colors.amber, fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                            icon: const Icon(Icons.close_rounded, color: Colors.amber, size: 20),
                            onPressed: () => setState(() {
                              _suggestedByUserId = null;
                              _suggestorUsername = null;
                              _suggestorDisplayName = null;
                              _suggestorAvatar = null;
                              _suggestedByController.clear();
                            }),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        TextField(
                          controller: _suggestedByController,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary),
                          onChanged: (val) {
                            _searchFriends(val);
                          },
                          onTap: () {
                            if (_friendResults.isEmpty) _searchFriends('');
                          },
                          decoration: InputDecoration(
                            hintText: 'Search follower or friend username…',
                            prefixIcon: const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 20),
                            suffixIcon: _isSearchingFriends
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                                  )
                                : null,
                          ),
                        ),
                        if (_showFriendPicker && _friendResults.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.all(6),
                              itemCount: _friendResults.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                              itemBuilder: (ctx, i) {
                                final user = _friendResults[i];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    setState(() {
                                      _suggestedByUserId = user.id;
                                      _suggestorUsername = user.username;
                                      _suggestorDisplayName = user.displayName;
                                      _suggestorAvatar = user.profilePictureUrl;
                                      _showFriendPicker = false;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AppColors.primary,
                                          backgroundImage: user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty
                                              ? NetworkImage(user.profilePictureUrl!)
                                              : null,
                                          child: user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty
                                              ? Text(
                                                  (user.displayName ?? user.username)[0].toUpperCase(),
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.displayName ?? user.username,
                                                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                              ),
                                              Text(
                                                '@${user.username}',
                                                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 18),
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
                  const SizedBox(height: 16),

                  // ── Cinematic Tags System ──
                  const _SectionLabel('Cinematic Tags'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagController,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary),
                          onSubmitted: (_) => _addTag(),
                          decoration: const InputDecoration(
                            hintText: 'Add tag (e.g. masterpiece, thriller)…',
                            prefixIcon: Icon(Icons.sell_outlined, color: AppColors.textMuted, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addTag,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        child: const Text('Add +', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('#$tag', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _removeTag(tag),
                              child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Toggles (Rewatch / Currently Watching) ──
                  _Toggle(
                    label: '🔁 Mark as Rewatch',
                    value: _isRewatch,
                    onChanged: (v) => setState(() => _isRewatch = v),
                  ),
                  const SizedBox(height: 8),
                  _Toggle(
                    label: '▶ Currently Watching',
                    value: _isWatching,
                    onChanged: (v) => setState(() => _isWatching = v),
                  ),
                  const SizedBox(height: 28),

                  // ── Save Changes / Log Entry Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                          : Text(
                              isEditing ? 'Save Changes' : 'Log Entry',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final MediaResult media;
  final VoidCallback onTap;

  const _SearchResultTile({required this.media, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              media.mediaType == 'movie' ? Icons.movie_creation_outlined : Icons.tv_outlined,
              color: AppColors.primary,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.title,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  if (media.year.isNotEmpty)
                    Text(media.year, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingScaleRow extends StatelessWidget {
  final String range;
  final String label;
  final Color color;

  const _RatingScaleRow({
    required this.range,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 76,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              range,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
