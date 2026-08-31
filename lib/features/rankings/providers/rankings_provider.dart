import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/ranking_stack.dart';
import '../repositories/rankings_repository.dart';

// State model for My Ranking Stacks list
class MyRankingsState {
  final List<RankingStack> stacks;
  final bool isLoading;
  final String? error;

  const MyRankingsState({
    this.stacks = const [],
    this.isLoading = false,
    this.error,
  });

  MyRankingsState copyWith({
    List<RankingStack>? stacks,
    bool? isLoading,
    String? error,
  }) =>
      MyRankingsState(
        stacks: stacks ?? this.stacks,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class MyRankingsNotifier extends StateNotifier<MyRankingsState> {
  final RankingsRepository _repo;
  final String? _userId;

  MyRankingsNotifier(this._repo, [this._userId]) : super(const MyRankingsState(isLoading: true)) {
    loadStacks();
  }

  Future<void> loadStacks() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final stacks = await _repo.getMyRankingStacks(_userId);
      state = state.copyWith(stacks: stacks, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<RankingStack?> createStack({
    required String name,
    String? description,
    bool isPublic = true,
  }) async {
    try {
      final newStack = await _repo.createRankingStack(
        name: name,
        description: description,
        isPublic: isPublic,
      );
      state = state.copyWith(stacks: [newStack, ...state.stacks]);
      return newStack;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> updateStack(
    String listId, {
    String? name,
    String? description,
    bool? isPublic,
  }) async {
    try {
      final updated = await _repo.updateRankingStack(
        listId,
        name: name,
        description: description,
        isPublic: isPublic,
      );
      state = state.copyWith(
        stacks: state.stacks.map((s) => s.id == listId ? updated : s).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteStack(String listId) async {
    try {
      await _repo.deleteRankingStack(listId);
      state = state.copyWith(
        stacks: state.stacks.where((s) => s.id != listId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final myRankingsProvider = StateNotifierProvider<MyRankingsNotifier, MyRankingsState>((ref) {
  final userId = ref.watch(authStateProvider).value?.user?.id;
  return MyRankingsNotifier(ref.read(rankingsRepositoryProvider), userId);
});

// State for an Active Stack & its Items
class ActiveStackState {
  final RankingStack? stack;
  final List<RankedItem> items;
  final bool isLoading;
  final String? error;

  const ActiveStackState({
    this.stack,
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  ActiveStackState copyWith({
    RankingStack? stack,
    List<RankedItem>? items,
    bool? isLoading,
    String? error,
  }) =>
      ActiveStackState(
        stack: stack ?? this.stack,
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class ActiveStackNotifier extends StateNotifier<ActiveStackState> {
  final RankingsRepository _repo;
  String? _currentListId;

  ActiveStackNotifier(this._repo) : super(const ActiveStackState());

  Future<void> loadStack(String listId, {String? genre}) async {
    _currentListId = listId;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.getRankedStack(listId, genre: genre);
      state = state.copyWith(
        stack: result.stack,
        items: result.items,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> addItem({
    required int tmdbId,
    String mediaType = 'movie',
    String? suggestedByUserId,
  }) async {
    if (_currentListId == null) return;
    try {
      await _repo.addItemToStack(
        listId: _currentListId!,
        tmdbId: tmdbId,
        mediaType: mediaType,
        suggestedByUserId: suggestedByUserId,
      );
      // Reload stack to get full metadata from backend
      await loadStack(_currentListId!);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> removeItem(int tmdbId) async {
    if (_currentListId == null) return;
    // Optimistic removal
    final previousItems = state.items;
    state = state.copyWith(
      items: state.items.where((i) => i.tmdbId != tmdbId).toList(),
    );

    try {
      await _repo.removeItemFromStack(
        listId: _currentListId!,
        tmdbId: tmdbId,
      );
    } catch (e) {
      // Revert on error
      state = state.copyWith(items: previousItems, error: e.toString());
    }
  }

  Future<void> moveItem(int fromIndex, int toIndex) async {
    if (_currentListId == null) return;
    if (fromIndex < 0 || fromIndex >= state.items.length) return;
    if (toIndex < 0 || toIndex >= state.items.length) return;
    if (fromIndex == toIndex) return;

    final updated = List<RankedItem>.from(state.items);
    final movedItem = updated.removeAt(fromIndex);
    updated.insert(toIndex, movedItem);

    // Optimistic UI update
    state = state.copyWith(items: updated);

    try {
      final reorderData = updated.asMap().entries.map((entry) {
        return (tmdbId: entry.value.tmdbId, orderIndex: entry.key);
      }).toList();

      await _repo.reorderStack(
        listId: _currentListId!,
        items: reorderData,
      );
    } catch (e) {
      // Reload on failure
      loadStack(_currentListId!);
    }
  }
}

final activeStackProvider = StateNotifierProvider<ActiveStackNotifier, ActiveStackState>((ref) {
  return ActiveStackNotifier(ref.read(rankingsRepositoryProvider));
});

// Family Provider for Other User's Rankings
final userRankingsFamily = FutureProvider.family<List<RankingStack>, String>((ref, userId) async {
  final repo = ref.read(rankingsRepositoryProvider);
  return await repo.getUserRankings(userId);
});
