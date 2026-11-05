import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/auth/auth_manager.dart';
import 'package:watchhive_mobile/features/rankings/models/ranking_stack.dart';
import 'package:watchhive_mobile/features/rankings/repositories/rankings_repository.dart';
import 'package:watchhive_mobile/features/rankings/widgets/add_to_stack_sheet.dart';

class _FakeAuthManager extends AuthManager {}

class _FakeRankingsRepository extends RankingsRepository {
  List<RankingStack> stacks;
  bool createCalled = false;
  bool addItemCalled = false;
  String? lastCreatedName;

  _FakeRankingsRepository({this.stacks = const []}) : super(ApiClient(_FakeAuthManager()));

  @override
  Future<List<RankingStack>> getMyRankingStacks([String? userId]) async {
    return stacks;
  }

  @override
  Future<RankingStack> createRankingStack({
    required String name,
    String? description,
    bool isPublic = true,
  }) async {
    createCalled = true;
    lastCreatedName = name;
    final newStack = RankingStack(
      id: 'stack-new-1',
      userId: 'user-1',
      name: name,
      description: description,
      isPublic: isPublic,
      items: const [],
    );
    stacks = [newStack, ...stacks];
    return newStack;
  }

  @override
  Future<RankedItem> addItemToStack({
    required String listId,
    required int tmdbId,
    String mediaType = 'movie',
    String? suggestedByUserId,
  }) async {
    addItemCalled = true;
    return RankedItem(
      id: 'item-1',
      listId: listId,
      tmdbId: tmdbId,
      mediaType: mediaType,
      orderIndex: 0,
      title: 'Interstellar',
    );
  }
}

void main() {
  testWidgets('AddToStackSheet shows Add Stack button when stacks are empty', (tester) async {
    final fakeRepo = _FakeRankingsRepository(stacks: []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankingsRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AddToStackSheet(
              tmdbId: 157336,
              title: 'Interstellar',
              mediaType: 'movie',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and Media Banner
    expect(find.text('Add to Stack'), findsOneWidget);
    expect(find.text('Interstellar'), findsOneWidget);

    // Verify Empty State is shown
    expect(find.text('No Ranking Stacks Yet'), findsOneWidget);
    expect(find.text('Create a ranking stack to rank and organize your favorite titles.'), findsOneWidget);

    // Verify Add Stack button exists for empty stacks scenario
    final addStackButton = find.byKey(const Key('add_stack_button_empty'));
    expect(addStackButton, findsOneWidget);
    expect(find.text('Add Stack'), findsWidgets);
  });

  testWidgets('Tapping Add Stack reveals inline create form and creates/adds to stack', (tester) async {
    final fakeRepo = _FakeRankingsRepository(stacks: []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankingsRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AddToStackSheet(
              tmdbId: 157336,
              title: 'Interstellar',
              mediaType: 'movie',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Add Stack button
    await tester.tap(find.byKey(const Key('add_stack_button_empty')));
    await tester.pumpAndSettle();

    // Verify create form is revealed
    expect(find.text('Create New Stack'), findsOneWidget);
    expect(find.text('Stack Name'), findsOneWidget);
    expect(find.text('Public Visibility'), findsOneWidget);

    final createAndAddButton = find.byKey(const Key('create_and_add_stack_button'));
    expect(createAndAddButton, findsOneWidget);

    // Enter stack name
    await tester.enterText(find.byType(TextField).first, 'Christopher Nolan Masterpieces');
    await tester.pumpAndSettle();

    // Tap Create & Add to Stack
    await tester.tap(createAndAddButton);
    await tester.pumpAndSettle();

    // Verify repository calls
    expect(fakeRepo.createCalled, isTrue);
    expect(fakeRepo.lastCreatedName, 'Christopher Nolan Masterpieces');
    expect(fakeRepo.addItemCalled, isTrue);
  });

  testWidgets('AddToStackSheet shows existing stacks and header Add Stack button', (tester) async {
    const existingStack = RankingStack(
      id: 'stack-1',
      userId: 'user-1',
      name: 'Favorite Sci-Fi',
      isPublic: true,
      items: [],
    );
    final fakeRepo = _FakeRankingsRepository(stacks: [existingStack]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankingsRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AddToStackSheet(
              tmdbId: 157336,
              title: 'Interstellar',
              mediaType: 'movie',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify existing stack is shown in list
    expect(find.text('Favorite Sci-Fi'), findsOneWidget);

    // Verify header Add Stack button is also available
    final headerAddButton = find.byKey(const Key('add_stack_button_header'));
    expect(headerAddButton, findsOneWidget);

    // Tap header Add Stack button
    await tester.tap(headerAddButton);
    await tester.pumpAndSettle();

    // Verify form opens
    expect(find.text('Create New Stack'), findsOneWidget);
  });
}
