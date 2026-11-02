import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/entries/widgets/friends_watched_bar.dart';
import 'package:watchhive_mobile/features/entries/widgets/friends_who_watched_sheet.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final user1 = User(
    id: 'user_1',
    username: 'alex',
    displayName: 'Alex',
    createdAt: DateTime(2025, 1, 1),
  );

  final user2 = User(
    id: 'user_2',
    username: 'sam',
    displayName: 'Sam',
    createdAt: DateTime(2025, 1, 1),
  );

  final user3 = User(
    id: 'user_3',
    username: 'jordan',
    displayName: 'Jordan',
    createdAt: DateTime(2025, 1, 1),
  );

  final user4 = User(
    id: 'user_4',
    username: 'taylor',
    displayName: 'Taylor',
    createdAt: DateTime(2025, 1, 1),
  );

  final user5 = User(
    id: 'user_5',
    username: 'morgan',
    displayName: 'Morgan',
    createdAt: DateTime(2025, 1, 1),
  );

  Entry createFriendEntry({
    required String id,
    required User user,
    double? rating,
    String? review,
  }) {
    return Entry(
      id: id,
      userId: user.id,
      tmdbId: 157336,
      type: 'MOVIE',
      title: 'Interstellar',
      rating: rating,
      review: review,
      watchedAt: DateTime(2026, 10, 15),
      createdAt: DateTime(2026, 10, 15),
      user: user,
    );
  }

  Widget createTestWidget({required Widget child}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: child,
          ),
        ),
      ),
    );
  }

  group('FriendsWatchedBar Component Tests', () {
    testWidgets('Renders empty when friendsEntries is empty', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: FriendsWatchedBar(
            friendsEntries: const [],
            movieTitle: 'Interstellar',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FriendsWatchedBar), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      expect(find.textContaining('watched this'), findsNothing);
    });

    testWidgets('Renders 1 friend correctly with name and tap callback', (tester) async {
      var tapped = false;
      final entry1 = createFriendEntry(id: 'e1', user: user1, rating: 9.0, review: 'Absolute masterpiece!');

      await tester.pumpWidget(
        createTestWidget(
          child: FriendsWatchedBar(
            friendsEntries: [entry1],
            movieTitle: 'Interstellar',
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alex watched this'), findsOneWidget);
      expect(find.text('Tap to view friend reviews'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      await tester.tap(find.byType(FriendsWatchedBar));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('Renders 2 friends correctly', (tester) async {
      final entry1 = createFriendEntry(id: 'e1', user: user1, rating: 8.5);
      final entry2 = createFriendEntry(id: 'e2', user: user2, rating: 9.5);

      await tester.pumpWidget(
        createTestWidget(
          child: FriendsWatchedBar(
            friendsEntries: [entry1, entry2],
            movieTitle: 'Interstellar',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alex & Sam watched this'), findsOneWidget);
      expect(find.text('9.0'), findsOneWidget); // Average rating pill
    });

    testWidgets('Renders 3 friends correctly without overflow badge', (tester) async {
      final entry1 = createFriendEntry(id: 'e1', user: user1);
      final entry2 = createFriendEntry(id: 'e2', user: user2);
      final entry3 = createFriendEntry(id: 'e3', user: user3);

      await tester.pumpWidget(
        createTestWidget(
          child: FriendsWatchedBar(
            friendsEntries: [entry1, entry2, entry3],
            movieTitle: 'Interstellar',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Watched by 3 friends'), findsOneWidget);
      expect(find.text('Alex, Sam & 1 other'), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('Renders max 3 avatars + "+2" badge for 5 friends', (tester) async {
      final entries = [
        createFriendEntry(id: 'e1', user: user1, rating: 8.0),
        createFriendEntry(id: 'e2', user: user2, rating: 9.0),
        createFriendEntry(id: 'e3', user: user3, rating: 10.0),
        createFriendEntry(id: 'e4', user: user4),
        createFriendEntry(id: 'e5', user: user5),
      ];

      await tester.pumpWidget(
        createTestWidget(
          child: FriendsWatchedBar(
            friendsEntries: entries,
            movieTitle: 'Interstellar',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Watched by 5 friends'), findsOneWidget);
      expect(find.text('Alex, Sam & 3 others'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget); // 5 - 3 = 2 overflow badge
      expect(find.text('9.0'), findsOneWidget); // Average of (8 + 9 + 10) / 3
    });
  });

  group('FriendsWhoWatchedSheet Tests', () {
    testWidgets('Renders friends reviews and handles interactions', (tester) async {
      final entry1 = createFriendEntry(
        id: 'e1',
        user: user1,
        rating: 9.5,
        review: 'Mind-bending cinematic experience with incredible soundtrack by Hans Zimmer that echoes for days.',
      );
      final entry2 = createFriendEntry(
        id: 'e2',
        user: user2,
        rating: 8.0,
      );

      final myEntry = Entry(
        id: 'my_entry',
        userId: 'current_user',
        tmdbId: 157336,
        type: 'MOVIE',
        title: 'Interstellar',
        rating: 9.0,
        watchedAt: DateTime(2026, 10, 20),
        createdAt: DateTime(2026, 10, 20),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FriendsWhoWatchedSheet(
                movieTitle: 'Interstellar',
                friendsEntries: [entry1, entry2],
                myEntry: myEntry,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header verification
      expect(find.text('Friends Who Watched (2)'), findsOneWidget);
      expect(find.text('Interstellar'), findsOneWidget);

      // Friends cards
      expect(find.text('Alex'), findsOneWidget);
      expect(find.textContaining('@alex'), findsOneWidget);
      expect(find.text('9.5'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);
      expect(find.textContaining('@sam'), findsOneWidget);
      expect(find.text('8.0'), findsOneWidget);

      // Mood badge and review text
      expect(find.text('Mind-bending cinematic experience with incredible soundtrack by Hans Zimmer that echoes for days.'), findsOneWidget);
      expect(find.text('Outstanding / Near Flawless'), findsOneWidget); // Mood for 9.5 rating

      // Rating comparison badge with user's rating (both Alex and Sam compare against user's 9.0 rating)
      expect(find.text('You rated this ⭐ 9.0 (Difference: 0.5)'), findsOneWidget);
      expect(find.text('You rated this ⭐ 9.0 (Difference: -1.0)'), findsOneWidget);
    });
  });
}
