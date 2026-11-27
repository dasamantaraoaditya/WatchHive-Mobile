import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/shared/widgets/shared_widgets.dart';

void main() {
  group('TMDBPosterImage & WHAvatar Robustness Tests', () {
    testWidgets('TMDBPosterImage renders with double.infinity dimensions without UnsupportedError', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: TMDBPosterImage(
                posterPath: '/valid_poster.jpg',
                width: double.infinity,
                height: double.infinity,
                borderRadius: 12,
              ),
            ),
          ),
        ),
      );

      // Verify that no exceptions or UnsupportedError: Infinity or NaN toInt are thrown
      expect(tester.takeException(), isNull);
      expect(find.byType(TMDBPosterImage), findsOneWidget);
    });

    testWidgets('TMDBPosterImage handles null, empty, and "null"/"undefined" posterPath safely', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TMDBPosterImage(posterPath: null, width: 80, height: 120),
                TMDBPosterImage(posterPath: '', width: 80, height: 120),
                TMDBPosterImage(posterPath: '   ', width: 80, height: 120),
                TMDBPosterImage(posterPath: 'null', width: 80, height: 120),
                TMDBPosterImage(posterPath: 'undefined', width: 80, height: 120),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(TMDBPosterImage), findsNWidgets(5));
      expect(find.byIcon(Icons.movie_creation_outlined), findsNWidgets(5));
    });

    testWidgets('TMDBPosterImage renders with finite standard dimensions and full URLs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TMDBPosterImage(
                  posterPath: '/sample.jpg',
                  width: 56,
                  height: 80,
                ),
                TMDBPosterImage(
                  posterPath: 'https://image.tmdb.org/t/p/w500/full_url.jpg',
                  width: 100,
                  height: 150,
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(TMDBPosterImage), findsNWidgets(2));
    });

    testWidgets('WHAvatar renders with infinite radius without throwing UnsupportedError', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80,
              height: 80,
              child: WHAvatar(
                imageUrl: 'https://example.com/avatar.jpg',
                name: 'Aditya',
                radius: double.infinity,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(WHAvatar), findsOneWidget);
    });

    testWidgets('WHAvatar handles null and empty image URLs with letter fallback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                WHAvatar(imageUrl: null, name: 'Sravan', radius: 24),
                WHAvatar(imageUrl: '', name: '', radius: 24),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('S'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
    });
  });
}
