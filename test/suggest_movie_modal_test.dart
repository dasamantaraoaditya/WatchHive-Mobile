import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/auth/auth_manager.dart';
import 'package:watchhive_mobile/features/entries/repositories/suggestions_repository.dart';
import 'package:watchhive_mobile/features/entries/widgets/suggest_movie_modal.dart';
import 'package:watchhive_mobile/features/profile/repositories/user_repository.dart';
import 'package:watchhive_mobile/features/search/repositories/search_repository.dart';
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
  Future<List<User>> getFollowers(String userId, {int limit = 100, String? query}) async {
    getFollowersCalled = true;
    return [
      User(
        id: 'follower-only',
        username: 'follower_user',
        displayName: 'Follower Only',
        profilePictureUrl: null,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<List<User>> getFollowing(String userId, {int limit = 100, String? query}) async {
    getFollowingCalled = true;
    return [
      User(
        id: 'following-1',
        username: 'cinephile_jane',
        displayName: 'Jane Cinephile',
        profilePictureUrl: null,
        createdAt: DateTime(2026, 1, 1),
      ),
      User(
        id: 'following-2',
        username: 'movie_buff_sam',
        displayName: 'Sam Buff',
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
  testWidgets('SuggestMovieModal displays ONLY followed users and never loads strangers or non-followed users', (tester) async {
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

    // 1. Verify following was fetched, but NOT getFollowers or getSuggestedUsers
    expect(fakeUserRepo.getFollowingCalled, isTrue);
    expect(fakeUserRepo.getFollowersCalled, isFalse);
    expect(fakeSearchRepo.getSuggestedUsersCalled, isFalse);

    // 2. Verify followed users are visible
    expect(find.text('Jane Cinephile'), findsOneWidget);
    expect(find.text('@cinephile_jane'), findsOneWidget);
    expect(find.text('Sam Buff'), findsOneWidget);
    expect(find.text('@movie_buff_sam'), findsOneWidget);

    // 3. Verify non-followed users and strangers are NEVER shown
    expect(find.text('Follower Only'), findsNothing);
    expect(find.text('Random Stranger'), findsNothing);

    // 4. Test in-memory followed user search filtering (including @ prefix)
    final searchInput = find.byType(TextField).first;
    await tester.enterText(searchInput, '@cinephile_jane');
    await tester.pumpAndSettle();

    // Search should filter locally without calling searchUsers API
    expect(fakeSearchRepo.searchUsersCalled, isFalse);
    expect(find.text('Jane Cinephile'), findsOneWidget);
    expect(find.text('Sam Buff'), findsNothing);

    // 5. Test clear button resets the search
    final clearBtn = find.byIcon(Icons.close_rounded).last;
    await tester.tap(clearBtn);
    await tester.pumpAndSettle();
    expect(find.text('Jane Cinephile'), findsOneWidget);
    expect(find.text('Sam Buff'), findsOneWidget);

    // 6. Select followed user and verify send
    await tester.tap(find.text('Jane Cinephile'));
    await tester.pumpAndSettle();

    final sendButton = find.widgetWithText(ElevatedButton, 'Send Suggestion (1)');
    expect(sendButton, findsOneWidget);
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    expect(fakeSuggestionsRepo.sentToUserIds, ['following-1']);
  });
}
