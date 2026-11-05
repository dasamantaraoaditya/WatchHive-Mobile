import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/feed/widgets/feed_add_friends_card.dart';
import 'package:watchhive_mobile/shared/models/user.dart';
import 'package:watchhive_mobile/shared/widgets/wh_bee_loader.dart';

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
      expect(find.text('Add Friends'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap follow on first user
      final followButtons = find.text('Follow');
      expect(followButtons, findsNWidgets(2));
      await tester.tap(followButtons.first);
      await tester.pump();

      expect(followedUser?.id, 'u1');

      // Tap Add Friends
      await tester.tap(find.text('Add Friends'));
      await tester.pump();
      expect(addFriendsTapped, isTrue);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(dismissedTapped, isTrue);
    });

    testWidgets('tapping user profile header invokes onUserTap', (tester) async {
      User? tappedUser;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeedAddFriendsCard(
                onAddFriends: () {},
                onDismiss: () {},
                suggestedUsers: testUsers,
                onUserTap: (u) => tappedUser = u,
              ),
            ),
          ),
        ),
      );

      // Tap Jane Doe's profile header
      await tester.tap(find.text('Jane Doe'));
      await tester.pump();

      expect(tappedUser?.id, equals('u1'));
      expect(tappedUser?.username, equals('cinephile_jane'));
    });

    testWidgets('shows loading spinner when user is in loadingFollowMap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeedAddFriendsCard(
                onAddFriends: () {},
                onDismiss: () {},
                suggestedUsers: testUsers,
                loadingFollowMap: const {'u1': true},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(WHBeeSpinner), findsOneWidget);
    });

    testWidgets('shows Following state when user is in followingMap and handles toggle tap', (tester) async {
      User? toggledUser;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeedAddFriendsCard(
                onAddFriends: () {},
                onDismiss: () {},
                suggestedUsers: testUsers,
                followingMap: const {'u1': true},
                onFollowUser: (u) => toggledUser = u,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);

      // Tap on 'Following' button to trigger toggle
      await tester.tap(find.text('Following'));
      await tester.pump();

      expect(toggledUser?.id, equals('u1'));
    });

    testWidgets('renders cleanly on web viewport with scroll arrow navigation for >2 users', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final threeUsers = [
        ...testUsers,
        User(
          id: 'u3',
          username: 'cinephile_chris',
          displayName: 'Chris Nolan Fan',
          bio: 'IMAX lover',
          suggestionReason: 'Shares your genres',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeedAddFriendsCard(
                onAddFriends: () {},
                onDismiss: () {},
                suggestedUsers: threeUsers,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check chevron buttons exist for >2 users
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Tap right arrow
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();

      // Tap left arrow
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
    });

    testWidgets('renders cleanly on standard mobile viewport (390x844)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeedAddFriendsCard(
                onAddFriends: () {},
                onDismiss: () {},
                suggestedUsers: testUsers,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Diversify Your Feed & Suggestions'), findsOneWidget);
      expect(find.text('Add Friends'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('Bob Smith'), findsOneWidget);
    });
  });
}
