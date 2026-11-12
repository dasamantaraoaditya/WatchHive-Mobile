import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/entries/widgets/post_log_success_dialog.dart';

void main() {
  group('PostLogSuccessDialog Widget Tests', () {
    testWidgets('renders Currently Watching dialog with Share to Story and Suggest options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PostLogSuccessDialog.show(
                  context,
                  title: 'Dune: Part Two',
                  tmdbId: 693134,
                  mediaType: 'movie',
                  isWatching: true,
                ),
                child: const Text('Trigger'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('NOW WATCHING 🍿'), findsOneWidget);
      expect(find.text('Started Watching!'), findsOneWidget);
      expect(find.text('Dune: Part Two'), findsOneWidget);
      expect(find.text('Share to Story'), findsOneWidget);
      expect(find.text('Suggest to a Friend'), findsOneWidget);
      expect(find.text('Add to Cinematic Stack'), findsNothing);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('NOW WATCHING 🍿'), findsNothing);
    });

    testWidgets('renders Completed Watch dialog with rating, review, Share Review to Story, Suggest, and Stack options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => PostLogSuccessDialog.show(
                  context,
                  title: 'Inception',
                  tmdbId: 27205,
                  mediaType: 'movie',
                  rating: 9.5,
                  review: 'Mind-bending masterpiece.',
                  isWatching: false,
                ),
                child: const Text('Trigger'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();

      expect(find.text('WATCH LOGGED 🏆'), findsOneWidget);
      expect(find.text('Watch Logged!'), findsOneWidget);
      expect(find.text('Inception'), findsOneWidget);
      expect(find.text('⭐ 9.5 / 10'), findsOneWidget);
      expect(find.text('“Mind-bending masterpiece.”'), findsOneWidget);
      expect(find.text('Share Review to Story'), findsOneWidget);
      expect(find.text('Suggest to a Friend'), findsOneWidget);
      expect(find.text('Add to Cinematic Stack'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
