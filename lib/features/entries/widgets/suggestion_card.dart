import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/suggestion.dart';
import '../repositories/entries_repository.dart';
import '../repositories/suggestions_repository.dart';
import '../screens/add_entry_sheet.dart';
import 'wh_entry_grid_card.dart';

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

  Future<void> _handleAddToWatching() async {
    final firstSuggestor = widget.group.suggestors.isNotEmpty ? widget.group.suggestors.first : null;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Log as Currently Watching'),
        content: const Text('Move this title to your Currently Watching log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final repo = ref.read(entriesRepositoryProvider);
      final suggRepo = ref.read(suggestionsRepositoryProvider);
      await repo.createEntry({
        'tmdbId': widget.group.tmdbId,
        'title': 'TMDB Title #${widget.group.tmdbId}',
        'type': widget.group.mediaType == 'tv' ? 'TV_SHOW' : 'MOVIE',
        'isWatching': true,
        'startedAt': DateTime.now().toIso8601String(),
        if (firstSuggestor != null) 'suggestedByUserId': firstSuggestor.id,
      });

      await Future.wait(widget.group.suggestions.map((s) => suggRepo.deleteSuggestion(s.id)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to Currently Watching!')),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to currently watching: $e')),
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
        prefillSuggestor: firstSuggestor,
        onSuccess: () {
          final suggRepo = ref.read(suggestionsRepositoryProvider);
          Future.wait(widget.group.suggestions.map((s) => suggRepo.deleteSuggestion(s.id)))
              .then((_) => widget.onRefresh())
              .catchError((_) => widget.onRefresh());
        },
      ),
    );
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Delete Suggestion'),
        content: const Text('Delete this suggestion from your list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final suggRepo = ref.read(suggestionsRepositoryProvider);
      await Future.wait(widget.group.suggestions.map((s) => suggRepo.deleteSuggestion(s.id)));
      if (mounted) widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete suggestion: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstSuggestor = widget.group.suggestors.isNotEmpty ? widget.group.suggestors.first : null;
    final mediaType = widget.group.mediaType == 'tv' ? 'tv' : 'movie';
    final tmdbId = widget.group.tmdbId;

    return WHEntryGridCard(
      tmdbId: tmdbId,
      title: 'Title #$tmdbId',
      mediaType: mediaType,
      mode: WHEntryCardMode.suggestion,
      suggestedByUsername: firstSuggestor?.username,
      suggestedByAvatarUrl: firstSuggestor?.profilePictureUrl,
      onTap: () => widget.onTapMedia?.call(tmdbId, mediaType),
      onMoveToWatching: _handleAddToWatching,
      onMarkWatched: _handleMarkAsWatched,
      onDelete: _handleDelete,
    );
  }
}
