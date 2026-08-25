import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../repositories/watchlist_repository.dart';
import '../repositories/entries_repository.dart';
import '../screens/add_entry_sheet.dart';
import '../screens/entries_screen.dart';
import 'wh_entry_grid_card.dart';


class WatchlistTab extends ConsumerStatefulWidget {
  const WatchlistTab({super.key});

  @override
  ConsumerState<WatchlistTab> createState() => _WatchlistTabState();
}

class _WatchlistTabState extends ConsumerState<WatchlistTab> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWatchlist();
  }

  Future<void> _fetchWatchlist() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(watchlistRepositoryProvider);
      final data = await repo.getWatchlist();
      if (mounted) {
        setState(() {
          _items = (data['items'] as List<dynamic>?) ?? [];
          _isLoading = false;
        });
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

  Future<void> _removeItem(String itemId, String title) async {
    final confirm = await WHAlert.confirm(
      context,
      title: 'Remove from Watchlist',
      message: 'Are you sure you want to remove "$title" from your watchlist?',
      confirmText: 'Remove',
      severity: WHAlertSeverity.danger,
      icon: Icons.bookmark_remove_rounded,
    );

    if (!confirm) return;

    try {
      await ref.read(watchlistRepositoryProvider).removeFromWatchlist(itemId);
      setState(() {
        _items.removeWhere((item) => item['id'] == itemId);
      });
      if (mounted) {
        WHAlert.showSuccess(context, 'Removed "$title" from Watchlist');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to remove item: $e');
      }
    }
  }

  void _logWatchlistItem(Map<String, dynamic> item) {
    final itemId = item['id'] as String?;
    final tmdbId = (item['tmdbId'] as num?)?.toInt();
    final mediaType = item['mediaType'] == 'tv' ? 'TV_SHOW' : 'MOVIE';
    final suggestedByUser = item['suggestedByUser'] as Map<String, dynamic>?;
    final suggestedByUserId = item['suggestedByUserId'] as String? ?? suggestedByUser?['id'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEntrySheet(
        prefillTmdbId: tmdbId,
        prefillType: mediaType,
        prefillSuggestedByUserId: suggestedByUserId,
        onSuccess: () {
          if (itemId != null) {
            final title = item['title'] as String? ?? 'this title';
            ref.read(watchlistRepositoryProvider).removeFromWatchlist(itemId);
            setState(() {
              _items.removeWhere((item) => item['id'] == itemId);
            });
            WHAlert.showSuccess(context, 'Logged and removed "$title" from Watchlist! ✨');
          }
        },
      ),
    );
  }

  Future<void> _addToCurrentlyWatching(Map<String, dynamic> item) async {
    final title = item['title'] as String? ?? 'this title';
    final confirm = await WHAlert.confirm(
      context,
      title: 'Move to Currently Watching',
      message: 'Would you like to move "$title" to your Currently Watching log?',
      confirmText: 'Move to Watching',
      severity: WHAlertSeverity.primary,
      icon: Icons.play_circle_outline_rounded,
    );

    if (!confirm) return;

    try {
      final tmdbId = (item['tmdbId'] as num?)?.toInt() ?? 0;
      final mediaType = item['mediaType'] == 'tv' ? 'TV_SHOW' : 'MOVIE';
      final itemId = item['id'] as String?;
      final suggestedByUser = item['suggestedByUser'] as Map<String, dynamic>?;
      final suggestedByUserId = item['suggestedByUserId'] as String? ?? suggestedByUser?['id'] as String?;

      final entry = await ref.read(entriesRepositoryProvider).createEntry({
        'tmdbId': tmdbId,
        'title': title,
        'type': mediaType,
        'isWatching': true,
        'startedAt': DateTime.now().toIso8601String(),
        if (suggestedByUserId != null) 'suggestedByUserId': suggestedByUserId,
      });

      ref.read(entriesProvider(true).notifier).addEntry(entry);

      if (itemId != null) {
        await ref.read(watchlistRepositoryProvider).removeFromWatchlist(itemId);
        setState(() {
          _items.removeWhere((it) => it['id'] == itemId);
        });
      }

      if (mounted) {
        WHAlert.showSuccess(context, 'Moved "$title" to Currently Watching! 🎬');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to add to currently watching: $e');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text('Failed to load Watchlist: $_error', style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchWatchlist,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'Your Watchlist is empty',
              style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            SizedBox(height: 6),
            Text(
              'Save movies & shows you want to watch later.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchWatchlist,
      color: AppColors.primary,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.63,
        ),
        itemCount: _items.length,
        itemBuilder: (ctx, i) {
          final item = _items[i] as Map<String, dynamic>;
          final itemId = item['id'] as String;
          final tmdbId = (item['tmdbId'] as num?)?.toInt() ?? 0;
          final title = item['title'] as String? ?? 'Untitled';
          final posterPath = item['posterPath'] as String?;
          final mediaType = item['mediaType'] == 'tv' ? 'tv' : 'movie';
          final suggestedByUser = item['suggestedByUser'] as Map<String, dynamic>?;
          final suggestorUsername = suggestedByUser?['username'] as String? ?? item['suggestedByUsername'] as String?;

          return WHEntryGridCard(
            tmdbId: tmdbId,
            title: title,
            initialPosterPath: posterPath,
            mediaType: mediaType,
            mode: WHEntryCardMode.watchlist,
            suggestedByUsername: suggestorUsername,
            onTap: () {
              if (tmdbId > 0) context.push('/details/$mediaType/$tmdbId');
            },
            onMoveToWatching: () => _addToCurrentlyWatching(item),
            onMarkWatched: () => _logWatchlistItem(item),
            onDelete: () => _removeItem(itemId, title),
          );

        },
      ),
    );
  }
}
