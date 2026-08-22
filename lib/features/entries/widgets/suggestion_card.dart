import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/suggestion.dart';
import '../repositories/entries_repository.dart';
import '../repositories/suggestions_repository.dart';
import '../screens/add_entry_sheet.dart';

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
  bool _isProcessing = false;

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

    setState(() => _isProcessing = true);
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
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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

    setState(() => _isProcessing = true);
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
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstSuggestor = widget.group.suggestors.isNotEmpty ? widget.group.suggestors.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: () => widget.onTapMedia?.call(widget.group.tmdbId, widget.group.mediaType),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 44,
            height: 66,
            color: Colors.amber.withOpacity(0.12),
            child: const Icon(Icons.movie_outlined, color: AppColors.primary),
          ),
        ),
        title: Text(
          'Title #${widget.group.tmdbId}',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (firstSuggestor != null)
              Row(
                children: [
                  const Text(
                    'Suggested by ',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  CircleAvatar(
                    radius: 8,
                    backgroundColor: AppColors.primary,
                    backgroundImage: firstSuggestor.profilePictureUrl != null
                        ? NetworkImage(firstSuggestor.profilePictureUrl!)
                        : null,
                    onBackgroundImageError: (_, __) {},
                    child: firstSuggestor.profilePictureUrl == null
                        ? Text(
                            (firstSuggestor.displayName ?? firstSuggestor.username)[0].toUpperCase(),
                            style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '@${firstSuggestor.username}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, color: AppColors.primary, size: 20),
                    tooltip: 'Log as Currently Watching',
                    onPressed: _handleAddToWatching,
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                    tooltip: 'Mark as Watched',
                    onPressed: _handleMarkAsWatched,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    tooltip: 'Delete',
                    onPressed: _handleDelete,
                  ),
                ],
              ),
      ),
    );
  }
}
