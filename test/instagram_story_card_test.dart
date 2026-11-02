import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/utils/share_helper.dart';
import 'package:watchhive_mobile/features/share/widgets/instagram_story_card.dart';
import 'package:watchhive_mobile/features/share/widgets/story_share_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InstagramStoryCard Widget Tests', () {
    testWidgets('renders title, pictorial stars, rating, review snippet, and QR link', (tester) async {
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
                  isCompleted: true,
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

      // Verify WatchersHive link and QR code CTA
      expect(find.text('View on WatchersHive'), findsOneWidget);
      expect(find.text('watchershive.com/m/157336'), findsOneWidget);
    });

    testWidgets('renders TV series badge and Watching status correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 640,
                child: InstagramStoryCard(
                  title: 'Severance',
                  rating: 8.5,
                  tmdbId: 97546,
                  mediaType: 'tv',
                  releaseYear: '2022',
                  username: 'mark_s',
                  isCompleted: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Severance'), findsOneWidget);
      expect(find.text('📺 WATCHING'), findsOneWidget);
      expect(find.text('SERIES • 2022'), findsOneWidget);
      expect(find.text('watchershive.com/tv/97546'), findsOneWidget);
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
}
