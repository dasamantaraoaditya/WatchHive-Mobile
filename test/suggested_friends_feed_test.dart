import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/feed/widgets/feed_add_friends_card.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

void main() {
  group('FeedAddFriendsCard with Suggested Friends Tests', () {
    final testUsers = [
      User(
        id: 'u1',
        username: 'cinephile_jane',
        displayName: 'Jane Doe',
        bio: 'Sci-Fi Fan',
        suggestionReason: 'Top Reviewer',
        createdAt: DateTime.now(),
      ),
      User(
        id: 'u2',
        username: 'movie_bob',
        displayName: 'Bob Smith',
        bio: 'Horror Buff',
        suggestionReason: 'Follows you',
        createdAt: DateTime.now(),
      ),
    ];

    testWidgets('renders header, title, and suggested friends list correctly', (tester) async {
      bool addFriendsTapped = false;
      bool dismissedTapped = false;
      User? followedUser;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeedAddFriendsCard(
                onAddFriends: () => addFriendsTapped = true,
                onDismiss: () => dismissedTapped = true,
                suggestedUsers: testUsers,
                onFollowUser: (u) => followedUser = u,
              ),
            ),
          ),
        ),
      );

      // Verify header and description
      expect(find.text('Diversify Your Feed & Suggestions'), findsOneWidget);
      expect(find.textContaining('You haven’t added any friends yet'), findsOneWidget);

      // Verify suggested users section
      expect(find.text('SUGGESTED FRIENDS TO FOLLOW'), findsOneWidget);
      expect(find.text('2 cinephiles'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('@cinephile_jane'), findsOneWidget);
      expect(find.text('Top Reviewer'), findsOneWidget);

      expect(find.text('Bob Smith'), findsOneWidget);
      expect(find.text('@movie_bob'), findsOneWidget);
      expect(find.text('Follows you'), findsOneWidget);

      // Verify buttons
      expect(find.text('Find More Friends'), findsOneWidget);
      expect(find.text('Maybe Later'), findsOneWidget);

      // Tap follow on first user
      final followButtons = find.text('Follow');
      expect(followButtons, findsNWidgets(2));
      await tester.tap(followButtons.first);
      await tester.pump();

      expect(followedUser?.id, 'u1');

      // Tap Find More Friends
      await tester.tap(find.text('Find More Friends'));
      await tester.pump();
      expect(addFriendsTapped, isTrue);

      // Tap Maybe Later
      await tester.tap(find.text('Maybe Later'));
      await tester.pump();
      expect(dismissedTapped, isTrue);
    });

    testWidgets('shows Following state when user is in followingMap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeedAddFriendsCard(
                onAddFriends: () {},
                onDismiss: () {},
                suggestedUsers: testUsers,
                followingMap: const {'u1': true},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
    });
  });
}
