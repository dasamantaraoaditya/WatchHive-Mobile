import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/feed/widgets/wh_feed_card.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockUser = User(
    id: 'user_review_test_1',
    username: 'filmcritic',
    displayName: 'Film Critic',
    email: 'critic@test.com',
    createdAt: DateTime(2025, 1, 1),
  );

  Entry createEntryWithReview(String review) {
    return Entry(
      id: 'entry_review_1',
      userId: 'user_review_test_1',
      tmdbId: 550,
      type: 'MOVIE',
      title: 'Fight Club',
      watchedAt: DateTime(2026, 11, 1, 20, 0),
      createdAt: DateTime(2026, 11, 1, 20, 0),
      user: mockUser,
      review: review,
    );
  }

  Widget createWidget({required Entry entry, bool initiallyExpanded = false}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WHFeedCard(
              entry: entry,
              initiallyExpandedReview: initiallyExpanded,
              isLiked: false,
              isOwnEntry: false,
              onLike: () {},
              onUserTap: () {},
              onMediaTap: () {},
            ),
          ),
        ),
      ),
    );
  }

  group('WHFeedCard Review Read More / Show Less Tests', () {
    testWidgets('Short review does not display Read more or Show less toggle', (tester) async {
      const shortReview = 'An exceptional thriller with brilliant cinematography and a gripping third act.';
      final entry = createEntryWithReview(shortReview);

      await tester.pumpWidget(createWidget(entry: entry));
      await tester.pumpAndSettle();

      expect(find.text('“$shortReview”'), findsOneWidget);
      expect(find.text('Read more'), findsNothing);
      expect(find.text('Show less'), findsNothing);
    });

    testWidgets('Long review (>160 chars) displays Read more initially, expands on tap to Show less, and collapses back', (tester) async {
      const longReview =
          'Dune: Part Two is an extraordinary cinematic triumph. Denis Villeneuve crafts a sprawling, '
          'hypnotic masterpiece of sound, scale, and intensity that completely immerses you from start to finish. '
          'Austin Butler and Timothée Chalamet deliver unforgettable performances that elevate the sci-fi genre.';
      expect(longReview.length, greaterThan(160));

      final entry = createEntryWithReview(longReview);

      await tester.pumpWidget(createWidget(entry: entry));
      await tester.pumpAndSettle();

      // Initially shows 'Read more'
      expect(find.text('Read more'), findsOneWidget);
      expect(find.text('Show less'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      // Tap 'Read more'
      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();

      // Now expanded: shows 'Show less'
      expect(find.text('Show less'), findsOneWidget);
      expect(find.text('Read more'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

      // Tap 'Show less' to collapse
      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();

      // Collapsed again: shows 'Read more'
      expect(find.text('Read more'), findsOneWidget);
      expect(find.text('Show less'), findsNothing);
    });

    testWidgets('Tapping the review box container also toggles expansion for long reviews', (tester) async {
      const multilineReview =
          '1. Fantastic world-building and character arcs.\n'
          '2. The sound design is thunderous and evocative.\n'
          '3. Definitely one of the best theater experiences of the decade.';
      final entry = createEntryWithReview(multilineReview);

      await tester.pumpWidget(createWidget(entry: entry));
      await tester.pumpAndSettle();

      expect(find.text('Read more'), findsOneWidget);
      expect(find.text('Show less'), findsNothing);

      // Tap the container
      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();

      expect(find.text('Show less'), findsOneWidget);
      expect(find.text('Read more'), findsNothing);
    });

    testWidgets('initiallyExpandedReview: true renders in expanded state with Show less', (tester) async {
      const longReview =
          'Oppenheimer is a searing exploration of ambition, morality, and devastating consequences. '
          'Cillian Murphy gives a career-defining performance anchoring Christopher Nolan’s tightly coiled historical thriller.';
      final entry = createEntryWithReview(longReview);

      await tester.pumpWidget(createWidget(entry: entry, initiallyExpanded: true));
      await tester.pumpAndSettle();

      expect(find.text('Show less'), findsOneWidget);
      expect(find.text('Read more'), findsNothing);
    });
  });
}
