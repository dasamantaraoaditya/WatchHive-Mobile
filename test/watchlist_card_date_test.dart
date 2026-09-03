import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/entries/widgets/wh_entry_grid_card.dart';

void main() {
  group('WHEntryGridCard Watchlist Date Tests', () {
    testWidgets('renders formatted added date when addedAt is provided in watchlist mode', (tester) async {
      final testDate = DateTime(2026, 1, 15);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 320,
                child: WHEntryGridCard(
                  tmdbId: 0,
                  title: 'Interstellar',
                  mediaType: 'movie',
                  mode: WHEntryCardMode.watchlist,
                  addedAt: testDate,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Added Jan 15, 2026'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_added_rounded), findsOneWidget);
    });

    testWidgets('renders "Added to List" when addedAt is null in watchlist mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 320,
                child: WHEntryGridCard(
                  tmdbId: 0,
                  title: 'Interstellar',
                  mediaType: 'movie',
                  mode: WHEntryCardMode.watchlist,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Added to List'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_added_rounded), findsOneWidget);
    });
  });
}
