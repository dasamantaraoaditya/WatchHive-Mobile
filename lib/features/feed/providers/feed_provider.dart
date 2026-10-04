import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/models/entry.dart';
import '../repositories/feed_repository.dart';

/// State representation for the home feed.
class FeedState {
  final List<Entry> entries;
  final List<Entry>? pendingEntries;
  final int newPostsCount;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final Set<String> likedEntryIds;
  final DateTime? lastFetchedAt;
  final bool isStale;
  final bool isNearTop;

  const FeedState({
    this.entries = const [],
    this.pendingEntries,
    this.newPostsCount = 0,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.likedEntryIds = const {},
    this.lastFetchedAt,
    this.isStale = false,
    this.isNearTop = true,
  });

  FeedState copyWith({
    List<Entry>? entries,
    List<Entry>? pendingEntries,
    bool clearPendingEntries = false,
    int? newPostsCount,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
    Set<String>? likedEntryIds,
    DateTime? lastFetchedAt,
    bool? isStale,
    bool? isNearTop,
  }) =>
      FeedState(
        entries: entries ?? this.entries,
        pendingEntries: clearPendingEntries ? null : (pendingEntries ?? this.pendingEntries),
        newPostsCount: newPostsCount ?? this.newPostsCount,
        isLoading: isLoading ?? this.isLoading,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
        likedEntryIds: likedEntryIds ?? this.likedEntryIds,
        lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
        isStale: isStale ?? this.isStale,
        isNearTop: isNearTop ?? this.isNearTop,
      );
}

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier(ref.read(feedRepositoryProvider));
});

/// Reactive trigger to scroll to top and refresh feed (e.g. tapping Home bottom-nav item).
final feedRefreshTriggerProvider = StateProvider<int>((ref) => 0);

class FeedNotifier extends StateNotifier<FeedState> {
  final FeedRepository _repo;
  static const _pageSize = 20;

  FeedNotifier(this._repo) : super(const FeedState()) {
    loadFeed();
  }

  void setNearTop(bool isNearTop) {
    if (state.isNearTop == isNearTop) return;
    if (isNearTop && state.pendingEntries != null) {
      applyPendingEntries();
    } else {
      state = state.copyWith(isNearTop: isNearTop);
    }
  }

  void applyPendingEntries() {
    if (state.pendingEntries == null) return;
    final incoming = state.pendingEntries!;
    final initialLiked = incoming.where((e) => e.isLiked).map((e) => e.id).toSet();
    state = state.copyWith(
      entries: incoming,
      clearPendingEntries: true,
      newPostsCount: 0,
      likedEntryIds: {...state.likedEntryIds, ...initialLiked},
      isNearTop: true,
    );
  }

  /// Called whenever a user arrives on the feed tab (via tab switch, back navigation, or app resume).
  void onArrivedAtFeed() {
    final now = DateTime.now();
    final lastFetch = state.lastFetchedAt;
    final isStale = state.isStale;

    // Refresh automatically if never fetched, marked stale, or fetched > 30 seconds ago
    if (lastFetch == null || isStale || now.difference(lastFetch) > const Duration(seconds: 30)) {
      loadFeed(isSilent: state.entries.isNotEmpty);
    }
  }

  void markStale() {
    state = state.copyWith(isStale: true);
  }

  /// Instantly prepends a freshly created entry at index 0 of the feed.
  void prependEntry(Entry entry) {
    if (state.entries.any((e) => e.id == entry.id)) {
      updateEntry(entry);
      return;
    }
    final updatedEntries = [entry, ...state.entries];
    final updatedLiked = Set<String>.from(state.likedEntryIds);
    if (entry.isLiked) updatedLiked.add(entry.id);

    state = state.copyWith(
      entries: updatedEntries,
      likedEntryIds: updatedLiked,
      isStale: true,
    );
  }

  void removeEntry(String id) {
    state = state.copyWith(
      entries: state.entries.where((e) => e.id != id).toList(),
      pendingEntries: state.pendingEntries?.where((e) => e.id != id).toList(),
    );
  }

  void updateEntry(Entry updated) {
    final targetIndex = state.entries.indexWhere((e) => e.id == updated.id);
    if (targetIndex != -1) {
      final updatedEntries = [...state.entries];
      updatedEntries[targetIndex] = updated;
      state = state.copyWith(entries: updatedEntries);
    }
  }

  Future<void> loadFeed({bool isRefresh = false, bool isSilent = false}) async {
    // Avoid concurrent duplicate requests
    if (state.isLoading || state.isRefreshing) return;

    if (state.entries.isEmpty) {
      state = state.copyWith(isLoading: true, clearError: true);
    } else if (isRefresh) {
      state = state.copyWith(isRefreshing: true, clearError: true);
    }

    try {
      final result = await _repo.getFeed(limit: _pageSize, offset: 0);
      final incoming = result.entries;
      final initialLiked = incoming.where((e) => e.isLiked).map((e) => e.id).toSet();

      // If silent refresh and user is scrolled down into feed, don't disorient them:
      // Show floating "New updates" pill instead of abrupt scroll jump
      if (isSilent && state.entries.isNotEmpty && !state.isNearTop) {
        final existingIds = state.entries.map((e) => e.id).toSet();
        final newItems = incoming.where((e) => !existingIds.contains(e.id)).toList();
        if (newItems.isNotEmpty) {
          state = state.copyWith(
            pendingEntries: incoming,
            newPostsCount: newItems.length,
            isLoading: false,
            isRefreshing: false,
            hasMore: result.pagination.hasMore,
            lastFetchedAt: DateTime.now(),
            isStale: false,
          );
          return;
        }
      }

      state = state.copyWith(
        entries: incoming,
        clearPendingEntries: true,
        newPostsCount: 0,
        likedEntryIds: {...state.likedEntryIds, ...initialLiked},
        isLoading: false,
        isRefreshing: false,
        hasMore: result.pagination.hasMore,
        lastFetchedAt: DateTime.now(),
        isStale: false,
        clearError: true,
      );
    } catch (e, stackTrace) {
      debugPrint('Feed load error: $e');
      debugPrint('Feed stack trace: $stackTrace');
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: state.entries.isEmpty ? AppErrorHandler.toUserFriendlyMessage(e) : null,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.getFeed(limit: _pageSize, offset: state.entries.length);
      final moreLiked = result.entries.where((e) => e.isLiked).map((e) => e.id);
      state = state.copyWith(
        entries: [...state.entries, ...result.entries],
        likedEntryIds: {...state.likedEntryIds, ...moreLiked},
        isLoadingMore: false,
        hasMore: result.pagination.hasMore,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> toggleLike(String entryId) async {
    final targetIndex = state.entries.indexWhere((e) => e.id == entryId);
    if (targetIndex == -1) return;

    final targetEntry = state.entries[targetIndex];
    final wasLiked = state.likedEntryIds.contains(entryId) || targetEntry.isLiked;
    final newIsLiked = !wasLiked;
    final newLikesCount = newIsLiked
        ? targetEntry.likesCount + (targetEntry.isLiked ? 0 : 1)
        : (targetEntry.likesCount > 0 ? targetEntry.likesCount - (targetEntry.isLiked ? 1 : 0) : 0);

    final updatedEntries = [...state.entries];
    updatedEntries[targetIndex] = targetEntry.copyWith(
      isLiked: newIsLiked,
      likesCount: newLikesCount,
    );

    final newLiked = Set<String>.from(state.likedEntryIds);
    if (newIsLiked) {
      newLiked.add(entryId);
    } else {
      newLiked.remove(entryId);
    }

    state = state.copyWith(entries: updatedEntries, likedEntryIds: newLiked);

    try {
      if (wasLiked) {
        await _repo.unlikeEntry(entryId);
      } else {
        await _repo.likeEntry(entryId);
      }
    } catch (_) {
      // Revert on failure
      final revertedEntries = [...state.entries];
      revertedEntries[targetIndex] = targetEntry;
      state = state.copyWith(
        entries: revertedEntries,
        likedEntryIds: Set<String>.from(state.likedEntryIds)..toggle(entryId),
      );
    }
  }

  void updateCommentsCount(String entryId, int newCount) {
    final targetIndex = state.entries.indexWhere((e) => e.id == entryId);
    if (targetIndex != -1) {
      final updatedEntries = [...state.entries];
      updatedEntries[targetIndex] = updatedEntries[targetIndex].copyWith(
        commentsCount: newCount,
        isCommented: newCount > 0,
      );
      state = state.copyWith(entries: updatedEntries);
    }
  }
}

extension on Set<String> {
  void toggle(String value) {
    if (contains(value)) {
      remove(value);
    } else {
      add(value);
    }
  }
}
