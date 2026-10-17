import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../repositories/entries_repository.dart';
import '../repositories/suggestions_repository.dart';
import 'entries_screen.dart';
import '../../feed/providers/feed_provider.dart';
import '../../../core/utils/error_handler.dart';
import '../../search/repositories/search_repository.dart';
import '../widgets/platform_logo_badge.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/offline_sync_manager.dart';
import '../../../core/services/offline_storage_service.dart';

class _LocationPreset {
  final String label;
  final String value;
  final List<String> altValues;
  final Color color;

  const _LocationPreset({
    required this.label,
    required this.value,
    this.altValues = const [],
    required this.color,
  });
}

const _locationPresets = [
  _LocationPreset(label: 'Cinema', value: 'Cinema', color: Color(0xFFE53935)),
  _LocationPreset(label: 'Home', value: 'Home', color: Color(0xFFF39C12)),
  _LocationPreset(label: 'Netflix', value: 'Netflix', color: Color(0xFFE50914)),
  _LocationPreset(label: 'Hotstar', value: 'Disney+ Hotstar', altValues: ['Disney+', 'Hotstar'], color: Color(0xFF00A8E8)),
  _LocationPreset(label: 'Prime', value: 'Prime Video', altValues: ['Prime'], color: Color(0xFF00A8E8)),
  _LocationPreset(label: 'JioCinema', value: 'JioCinema', color: Color(0xFFD80064)),
  _LocationPreset(label: 'YouTube', value: 'YouTube', color: Color(0xFFFF0000)),
  _LocationPreset(label: 'Apple TV+', value: 'Apple TV+', color: Color(0xFFFFFFFF)),
  _LocationPreset(label: 'On the Go', value: 'On the Go', altValues: ['Mobile'], color: Color(0xFF00D2D3)),
];

const _quickTagPresets = [
  'Masterpiece',
  'MindBending',
  'ComfortWatch',
  'Cinematography',
  'WeekendBinge',
  'PlotTwist',
  'CultClassic',
];

class AddEntrySheet extends ConsumerStatefulWidget {
  final Entry? editEntry;
  final int? prefillTmdbId;
  final String? prefillType;
  final String? prefillTitle;
  final String? prefillPosterPath;
  final User? prefillSuggestor;
  final String? prefillSuggestedByUserId;
  final bool? prefillIsWatching;
  final VoidCallback? onSuccess;

  const AddEntrySheet({
    super.key,
    this.editEntry,
    this.prefillTmdbId,
    this.prefillType,
    this.prefillTitle,
    this.prefillPosterPath,
    this.prefillSuggestor,
    this.prefillSuggestedByUserId,
    this.prefillIsWatching,
    this.onSuccess,
  });

  @override
  ConsumerState<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<AddEntrySheet> {
  final _scrollController = ScrollController();

  final _mediaKey = GlobalKey();
  final _scoreKey = GlobalKey();
  final _dateKey = GlobalKey();
  final _reviewKey = GlobalKey();
  final _locationKey = GlobalKey();
  final _suggestedByKey = GlobalKey();
  final _tagsKey = GlobalKey();

  final _searchFocusNode = FocusNode();
  final _reviewFocusNode = FocusNode();
  final _locationFocusNode = FocusNode();
  final _suggestedByFocusNode = FocusNode();
  final _tagFocusNode = FocusNode();

  Timer? _friendDebounce;
  Timer? _mediaDebounce;

  final _titleController = TextEditingController();
  final _reviewController = TextEditingController();
  final _searchController = TextEditingController();
  final _suggestedByController = TextEditingController();
  final _locationController = TextEditingController();
  final _tagController = TextEditingController();

  int _tmdbId = 0;
  String _type = 'MOVIE';
  double _rating = 0.0;
  bool _isRewatch = false;
  bool _isWatching = false;
  bool _isLoading = false;
  String _watchLocation = '';
  List<String> _tags = [];
  DateTime _watchedDate = DateTime.now();

  List<MediaResult> _searchResults = [];
  bool _isSearching = false;
  MediaResult? _selectedMedia;
  Map<String, dynamic>? _mediaDetails;

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

    // Auto-scroll hooks so active fields are always smoothly positioned above the keyboard
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        _scrollToKey(_mediaKey, alignment: 0.0);
      }
    });

    _reviewFocusNode.addListener(() {
      if (_reviewFocusNode.hasFocus) {
        _scrollToKey(_reviewKey, alignment: 0.08);
      }
    });

    _locationFocusNode.addListener(() {
      if (_locationFocusNode.hasFocus) {
        _scrollToKey(_locationKey, alignment: 0.08);
      }
    });

    _suggestedByFocusNode.addListener(() {
      if (_suggestedByFocusNode.hasFocus) {
        if (_friendResults.isEmpty && !_isSearchingFriends) {
          _searchFriends('');
        }
        _scrollToKey(_suggestedByKey, alignment: 0.05);
      }
    });

    _tagFocusNode.addListener(() {
      if (_tagFocusNode.hasFocus) {
        _scrollToKey(_tagsKey, alignment: 0.1);
      }
    });

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
      _rating = e.rating ?? 0.0;
      _isRewatch = e.isRewatch;
      _isWatching = widget.prefillIsWatching ?? e.isWatching;
      _watchLocation = e.watchLocation ?? '';
      _locationController.text = _watchLocation;
      _tags = List<String>.from(e.tags);
      _watchedDate = e.watchedAt.toLocal();
      if (_watchedDate.isAfter(DateTime.now())) {
        _watchedDate = DateTime.now();
      }
      if (_tmdbId > 0) _loadMediaDetails(_tmdbId, _type);
    } else {
      if (widget.prefillTitle != null && widget.prefillTitle!.trim().isNotEmpty) {
        _titleController.text = widget.prefillTitle!.trim();
      }
      if (widget.prefillIsWatching != null) {
        _isWatching = widget.prefillIsWatching!;
      }
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
        if (_suggestedByUserId == null) _checkSuggestionsForTmdbId(_tmdbId);
      }
    }
  }

  @override
  void dispose() {
    _friendDebounce?.cancel();
    _mediaDebounce?.cancel();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _reviewFocusNode.dispose();
    _locationFocusNode.dispose();
    _suggestedByFocusNode.dispose();
    _tagFocusNode.dispose();
    _titleController.dispose();
    _reviewController.dispose();
    _searchController.dispose();
    _suggestedByController.dispose();
    _locationController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _scrollToKey(GlobalKey key, {double alignment = 0.08}) {
    void executeScroll() {
      if (!mounted) return;
      final keyContext = key.currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          alignment: alignment,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      executeScroll();
      Future.delayed(const Duration(milliseconds: 220), executeScroll);
    });
  }

  Widget _buildQuickNavStrip() {
    final hasMedia = _tmdbId > 0 || _selectedMedia != null || isEditing;
    final hasScore = _rating > 0;
    final hasReview = _reviewController.text.trim().isNotEmpty;
    final hasLocation = _watchLocation.trim().isNotEmpty;
    final hasFriend = _suggestedByUserId != null && _suggestedByUserId!.isNotEmpty;
    final hasTags = _tags.isNotEmpty;

    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _buildNavPill(
            label: hasMedia ? 'Title ✓' : '1. Title',
            icon: Icons.movie_outlined,
            isCompleted: hasMedia,
            onTap: () {
              _scrollToKey(_mediaKey, alignment: 0.0);
              if (!hasMedia) _searchFocusNode.requestFocus();
            },
          ),
          const SizedBox(width: 8),
          _buildNavPill(
            label: hasScore ? '${_rating.toStringAsFixed(1)} ★' : '2. Score',
            icon: Icons.star_rounded,
            isCompleted: hasScore,
            onTap: () => _scrollToKey(_scoreKey, alignment: 0.08),
          ),
          const SizedBox(width: 8),
          _buildNavPill(
            label: DateFormat('MMM dd').format(_watchedDate),
            icon: Icons.calendar_today_rounded,
            isCompleted: true,
            onTap: () => _scrollToKey(_dateKey, alignment: 0.08),
          ),
          const SizedBox(width: 8),
          _buildNavPill(
            label: hasReview ? 'Review ✓' : 'Review',
            icon: Icons.rate_review_outlined,
            isCompleted: hasReview,
            onTap: () {
              _scrollToKey(_reviewKey, alignment: 0.08);
              _reviewFocusNode.requestFocus();
            },
          ),
          const SizedBox(width: 8),
          _buildNavPill(
            label: hasLocation ? _watchLocation : 'Place',
            icon: Icons.location_on_outlined,
            isCompleted: hasLocation,
            onTap: () {
              _scrollToKey(_locationKey, alignment: 0.08);
              _locationFocusNode.requestFocus();
            },
          ),
          const SizedBox(width: 8),
          _buildNavPill(
            label: hasFriend
                ? (_suggestorUsername != null ? '@$_suggestorUsername' : 'Friend ✓')
                : 'Friend 💡',
            icon: Icons.people_outline_rounded,
            isCompleted: hasFriend,
            isHighlighted: !hasFriend,
            onTap: () {
              _scrollToKey(_suggestedByKey, alignment: 0.05);
              if (!hasFriend) {
                _suggestedByFocusNode.requestFocus();
                if (_friendResults.isEmpty && !_isSearchingFriends) {
                  _searchFriends('');
                }
              }
            },
          ),
          const SizedBox(width: 8),
          _buildNavPill(
            label: hasTags ? '${_tags.length} Tags' : 'Tags',
            icon: Icons.sell_outlined,
            isCompleted: hasTags,
            onTap: () {
              _scrollToKey(_tagsKey, alignment: 0.1);
              _tagFocusNode.requestFocus();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavPill({
    required String label,
    required IconData icon,
    required bool isCompleted,
    bool isHighlighted = false,
    required VoidCallback onTap,
  }) {
    final bgColor = isCompleted
        ? AppColors.primary.withValues(alpha: 0.16)
        : (isHighlighted ? AppColors.surfaceElevated : AppColors.surface);
    final borderColor = isCompleted
        ? AppColors.primary
        : AppColors.border;
    final textColor = isCompleted
        ? AppColors.textPrimary
        : AppColors.textSecondary;
    final iconColor = isCompleted
        ? AppColors.primaryDark
        : AppColors.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: isCompleted ? 1.2 : 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: isCompleted ? FontWeight.w800 : FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          if (_titleController.text.trim().isEmpty) {
            final fetched = (details['title'] ??
                    details['name'] ??
                    details['original_title'] ??
                    details['original_name'] ??
                    '')
                .toString()
                .trim();
            if (fetched.isNotEmpty) {
              _titleController.text = fetched;
            }
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
      if (results.isNotEmpty) {
        setState(() => _searchResults = results.take(6).toList());
      } else {
        // Online search returned nothing; check local cache
        final local = await ref.read(offlineStorageServiceProvider).searchLocalMedia(query);
        if (mounted && local.isNotEmpty) {
          final mapped = local.map((l) => MediaResult(
            id: l['id'] as int,
            title: l['title'] as String,
            mediaType: l['mediaType'] as String,
            posterPath: l['posterPath'] as String?,
            releaseDate: l['year'] as String?,
          )).toList();
          setState(() => _searchResults = mapped.take(6).toList());
        } else {
          setState(() => _searchResults = []);
        }
      }
    } catch (_) {
      // Network failed or offline: fall back to local media cache
      try {
        final local = await ref.read(offlineStorageServiceProvider).searchLocalMedia(query);
        if (mounted && local.isNotEmpty) {
          final mapped = local.map((l) => MediaResult(
            id: l['id'] as int,
            title: l['title'] as String,
            mediaType: l['mediaType'] as String,
            posterPath: l['posterPath'] as String?,
            releaseDate: l['year'] as String?,
          )).toList();
          setState(() => _searchResults = mapped.take(6).toList());
        }
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _searchFriends(String query) async {
    setState(() {
      _isSearchingFriends = true;
      _showFriendPicker = true;
    });
    _scrollToKey(_suggestedByKey, alignment: 0.05);
    try {
      final results = await ref.read(searchRepositoryProvider).searchUsers(query.isNotEmpty ? query : 'a');
      if (mounted) {
        setState(() {
          _friendResults = results;
          _isSearchingFriends = false;
        });
        _scrollToKey(_suggestedByKey, alignment: 0.05);
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingFriends = false);
    }
  }

  void _addTag([String? customTag]) {
    final t = (customTag ?? _tagController.text).trim().replaceAll('#', '');
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() {
        _tags.add(t);
        if (customTag == null) _tagController.clear();
      });
      HapticFeedback.lightImpact();
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
    HapticFeedback.lightImpact();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final maxDate = DateTime(now.year, now.month, now.day);
    final initial = _watchedDate.isAfter(maxDate) ? maxDate : _watchedDate;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: maxDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    // After picking a date, prompt the user for the watch time, preserving current hours/minutes as default
    final initialTime = TimeOfDay.fromDateTime(_watchedDate);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
          ),
          child: child!,
        );
      },
    );

    final resolvedTime = pickedTime ?? initialTime;
    var candidateDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      resolvedTime.hour,
      resolvedTime.minute,
    );

    if (candidateDateTime.isAfter(now)) {
      candidateDateTime = now;
      if (mounted) {
        WHAlert.showWarning(context, 'Future time not allowed (set to current time).');
      }
    }

    if (mounted) {
      setState(() {
        _watchedDate = candidateDateTime;
      });
    }
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final initialTime = TimeOfDay.fromDateTime(_watchedDate);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null && mounted) {
      var candidate = DateTime(
        _watchedDate.year,
        _watchedDate.month,
        _watchedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      if (candidate.isAfter(now)) {
        candidate = now;
        WHAlert.showWarning(context, 'Future time not allowed (set to current time).');
      }
      setState(() {
        _watchedDate = candidate;
      });
    }
  }

  Future<void> _save() async {
    var title = _titleController.text.trim();
    if (title.isEmpty) {
      final fallbackTitle = _selectedMedia?.title ??
          (_mediaDetails?['title'] ??
                  _mediaDetails?['name'] ??
                  _mediaDetails?['original_title'] ??
                  _mediaDetails?['original_name'])
              ?.toString()
              .trim() ??
          widget.prefillTitle?.trim() ??
          _searchController.text.trim();
      if (fallbackTitle.isNotEmpty) {
        title = fallbackTitle;
        _titleController.text = fallbackTitle;
      }
    }
    if (title.isEmpty) {
      WHAlert.showWarning(context, 'Please enter or select a movie or TV show title');
      return;
    }
    final now = DateTime.now();
    if (_watchedDate.isAfter(now)) {
      _watchedDate = now;
    }
    setState(() => _isLoading = true);
    try {
      final poster = _selectedMedia?.posterPath ??
          _mediaDetails?['poster_path'] as String? ??
          widget.prefillPosterPath ??
          widget.editEntry?.posterPath;
      final backdrop = _mediaDetails?['backdrop_path'] as String? ??
          widget.editEntry?.backdropPath;

      final data = {
        'tmdbId': _tmdbId > 0 ? _tmdbId : (_selectedMedia?.id ?? 0),
        'title': title,
        'type': _type,
        if (_rating > 0) 'rating': (_rating.clamp(0.5, 10.0) * 10).round() / 10,
        if (_reviewController.text.trim().isNotEmpty) 'review': _reviewController.text.trim(),
        'isRewatch': _isRewatch,
        'isWatching': _isWatching,
        if (_watchLocation.trim().isNotEmpty) 'watchLocation': _watchLocation.trim(),
        'tags': _tags.where((t) => t.trim().isNotEmpty).toList(),
        'watchedAt': _watchedDate.toUtc().toIso8601String(),
        if (_suggestedByUserId != null && _suggestedByUserId!.trim().isNotEmpty)
          'suggestedByUserId': _suggestedByUserId!.trim(),
        if (poster != null && poster.isNotEmpty) 'posterPath': poster,
        if (backdrop != null && backdrop.isNotEmpty) 'backdropPath': backdrop,
      };

      bool isPendingSync = false;
      if (isEditing) {
        final updated = await ref.read(entriesRepositoryProvider).updateEntry(widget.editEntry!.id, data);
        isPendingSync = updated.isPendingSync;
        ref.read(entriesProvider(true).notifier).updateEntry(updated);
        ref.read(entriesProvider(false).notifier).updateEntry(updated);
        ref.read(feedProvider.notifier).updateEntry(updated);
      } else {
        final entry = await ref.read(entriesRepositoryProvider).createEntry(data);
        isPendingSync = entry.isPendingSync;
        ref.read(entriesProvider(true).notifier).addEntry(entry);
        ref.read(entriesProvider(false).notifier).addEntry(entry);
        ref.read(feedProvider.notifier).prependEntry(entry);
      }
      ref.read(offlineSyncManagerProvider.notifier).refreshPendingCount();

      if (mounted) {
        widget.onSuccess?.call();
        Navigator.of(context).pop();
        if (isPendingSync) {
          WHAlert.showInfo(
            context,
            'Saved offline! Will automatically sync to your Hive when reconnected. 📶⏳',
          );
        } else {
          WHAlert.showSuccess(
            context,
            isEditing
                ? (widget.editEntry?.isWatching == true && !_isWatching
                    ? 'Completed watching "$title"! 🎉🎬'
                    : 'Updated "$title" in your Hive! ✨')
                : (_isWatching ? 'Started watching "$title"! 👁️🎬' : 'Logged "$title" to your Hive! 🐝🎬'),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Could not save entry. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final posterPath = _selectedMedia?.posterPath ??
        _mediaDetails?['poster_path'] as String? ??
        widget.prefillPosterPath ??
        widget.editEntry?.posterPath;
    final displayTitle = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : (_selectedMedia?.title ??
            (_mediaDetails?['title'] ??
                    _mediaDetails?['name'] ??
                    _mediaDetails?['original_title'] ??
                    _mediaDetails?['original_name'])
                ?.toString()
                .trim() ??
            widget.prefillTitle ??
            'Selected Title');
    final releaseYear = _selectedMedia?.year ?? (_mediaDetails?['release_date'] as String? ?? _mediaDetails?['first_air_date'] as String?)?.split('-').first ?? '';
    final runtime = _mediaDetails?['runtime'] != null ? '${_mediaDetails!['runtime']} min' : _mediaDetails?['number_of_seasons'] != null ? '${_mediaDetails!['number_of_seasons']} Season${_mediaDetails!['number_of_seasons'] > 1 ? 's' : ''}' : '';
    final voteAverage = _selectedMedia?.voteAverage ?? (_mediaDetails?['vote_average'] as num?)?.toDouble();
    final overview = _selectedMedia?.overview ?? _mediaDetails?['overview'] as String?;
    final hasSelectedMedia = _tmdbId > 0 || _selectedMedia != null || isEditing;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        bottom: false,
        minimum: const EdgeInsets.only(top: 8),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.92,
          ),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.hive_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? (widget.editEntry?.isWatching == true && !_isWatching
                                    ? 'Complete Watch 🎬'
                                    : 'Edit Watch Entry ✨')
                                : (_isWatching ? 'Track What You\'re Watching 👁️' : 'Log a Watch to Hive 🐝'),
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          const Text('Record your cinematic rating, thoughts & review', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border, width: 0.8),
                          ),
                          child: const Icon(Icons.close_rounded, color: AppColors.textPrimary, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Interactive Navigation Strip across form sections
              _buildQuickNavStrip(),
              if (!ref.watch(connectivityServiceProvider).isOnline)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFB45309)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Offline Mode: You can still log or edit entries. Changes will be saved locally and synced when back online.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Flexible(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isWatching = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(color: !_isWatching ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                                  child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_rounded, size: 16, color: !_isWatching ? Colors.black : AppColors.textMuted), const SizedBox(width: 6), Text('Completed Watch', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w800, color: !_isWatching ? Colors.black : AppColors.textMuted))])),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isWatching = true),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(color: _isWatching ? const Color(0xFF3B82F6) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                                  child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.visibility_rounded, size: 16, color: _isWatching ? Colors.white : AppColors.textMuted), const SizedBox(width: 6), Text('Currently Watching', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w800, color: _isWatching ? Colors.white : AppColors.textMuted))])),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      KeyedSubtree(
                        key: _mediaKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasSelectedMedia) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surfaceElevated, AppColors.surfaceElevated.withValues(alpha: 0.8)]),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.2),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: posterPath != null && posterPath.isNotEmpty
                                          ? CachedNetworkImage(imageUrl: ApiEndpoints.tmdbPoster(posterPath), width: 68, height: 100, fit: BoxFit.cover, placeholder: (_, __) => Container(width: 68, height: 100, color: AppColors.surfaceHighest, child: const Center(child: Icon(Icons.movie_rounded, color: AppColors.textMuted))), errorWidget: (_, __, ___) => Container(width: 68, height: 100, color: AppColors.surfaceHighest, child: const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.textMuted))))
                                          : Container(width: 68, height: 100, decoration: BoxDecoration(color: AppColors.surfaceHighest, borderRadius: BorderRadius.circular(12)), child: const Center(child: Icon(Icons.movie_creation_outlined, color: AppColors.primary, size: 28))),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))), child: Text(_type == 'TV_SHOW' || _type == 'tv' ? '📺 TV SERIES' : '🎬 MOVIE', style: const TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.5))),
                                              if (releaseYear.isNotEmpty) ...[const SizedBox(width: 6), Text(releaseYear, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted))],
                                              if (runtime.isNotEmpty) ...[const SizedBox(width: 6), const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 12)), const SizedBox(width: 6), Text(runtime, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500))],
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(displayTitle, style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          if (voteAverage != null && voteAverage > 0) ...[
                                            const SizedBox(height: 4),
                                            Row(children: [const Icon(Icons.star_rounded, size: 14, color: AppColors.primary), const SizedBox(width: 4), Text(voteAverage.toStringAsFixed(1), style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)), const Text(' TMDB Score', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.textMuted))]),
                                          ],
                                          if (overview != null && overview.isNotEmpty) ...[const SizedBox(height: 6), Text(overview, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted, height: 1.3))],
                                        ],
                                      ),
                                    ),
                                    if (!isEditing) IconButton(icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 20), onPressed: () => setState(() { _tmdbId = 0; _selectedMedia = null; _mediaDetails = null; _titleController.clear(); _searchController.clear(); })),
                                  ],
                                ),
                              ),
                            ] else ...[
                              const _SectionHeader(title: 'What did you watch?', subtitle: 'Search across millions of movies and TV shows from TMDB'),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  textInputAction: TextInputAction.search,
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary),
                                  onChanged: (val) {
                                    _mediaDebounce?.cancel();
                                    _mediaDebounce = Timer(const Duration(milliseconds: 250), () => _searchMedia(val));
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search title (e.g. Inception, Dune, Succession)…',
                                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                                    suffixIcon: _isSearching
                                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                                        : _searchController.text.isNotEmpty
                                            ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted), onPressed: () => setState(() { _searchController.clear(); _searchResults.clear(); }))
                                            : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                ),
                              ),
                              if (_isSearching) ...[
                                const SizedBox(height: 8),
                                const WHSkeletonMediaSearchList(count: 3),
                              ] else if (_searchResults.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 6))]),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Column(
                                      children: _searchResults.map((media) => _SearchResultTile(
                                        media: media,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            _selectedMedia = media;
                                            _tmdbId = media.id;
                                            _titleController.text = media.title;
                                            _type = media.mediaType == 'movie' ? 'MOVIE' : 'TV_SHOW';
                                            _searchResults.clear();
                                          });
                                          _searchFocusNode.unfocus();
                                          _loadMediaDetails(media.id, _type);
                                          _checkSuggestionsForTmdbId(media.id);
                                          _scrollToKey(_scoreKey, alignment: 0.08);
                                        },
                                      )).toList(),
                                    ),
                                  ),
                                ),
                              ] else if (_searchController.text.trim().length >= 2) ...[
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    final custom = _searchController.text.trim();
                                    setState(() {
                                      _titleController.text = custom;
                                      _tmdbId = 0;
                                      _selectedMedia = MediaResult(
                                        id: 0,
                                        title: custom,
                                        mediaType: _type.toLowerCase().contains('tv') ? 'tv' : 'movie',
                                      );
                                      _searchResults.clear();
                                    });
                                    _searchFocusNode.unfocus();
                                    _scrollToKey(_scoreKey, alignment: 0.08);
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Use "${_searchController.text.trim()}"',
                                                style: const TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                'Log with custom title (ideal for offline or rare titles)',
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 11,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      KeyedSubtree(
                        key: _scoreKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const _SectionHeader(title: 'Cinematic Score', subtitle: 'Tap or drag across stars (0.5 to 10 scale)'),
                                if (_rating > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                    child: Text('⭐ ${_rating.toStringAsFixed(1)} / 10', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            WHRatingPicker(rating: _rating, onRatingChanged: (val) => setState(() => _rating = val)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      KeyedSubtree(
                        key: _dateKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _SectionHeader(
                                  title: _isWatching ? 'Started Watching' : 'When Did You Watch?',
                                  subtitle: 'Date and time of your screening',
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _watchedDate = DateTime.now());
                                  },
                                  icon: const Icon(Icons.history_rounded, size: 14, color: AppColors.primary),
                                  label: const Text(
                                    'Now',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _pickDate,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _isWatching ? 'Started Date' : 'Watched Date',
                                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.textMuted),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  DateFormat('MMM dd, yyyy').format(_watchedDate),
                                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _pickTime,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _isWatching ? 'Started Time' : 'Watched Time',
                                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.textMuted),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  DateFormat('h:mm a').format(_watchedDate),
                                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _isRewatch = !_isRewatch);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isRewatch ? Colors.amber.withValues(alpha: 0.18) : AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _isRewatch ? Colors.amber : AppColors.border,
                                    width: _isRewatch ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.repeat_rounded, size: 18, color: _isRewatch ? Colors.amber : AppColors.textMuted),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Rewatch Status',
                                            style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: _isRewatch ? Colors.amber : AppColors.textMuted),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _isRewatch ? 'Repeat Watch 🔁' : 'First Time Watch 🎬',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: _isRewatch ? Colors.amber : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: _isRewatch,
                                      activeThumbColor: Colors.amber,
                                      activeTrackColor: Colors.amber.withValues(alpha: 0.3),
                                      onChanged: (val) {
                                        HapticFeedback.lightImpact();
                                        setState(() => _isRewatch = val);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      KeyedSubtree(
                        key: _reviewKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(title: 'Your Thoughts & Review', subtitle: 'What did you think of the story, acting, direction & soundtrack?'),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                              child: TextField(
                                controller: _reviewController,
                                focusNode: _reviewFocusNode,
                                maxLines: 4,
                                maxLength: 5000,
                                textInputAction: TextInputAction.newline,
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary, height: 1.4),
                                decoration: const InputDecoration(hintText: 'Pour your cinematic critique here…', hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13), border: InputBorder.none, contentPadding: EdgeInsets.all(16), counterText: ''),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      KeyedSubtree(
                        key: _locationKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(title: 'Where did you watch?', subtitle: 'Select platform or theater venue'),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _locationPresets.map((preset) {
                                  final isSelected = _watchLocation == preset.value ||
                                      preset.altValues.contains(_watchLocation);
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _watchLocation = isSelected ? '' : preset.value;
                                          _locationController.text = _watchLocation;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? preset.color.withValues(alpha: 0.18)
                                              : AppColors.surfaceElevated,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isSelected ? preset.color : AppColors.border,
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            PlatformBrandLogo(
                                              platform: preset.value,
                                              size: 18,
                                              isSelected: isSelected,
                                            ),
                                            const SizedBox(width: 8),
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
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                              child: TextField(
                                controller: _locationController,
                                focusNode: _locationFocusNode,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => _suggestedByFocusNode.requestFocus(),
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textPrimary),
                                onChanged: (val) => setState(() => _watchLocation = val),
                                decoration: const InputDecoration(
                                  hintText: 'Or custom venue (e.g. IMAX Laser, Flight, Drive-in)…',
                                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                  prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary, size: 18),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      KeyedSubtree(
                        key: _suggestedByKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(title: '💡 Recommended by a Friend', subtitle: 'Tag the cinephile friend who suggested this'),
                            const SizedBox(height: 8),
                            if (_suggestedByUserId != null && _suggestedByUserId!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.withValues(alpha: 0.4))),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.primary,
                                      backgroundImage: _suggestorAvatar != null && _suggestorAvatar!.isNotEmpty ? NetworkImage(_suggestorAvatar!) : null,
                                      child: _suggestorAvatar == null || _suggestorAvatar!.isEmpty ? Text((_suggestorUsername ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)) : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_suggestorDisplayName ?? '@${_suggestorUsername ?? "user"}', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                          if (_suggestorUsername != null) Text('@$_suggestorUsername', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(6),
                                      icon: const Icon(Icons.close_rounded, color: Colors.amber, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _suggestedByUserId = null;
                                          _suggestorUsername = null;
                                          _suggestorDisplayName = null;
                                          _suggestorAvatar = null;
                                        });
                                        _scrollToKey(_suggestedByKey, alignment: 0.05);
                                        _suggestedByFocusNode.requestFocus();
                                      },
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                                    child: TextField(
                                      controller: _suggestedByController,
                                      focusNode: _suggestedByFocusNode,
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) => _tagFocusNode.requestFocus(),
                                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textPrimary),
                                      onChanged: (val) {
                                        _friendDebounce?.cancel();
                                        _friendDebounce = Timer(const Duration(milliseconds: 250), () => _searchFriends(val));
                                      },
                                      onTap: () {
                                        if (_friendResults.isEmpty && !_isSearchingFriends) {
                                          _searchFriends('');
                                        }
                                        _scrollToKey(_suggestedByKey, alignment: 0.05);
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Search follower or friend username…',
                                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                        prefixIcon: const Icon(Icons.person_search_rounded, color: Colors.amber, size: 20),
                                        suffixIcon: _isSearchingFriends
                                            ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                                            : _suggestedByController.text.isNotEmpty
                                                ? IconButton(
                                                    icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                                                    onPressed: () {
                                                      _suggestedByController.clear();
                                                      _searchFriends('');
                                                    },
                                                  )
                                                : null,
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                    ),
                                  ),
                                  if (_isSearchingFriends) ...[
                                    const SizedBox(height: 6),
                                    const WHSkeletonUserList(count: 2),
                                  ] else if (_showFriendPicker && _friendResults.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      constraints: const BoxConstraints(maxHeight: 180),
                                      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))]),
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
                                              HapticFeedback.lightImpact();
                                              setState(() {
                                                _suggestedByUserId = user.id;
                                                _suggestorUsername = user.username;
                                                _suggestorDisplayName = user.displayName;
                                                _suggestorAvatar = user.profilePictureUrl;
                                                _showFriendPicker = false;
                                              });
                                              _suggestedByFocusNode.unfocus();
                                              _scrollToKey(_tagsKey, alignment: 0.1);
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(radius: 14, backgroundColor: AppColors.primary, backgroundImage: user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty ? NetworkImage(user.profilePictureUrl!) : null, child: user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty ? Text((user.displayName ?? user.username)[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)) : null),
                                                  const SizedBox(width: 10),
                                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.displayName ?? user.username, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)), Text('@${user.username}', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted))])),
                                                  const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 18),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ] else if (_showFriendPicker && !_isSearchingFriends && _friendResults.isEmpty && _suggestedByController.text.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceElevated,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person_off_rounded, size: 16, color: AppColors.textMuted),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'No friends found for "${_suggestedByController.text.trim()}".',
                                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textMuted),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      KeyedSubtree(
                        key: _tagsKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(title: 'Cinematic Tags', subtitle: 'Categorize your entry with tags and genres'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _quickTagPresets.map((presetTag) {
                                final isAdded = _tags.contains(presetTag);
                                return GestureDetector(
                                  onTap: () => isAdded ? _removeTag(presetTag) : _addTag(presetTag),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: isAdded ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: isAdded ? AppColors.primary : AppColors.border)),
                                    child: Text('#$presetTag ${isAdded ? '✓' : '+'}', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: isAdded ? FontWeight.bold : FontWeight.w500, color: isAdded ? AppColors.primary : AppColors.textSecondary)),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                                    child: TextField(
                                      controller: _tagController,
                                      focusNode: _tagFocusNode,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => _addTag(),
                                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textPrimary),
                                      decoration: const InputDecoration(
                                        hintText: 'Type custom tag (e.g. noir, anime, plot-twist)…',
                                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                        prefixIcon: Icon(Icons.sell_outlined, color: AppColors.textMuted, size: 18),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _addTag(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                  ),
                                  child: const Text('Add +', style: TextStyle(fontFamily: 'Inter', color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ],
                            ),
                            if (_tags.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _tags.map((tag) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withValues(alpha: 0.35))), child: Row(mainAxisSize: MainAxisSize.min, children: [Text('#$tag', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)), const SizedBox(width: 5), GestureDetector(onTap: () => _removeTag(tag), child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary))]))).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
                ),
                child: SafeArea(
                  top: false,
                  bottom: bottomInset == 0,
                  child: Row(
                    children: [
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surfaceElevated,
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border, width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                              SizedBox(width: 6),
                              Text(
                                'Close',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 4,
                              shadowColor: AppColors.primary.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isEditing
                                            ? (widget.editEntry?.isWatching == true && !_isWatching
                                                ? Icons.task_alt_rounded
                                                : Icons.save_rounded)
                                            : Icons.hive_rounded,
                                        color: Colors.black,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          isEditing
                                              ? (widget.editEntry?.isWatching == true && !_isWatching
                                                  ? 'Complete Watch 🎬'
                                                  : 'Save Changes ✨')
                                              : (_isWatching
                                                  ? 'Track Watching 👁️'
                                                  : 'Log to Hive 🐝🎬'),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 0.2)),
        if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted))],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: media.posterPath != null && media.posterPath!.isNotEmpty
                  ? CachedNetworkImage(imageUrl: ApiEndpoints.tmdbPoster(media.posterPath!), width: 32, height: 48, fit: BoxFit.cover, placeholder: (_, __) => Container(width: 32, height: 48, color: AppColors.surfaceHighest), errorWidget: (_, __, ___) => Container(width: 32, height: 48, color: AppColors.surfaceHighest, child: const Icon(Icons.movie_rounded, size: 16, color: AppColors.textMuted)))
                  : Container(width: 32, height: 48, decoration: BoxDecoration(color: AppColors.surfaceHighest, borderRadius: BorderRadius.circular(6)), child: Icon(media.mediaType == 'movie' ? Icons.movie_creation_outlined : Icons.tv_outlined, color: AppColors.primary, size: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(media.title, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          media.mediaType == 'movie' ? 'MOVIE' : 'TV',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (media.year.isNotEmpty) ...[const SizedBox(width: 6), Text(media.year, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))],
                      if (media.voteAverage != null && media.voteAverage! > 0) ...[
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        const SizedBox(width: 6),
                        const Icon(Icons.star_rounded, size: 12, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Text(media.voteAverage!.toStringAsFixed(1), style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}

