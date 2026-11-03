import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchhive_mobile/core/utils/share_helper.dart';
import 'package:watchhive_mobile/features/feed/widgets/wh_feed_card.dart';
import 'package:watchhive_mobile/features/share/widgets/instagram_story_card.dart';
import 'package:watchhive_mobile/features/share/widgets/story_share_modal.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InstagramStoryCard Widget Tests', () {
    testWidgets('renders logged watch with title, pictorial stars, rating, review snippet, and clean QR link without ugly numbers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 640,
                child: InstagramStoryCard(
                  title: 'Interstellar',
                  rating: 9.0,
                  review: 'A breathtaking journey through space and time with unmatched emotional depth.',
                  tmdbId: 157336,
                  mediaType: 'movie',
                  releaseYear: '2014',
                  userDisplayName: 'Cooper',
                  username: 'cooper_pilot',
                  shareMode: StoryShareMode.logged,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify title is rendered
      expect(find.text('Interstellar'), findsOneWidget);

      // Verify user attribution
      expect(find.text('Logged by Cooper'), findsOneWidget);

      // Verify status badge
      expect(find.text('🍿 JUST WATCHED'), findsOneWidget);

      // Verify pictorial rating
      expect(find.text('9.0 / 10'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsWidgets);

      // Verify review snippet
      expect(find.textContaining('breathtaking journey'), findsOneWidget);

      // Verify WatchersHive link and QR code CTA with clean domain (NO ugly numbers!)
      expect(find.text('View on WatchersHive'), findsOneWidget);
      expect(find.text('watchershive.com'), findsOneWidget);
    });

    testWidgets('renders currently watching status without personal rating', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 640,
                child: InstagramStoryCard(
                  title: 'Severance',
                  tmdbId: 97546,
                  mediaType: 'tv',
                  releaseYear: '2022',
                  username: 'mark_s',
                  shareMode: StoryShareMode.watching,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Severance'), findsOneWidget);
      expect(find.text('Watching now: mark_s'), findsOneWidget);
      expect(find.text('📺 WATCHING'), findsOneWidget);
      expect(find.text('SERIES • 2022'), findsOneWidget);
      expect(find.text('Started Watching'), findsOneWidget);
      // Ensure no star rating is shown for currently watching
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.text('watchershive.com'), findsOneWidget);
    });

    testWidgets('renders general movie share without logged or watching claims', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 640,
                child: InstagramStoryCard(
                  title: 'Dune: Part Two',
                  rating: 8.6,
                  tmdbId: 693134,
                  mediaType: 'movie',
                  releaseYear: '2024',
                  username: 'aditya',
                  shareMode: StoryShareMode.general,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Dune: Part Two'), findsOneWidget);
      expect(find.text('Shared via WatchersHive'), findsOneWidget);
      expect(find.text('🎬 DISCOVER'), findsOneWidget);
      expect(find.text('8.6 TMDB Rating'), findsOneWidget);
      expect(find.text('Check out on WatchersHive'), findsOneWidget);
      expect(find.text('watchershive.com'), findsOneWidget);
    });
  });

  group('StoryShareModal Widget Tests', () {
    testWidgets('renders preview modal with Share to Instagram, Copy Link, and fallback buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => StoryShareModal.show(
                  context,
                  title: 'Dune: Part Two',
                  rating: 9.2,
                  tmdbId: 693134,
                  mediaType: 'movie',
                  releaseYear: '2024',
                  userDisplayName: 'Paul',
                  username: 'muaddib',
                ),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Check modal contents
      expect(find.text('Share to Story'), findsOneWidget);
      expect(find.text('Share to Instagram / Stories'), findsOneWidget);
      expect(find.text('Copy Link'), findsOneWidget);
      expect(find.text('Share Text'), findsOneWidget);
      expect(find.text('Dune: Part Two'), findsOneWidget);
    });
  });

  group('ShareHelper Integration', () {
    testWidgets('showStoryShareModal displays the bottom sheet modal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ShareHelper.showStoryShareModal(
                  context,
                  title: 'Blade Runner 2049',
                  rating: 9.4,
                  tmdbId: 335984,
                ),
                child: const Text('Share Button'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Share Button'));
      await tester.pumpAndSettle();

      expect(find.text('Share to Story'), findsOneWidget);
      expect(find.text('Blade Runner 2049'), findsOneWidget);
    });
  });

  group('Post Sharing Ownership Restrictions', () {
    final otherUser = User(
      id: 'other-user-999',
      username: 'other_user',
      displayName: 'Other Person',
      createdAt: DateTime(2025, 1, 1),
    );

    final mockEntry = Entry(
      id: 'entry-999',
      userId: 'other-user-999',
      tmdbId: 157336,
      title: 'Interstellar',
      type: 'MOVIE',
      watchedAt: DateTime(2025, 6, 1),
      rating: 9.0,
      user: otherUser,
      createdAt: DateTime(2025, 6, 1),
    );

    testWidgets('WHFeedCard does NOT show share button for another user\'s post', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WHFeedCard(
                entry: mockEntry,
                isLiked: false,
                isOwnEntry: false, // NOT own post
                onLike: () {},
                onUserTap: () {},
                onMediaTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure 'Share Watch' tooltip / IconButton is NOT present for someone else's post
      expect(find.byTooltip('Share Watch'), findsNothing);
    });

    testWidgets('WHFeedCard DOES show share button for own post', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WHFeedCard(
                entry: mockEntry,
                isLiked: false,
                isOwnEntry: true, // OWN post
                onLike: () {},
                onUserTap: () {},
                onMediaTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure 'Share Watch' tooltip / IconButton IS present for own post
      expect(find.byTooltip('Share Watch'), findsOneWidget);
    });
  });
}
