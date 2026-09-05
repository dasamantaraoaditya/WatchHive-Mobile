import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/suggestion.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../repositories/entries_repository.dart';
import '../repositories/suggestions_repository.dart';
import '../screens/add_entry_sheet.dart';
import '../screens/entries_screen.dart';
import '../../search/repositories/search_repository.dart';
import 'wh_entry_grid_card.dart';
import '../../../core/utils/error_handler.dart';


class SuggestionCard extends ConsumerStatefulWidget {
  final GroupedSuggestion group;
  final VoidCallback onRefresh;
  final Function(int tmdbId, String mediaType)? onTapMedia;

  const SuggestionCard({
    super.key,
    required this.group,
    required this.onRefresh,
    this.onTapMedia,
  });

  @override
  ConsumerState<SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends ConsumerState<SuggestionCard> {

  Future<void> _handleAddToWatching(String title) async {
    final firstSuggestor = widget.group.suggestors.isNotEmpty ? widget.group.suggestors.first : null;
    final isTv = widget.group.mediaType == 'tv';
    String effectiveTitle = title.trim();

    if ((effectiveTitle.isEmpty || effectiveTitle == 'Untitled') && widget.group.tmdbId > 0) {
      try {
        final searchRepo = ref.read(searchRepositoryProvider);
        final details = isTv
            ? await searchRepo.getTvDetails(widget.group.tmdbId)
            : await searchRepo.getMovieDetails(widget.group.tmdbId);
        final realTitle = (details['title'] as String?) ??
            (details['name'] as String?) ??
            (details['original_title'] as String?) ??
            (details['original_name'] as String?);
        if (realTitle != null && realTitle.trim().isNotEmpty) {
          effectiveTitle = realTitle.trim();
        }
      } catch (_) {}
    }

    final cleanTitle = effectiveTitle.isNotEmpty && effectiveTitle != 'Untitled'
        ? effectiveTitle
        : (isTv ? 'this TV show' : 'this movie');

    if (!mounted) return;

    final confirm = await WHAlert.confirm(
      context,
      title: 'Move to Currently Watching',
      message: 'Would you like to move "$cleanTitle" to your Currently Watching log?',
      confirmText: 'Move to Watching',
      severity: WHAlertSeverity.primary,
      icon: Icons.play_circle_outline_rounded,
    );
    if (!confirm || !mounted) return;

    try {
      final repo = ref.read(entriesRepositoryProvider);
      final suggRepo = ref.read(suggestionsRepositoryProvider);
      final entry = await repo.createEntry({
        'tmdbId': widget.group.tmdbId,
        'title': effectiveTitle.isNotEmpty && effectiveTitle != 'Untitled' ? effectiveTitle : cleanTitle,
        'type': isTv ? 'TV_SHOW' : 'MOVIE',
        'isWatching': true,
        'startedAt': DateTime.now().toIso8601String(),
        if (firstSuggestor != null) 'suggestedByUserId': firstSuggestor.id,
      });

      ref.read(entriesProvider(true).notifier).addEntry(entry);

      await Future.wait(widget.group.suggestions.map((s) => suggRepo.deleteSuggestion(s.id)));
      if (mounted) {
        WHAlert.showSuccess(context, 'Moved "$cleanTitle" to Currently Watching! 🎬');
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Could not update currently watching. Please try again.',
          ),
        );
      }
    }
  }

  Future<void> _handleMarkAsWatched() async {
    final firstSuggestor = widget.group.suggestors.isNotEmpty ? widget.group.suggestors.first : null;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEntrySheet(
        prefillTmdbId: widget.group.tmdbId,
        prefillType: widget.group.mediaType == 'tv' ? 'TV_SHOW' : 'MOVIE',
        prefillSuggestedByUserId: firstSuggestor?.id,
        onSuccess: () async {
          final suggRepo = ref.read(suggestionsRepositoryProvider);
          await Future.wait(widget.group.suggestions.map((s) => suggRepo.deleteSuggestion(s.id)));
          if (mounted) {
            widget.onRefresh();
          }
        },
      ),
    );
  }

  Future<void> _handleDelete(String title) async {
    final isTv = widget.group.mediaType == 'tv';
    String effectiveTitle = title.trim();

    if ((effectiveTitle.isEmpty || effectiveTitle == 'Untitled') && widget.group.tmdbId > 0) {
      try {
        final searchRepo = ref.read(searchRepositoryProvider);
        final details = isTv
            ? await searchRepo.getTvDetails(widget.group.tmdbId)
            : await searchRepo.getMovieDetails(widget.group.tmdbId);
        final realTitle = (details['title'] as String?) ??
            (details['name'] as String?) ??
            (details['original_title'] as String?) ??
            (details['original_name'] as String?);
        if (realTitle != null && realTitle.trim().isNotEmpty) {
          effectiveTitle = realTitle.trim();
        }
      } catch (_) {}
    }

    final cleanTitle = effectiveTitle.isNotEmpty && effectiveTitle != 'Untitled'
        ? effectiveTitle
        : (isTv ? 'this TV show' : 'this movie');

    if (!mounted) return;

    final confirm = await WHAlert.confirm(
      context,
      title: 'Dismiss Suggestion',
      message: 'Dismiss recommendation for "$cleanTitle"?',
      confirmText: 'Dismiss',
      severity: WHAlertSeverity.danger,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirm || !mounted) return;

    try {
      final suggRepo = ref.read(suggestionsRepositoryProvider);
      await Future.wait(widget.group.suggestions.map((s) => suggRepo.deleteSuggestion(s.id)));
      if (mounted) {
        WHAlert.showSuccess(context, 'Dismissed recommendation for "$cleanTitle"');
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Could not dismiss suggestion. Please try again.',
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final mediaType = widget.group.mediaType == 'tv' ? 'tv' : 'movie';
    final tmdbId = widget.group.tmdbId;

    final detailsAsync = ref.watch(tmdbMediaDetailsProvider((tmdbId: tmdbId, mediaType: mediaType)));

    final title = (detailsAsync.value?['title'] as String?) ??
        (detailsAsync.value?['name'] as String?) ??
        'Movie #$tmdbId';
    final posterPath = detailsAsync.value?['poster_path'] as String?;
    final voteAvg = (detailsAsync.value?['vote_average'] as num?)?.toDouble();

    final suggestors = widget.group.suggestors;
    final firstSuggestor = suggestors.isNotEmpty ? suggestors.first : null;
    final suggestorDisplay = firstSuggestor != null
        ? (suggestors.length > 1
            ? '${firstSuggestor.username} (+${suggestors.length - 1})'
            : firstSuggestor.username)
        : null;

    final firstSuggestion = widget.group.suggestions.isNotEmpty ? widget.group.suggestions.first : null;
    final suggestedDate = firstSuggestion != null && firstSuggestion.createdAt.isNotEmpty
        ? DateTime.tryParse(firstSuggestion.createdAt)
        : null;

    return WHEntryGridCard(
      tmdbId: tmdbId,
      title: title,
      initialPosterPath: posterPath,
      mediaType: mediaType,
      mode: WHEntryCardMode.suggestion,
      rating: voteAvg,
      suggestedAt: suggestedDate,
      suggestedByUsername: suggestorDisplay,
      suggestedByAvatarUrl: firstSuggestor?.profilePictureUrl,
      onTap: () => widget.onTapMedia?.call(tmdbId, mediaType),
      onMoveToWatchingWithTitle: (resolvedTitle) => _handleAddToWatching(
        resolvedTitle.isNotEmpty && resolvedTitle != 'Untitled' ? resolvedTitle : title,
      ),
      onMoveToWatching: () => _handleAddToWatching(title),
      onMarkWatched: _handleMarkAsWatched,
      onDeleteWithTitle: (resolvedTitle) => _handleDelete(
        resolvedTitle.isNotEmpty && resolvedTitle != 'Untitled' ? resolvedTitle : title,
      ),
      onDelete: () => _handleDelete(title),
    );
  }
}
