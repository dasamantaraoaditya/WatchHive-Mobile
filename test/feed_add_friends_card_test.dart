import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:watchhive_mobile/features/auth/providers/auth_provider.dart';
import 'package:watchhive_mobile/features/feed/repositories/feed_repository.dart';
import 'package:watchhive_mobile/features/feed/screens/feed_screen.dart';
import 'package:watchhive_mobile/features/feed/widgets/feed_add_friends_card.dart';
import 'package:watchhive_mobile/features/onboarding/services/tour_service.dart';
import 'package:watchhive_mobile/features/profile/repositories/user_repository.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/models.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

class _FakeFeedRepo implements FeedRepository {
  List<Entry> currentEntries = [];

  _FakeFeedRepo(this.currentEntries);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<({List<Entry> entries, Pagination pagination})> getFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    return (
      entries: currentEntries,
      pagination: Pagination(
        total: currentEntries.length,
        limit: limit,
        offset: offset,
        hasMore: false,
      ),
    );
  }
}

class _FakeTourService implements TourService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<bool> shouldShowTour(String userId) async => false;
}

class _FakeUserRepo implements UserRepository {
  final int followingCount;
  _FakeUserRepo({this.followingCount = 0});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<({int followersCount, int followingCount})> getFollowStats(String userId) async {
    return (followersCount: 0, followingCount: followingCount);
  }
}

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  _MockAuthNotifier(this._initialState);

  @override
  Future<AuthState> build() async => _initialState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final userWithNoFriends = User(
    id: 'user_zero_friends',
    username: 'lonewolf',
    displayName: 'Lone Wolf',
    email: 'lone@test.com',
    followingCount: 0,
    createdAt: DateTime(2025, 1, 1),
  );

  final userWithFriends = User(
    id: 'user_has_friends',
    username: 'socialbee',
    displayName: 'Social Bee',
    email: 'bee@test.com',
    followingCount: 5,
    createdAt: DateTime(2025, 1, 1),
  );

  group('FeedAddFriendsCard Widget Tests', () {
    testWidgets('renders title, body message, Add Friends and Cancel buttons', (tester) async {
      bool addFriendsTapped = false;
      bool dismissTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedAddFriendsCard(
              onAddFriends: () => addFriendsTapped = true,
              onDismiss: () => dismissTapped = true,
            ),
          ),
        ),
      );

      // Verify title & messaging
      expect(find.text('Diversify Your Feed & Suggestions'), findsOneWidget);
      expect(find.textContaining('You haven’t added any friends yet!'), findsOneWidget);

      // Verify Add Friends button and tap action
      final addFriendsBtn = find.widgetWithText(ElevatedButton, 'Add Friends');
      expect(addFriendsBtn, findsOneWidget);
      await tester.tap(addFriendsBtn);
      expect(addFriendsTapped, isTrue);

      // Verify top close '✕' button and tap action
      final closeBtn = find.byIcon(Icons.close_rounded);
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      expect(dismissTapped, isTrue);

      // Verify Cancel text button and tap action
      dismissTapped = false;
      final cancelBtn = find.widgetWithText(TextButton, 'Cancel');
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      expect(dismissTapped, isTrue);
    });

    test('isDismissed, setDismissed, and resetDismissed storage tests', () async {
      FlutterSecureStorage.setMockInitialValues({});
      const testUserId = 'test_user_storage_99';

      expect(await FeedAddFriendsCard.isDismissed(testUserId), isFalse);

      await FeedAddFriendsCard.setDismissed(testUserId);
      expect(await FeedAddFriendsCard.isDismissed(testUserId), isTrue);

      await FeedAddFriendsCard.resetDismissed(testUserId);
      expect(await FeedAddFriendsCard.isDismissed(testUserId), isFalse);
    });
  });

  group('FeedScreen Add Friends Integration Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    testWidgets('Shows FeedAddFriendsCard in feed when user has 0 friends, dismisses on Cancel', (tester) async {
      final repo = _FakeFeedRepo([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedRepositoryProvider.overrideWithValue(repo),
            tourServiceProvider.overrideWithValue(_FakeTourService()),
            userRepositoryProvider.overrideWithValue(_FakeUserRepo(followingCount: 0)),
            authStateProvider.overrideWith(
              () => _MockAuthNotifier(
                AuthState(
                  isAuthenticated: true,
                  user: userWithNoFriends,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Should render the Add Friends panel
      expect(find.byType(FeedAddFriendsCard), findsOneWidget);
      expect(find.text('Diversify Your Feed & Suggestions'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Add Friends'), findsOneWidget);

      // Tap Cancel button
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      // Card should be dismissed/removed from feed
      expect(find.byType(FeedAddFriendsCard), findsNothing);
    });

    testWidgets('Does NOT show FeedAddFriendsCard when user has friends (followingCount > 0)', (tester) async {
      final repo = _FakeFeedRepo([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedRepositoryProvider.overrideWithValue(repo),
            tourServiceProvider.overrideWithValue(_FakeTourService()),
            userRepositoryProvider.overrideWithValue(_FakeUserRepo(followingCount: 5)),
            authStateProvider.overrideWith(
              () => _MockAuthNotifier(
                AuthState(
                  isAuthenticated: true,
                  user: userWithFriends,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(find.byType(FeedAddFriendsCard), findsNothing);
    });
  });
}
