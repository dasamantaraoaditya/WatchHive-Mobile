import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/auth/auth_manager.dart';
import 'package:watchhive_mobile/features/rankings/models/ranking_stack.dart';
import 'package:watchhive_mobile/features/rankings/repositories/rankings_repository.dart';
import 'package:watchhive_mobile/features/rankings/screens/rankings_screen.dart';

class _FakeAuthManager extends AuthManager {}

class _MockRankingsRepository extends RankingsRepository {
  final List<RankingStack> dummyStacks;

  _MockRankingsRepository(this.dummyStacks) : super(ApiClient(_FakeAuthManager()));

  @override
  Future<List<RankingStack>> getMyRankingStacks([String? userId]) async {
    return dummyStacks;
  }

  @override
  Future<({RankingStack stack, List<RankedItem> items})> getRankedStack(
    String listId, {
    String? genre,
  }) async {
    final stack = dummyStacks.firstWhere(
      (s) => s.id == listId,
      orElse: () => dummyStacks.first,
    );
    return (stack: stack, items: stack.items);
  }
}

void main() {
  const stack1 = RankingStack(
    id: 'stack-1',
    userId: 'user-1',
    name: 'Top Sci-Fi',
    description: 'Best Sci-Fi Movies',
    isPublic: true,
    items: [
      RankedItem(
        id: 'item-1',
        listId: 'stack-1',
        tmdbId: 157336,
        mediaType: 'movie',
        orderIndex: 0,
        title: 'Interstellar',
      ),
    ],
  );

  const stack2 = RankingStack(
    id: 'stack-2',
    userId: 'user-1',
    name: 'Best Anime Stacks',
    description: 'All time greatest anime',
    isPublic: false,
    items: [
      RankedItem(
        id: 'item-2',
        listId: 'stack-2',
        tmdbId: 99999,
        mediaType: 'tv',
        orderIndex: 0,
        title: 'Attack on Titan',
      ),
    ],
  );

  testWidgets('RankingsScreen selects specified initialStackId instead of default stack', (tester) async {
    final fakeRepo = _MockRankingsRepository([stack1, stack2]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankingsRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: RankingsScreen(
              initialStackId: 'stack-2',
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Stack 2 should be displayed in the hero card
    expect(find.text('Best Anime Stacks'), findsWidgets);
    expect(find.text('All time greatest anime'), findsOneWidget);
  });

  testWidgets('RankingsScreen with autoOpenEdit opens the edit modal with target stack', (tester) async {
    final fakeRepo = _MockRankingsRepository([stack1, stack2]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankingsRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: RankingsScreen(
              initialStackId: 'stack-2',
              autoOpenEdit: true,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    // Edit modal should be opened with title "Edit Ranking Stack" and name "Best Anime Stacks"
    expect(find.text('Edit Ranking Stack'), findsOneWidget);
    final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(textFields.first.controller?.text, 'Best Anime Stacks');
    expect(textFields[1].controller?.text, 'All time greatest anime');
  });
}
