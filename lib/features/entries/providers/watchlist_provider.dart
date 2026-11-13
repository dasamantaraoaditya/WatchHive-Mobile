import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/watchlist_repository.dart';

class WatchlistState {
  final String? watchlistId;
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final String? error;

  const WatchlistState({
    this.watchlistId,
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  WatchlistState copyWith({
    String? watchlistId,
    List<Map<String, dynamic>>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      WatchlistState(
        watchlistId: watchlistId ?? this.watchlistId,
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class WatchlistNotifier extends StateNotifier<WatchlistState> {
  final WatchlistRepository _repo;

  WatchlistNotifier(this._repo) : super(const WatchlistState(isLoading: true)) {
    loadWatchlist();
  }

  Future<void> loadWatchlist() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _repo.getWatchlist();
      final rawItems = (data['items'] as List<dynamic>?) ?? [];
      final parsed = rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      state = state.copyWith(
        watchlistId: data['id'] as String?,
        items: parsed,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    try {
      final data = await _repo.getWatchlist();
      final rawItems = (data['items'] as List<dynamic>?) ?? [];
      final parsed = rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // Preserve any pending optimistic additions not yet indexed
      final fetchedIds = parsed
          .map((it) => (it['tmdbId'] as num?)?.toInt() ?? it['id']?.toString())
          .toSet();

      final pending = state.items.where((it) {
        final id = (it['tmdbId'] as num?)?.toInt() ?? it['id']?.toString();
        return id != null && !fetchedIds.contains(id);
      }).toList();

      state = state.copyWith(
        watchlistId: data['id'] as String?,
        items: [...pending, ...parsed],
        isLoading: false,
        clearError: true,
      );
    } catch (_) {}
  }

  void addItem(Map<String, dynamic> item) {
    final tmdbId = (item['tmdbId'] as num?)?.toInt();
    final itemId = item['id']?.toString();

    final filtered = state.items.where((it) {
      final itTmdb = (it['tmdbId'] as num?)?.toInt();
      final itId = it['id']?.toString();
      if (tmdbId != null && itTmdb == tmdbId) return false;
      if (itemId != null && itId == itemId) return false;
      return true;
    }).toList();

    state = state.copyWith(
      items: [item, ...filtered],
      clearError: true,
    );
  }

  void removeItem(dynamic target) {
    final int? tmdbId = target is int ? target : int.tryParse(target?.toString() ?? '');
    final String? itemId = target is String ? target : target?.toString();

    state = state.copyWith(
      items: state.items.where((it) {
        final itTmdb = (it['tmdbId'] as num?)?.toInt() ?? int.tryParse(it['tmdbId']?.toString() ?? '');
        final itId = it['id']?.toString();
        if (tmdbId != null && itTmdb == tmdbId) return false;
        if (itemId != null && itId == itemId) return false;
        return true;
      }).toList(),
    );
  }

  Future<void> addToWatchlist({
    required int tmdbId,
    required String title,
    required String mediaType,
    String? posterPath,
    String? overview,
    String? suggestedByUserId,
  }) async {
    // Optimistic add
    addItem({
      'tmdbId': tmdbId,
      'title': title,
      'mediaType': mediaType,
      'posterPath': posterPath,
      'overview': overview,
      'suggestedByUserId': suggestedByUserId,
      'addedAt': DateTime.now().toUtc().toIso8601String(),
    });

    try {
      await _repo.addToWatchlist(
        tmdbId: tmdbId,
        title: title,
        mediaType: mediaType,
        posterPath: posterPath,
        overview: overview,
        suggestedByUserId: suggestedByUserId,
      );
      await refresh();
    } catch (e) {
      // Revert if failed
      removeItem(tmdbId);
      rethrow;
    }
  }

  Future<void> removeFromWatchlist(dynamic target, {String? listId}) async {
    // Optimistic remove
    removeItem(target);

    try {
      await _repo.removeFromWatchlist(target, listId: listId ?? state.watchlistId);
      await refresh();
    } catch (_) {}
  }
}

final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, WatchlistState>((ref) {
  return WatchlistNotifier(ref.read(watchlistRepositoryProvider));
});

final reactiveIsInWatchlistProvider = Provider.family<bool, int>((ref, tmdbId) {
  final items = ref.watch(watchlistProvider).items;
  return items.any((item) {
    final id = item['tmdbId'];
    final parsed = (id as num?)?.toInt() ?? int.tryParse(id?.toString() ?? '');
    return parsed == tmdbId;
  });
});
