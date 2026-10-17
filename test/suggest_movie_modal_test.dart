import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/auth/auth_manager.dart';
import 'package:watchhive_mobile/features/entries/repositories/suggestions_repository.dart';
import 'package:watchhive_mobile/features/entries/widgets/suggest_movie_modal.dart';
import 'package:watchhive_mobile/features/profile/repositories/user_repository.dart';
import 'package:watchhive_mobile/features/search/repositories/search_repository.dart';
import 'package:watchhive_mobile/shared/models/models.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

class _FakeAuthManager extends AuthManager {}

class _FakeUserRepository extends UserRepository {
  bool getFollowersCalled = false;
  bool getFollowingCalled = false;

  _FakeUserRepository() : super(ApiClient(_FakeAuthManager()));

  @override
  Future<User> getCurrentUser() async {
    return User(
      id: 'current-user-id',
      username: 'aditya',
      displayName: 'Aditya D',
      profilePictureUrl: null,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<List<User>> getFollowers(String userId) async {
    getFollowersCalled = true;
    return [
      User(
        id: 'follower-1',
        username: 'cinephile_jane',
        displayName: 'Jane Cinephile',
        profilePictureUrl: null,
        createdAt: DateTime(2026, 1, 1),
      ),
      User(
        id: 'follower-2',
        username: 'movie_buff_sam',
        displayName: 'Sam Buff',
        profilePictureUrl: null,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<List<User>> getFollowing(String userId) async {
    getFollowingCalled = true;
    return [
      User(
        id: 'following-stranger',
        username: 'stranger_user',
        displayName: 'Stranger User',
        profilePictureUrl: null,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }
}

class _FakeSearchRepository extends SearchRepository {
  bool getSuggestedUsersCalled = false;
  bool searchUsersCalled = false;

  _FakeSearchRepository() : super(ApiClient(_FakeAuthManager()));

  @override
  Future<List<User>> getSuggestedUsers() async {
    getSuggestedUsersCalled = true;
    return [
      User(
        id: 'random-stranger-id',
        username: 'random_stranger',
        displayName: 'Random Stranger',
        profilePictureUrl: null,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<List<User>> searchUsers(String query) async {
    searchUsersCalled = true;
    return [
      User(
        id: 'random-stranger-id',
        username: 'random_stranger',
        displayName: 'Random Stranger',
        profilePictureUrl: null,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }
}

class _FakeSuggestionsRepository extends SuggestionsRepository {
  List<String> sentToUserIds = [];

  _FakeSuggestionsRepository() : super(ApiClient(_FakeAuthManager()));

  @override
  Future<void> sendSuggestion({
    String? toUserId,
    List<String>? toUserIds,
    required int tmdbId,
    required String title,
    String? mediaType,
    String? message,
  }) async {
    sentToUserIds = toUserIds ?? (toUserId != null ? [toUserId] : []);
  }
}

void main() {
  testWidgets('SuggestMovieModal displays ONLY followers and never loads strangers/suggested users', (tester) async {
    final fakeUserRepo = _FakeUserRepository();
    final fakeSearchRepo = _FakeSearchRepository();
    final fakeSuggestionsRepo = _FakeSuggestionsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(fakeUserRepo),
          searchRepositoryProvider.overrideWithValue(fakeSearchRepo),
          suggestionsRepositoryProvider.overrideWithValue(fakeSuggestionsRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SuggestMovieModal(
              tmdbId: 550,
              title: 'Fight Club',
              mediaType: 'movie',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify followers were fetched, but NOT getSuggestedUsers or getFollowing
    expect(fakeUserRepo.getFollowersCalled, isTrue);
    expect(fakeUserRepo.getFollowingCalled, isFalse);
    expect(fakeSearchRepo.getSuggestedUsersCalled, isFalse);

    // 2. Verify followers are visible
    expect(find.text('Jane Cinephile'), findsOneWidget);
    expect(find.text('@cinephile_jane'), findsOneWidget);
    expect(find.text('Sam Buff'), findsOneWidget);
    expect(find.text('@movie_buff_sam'), findsOneWidget);

    // 3. Verify strangers are NEVER shown
    expect(find.text('Random Stranger'), findsNothing);
    expect(find.text('Stranger User'), findsNothing);

    // 4. Test in-memory follower search filtering
    final searchInput = find.byType(TextField).first;
    await tester.enterText(searchInput, 'jane');
    await tester.pumpAndSettle();

    // Search should filter locally without calling searchUsers API
    expect(fakeSearchRepo.searchUsersCalled, isFalse);
    expect(find.text('Jane Cinephile'), findsOneWidget);
    expect(find.text('Sam Buff'), findsNothing);

    // 5. Select follower and verify send
    await tester.tap(find.text('Jane Cinephile'));
    await tester.pumpAndSettle();

    final sendButton = find.widgetWithText(ElevatedButton, 'Send Suggestion (1)');
    expect(sendButton, findsOneWidget);
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    expect(fakeSuggestionsRepo.sentToUserIds, ['follower-1']);
  });
}
