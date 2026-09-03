import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/entries/widgets/wh_entry_grid_card.dart';

void main() {
  group('WHEntryGridCard Date Tests Across All Modes', () {
    testWidgets('renders clean added date without prefix in watchlist mode', (tester) async {
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

      expect(find.text('Jan 15, 2026'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_added_rounded), findsOneWidget);
    });

    testWidgets('renders clean started date in watching mode', (tester) async {
      final startDate = DateTime(2026, 2, 10);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 320,
                child: WHEntryGridCard(
                  tmdbId: 0,
                  title: 'Breaking Bad',
                  mediaType: 'tv',
                  mode: WHEntryCardMode.watching,
                  startedAt: startDate,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Feb 10, 2026'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('renders clean logged date in history mode', (tester) async {
      final watchDate = DateTime(2026, 3, 5);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 320,
                child: WHEntryGridCard(
                  tmdbId: 0,
                  title: 'Oppenheimer',
                  mediaType: 'movie',
                  mode: WHEntryCardMode.history,
                  watchedAt: watchDate,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Mar 5, 2026'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    });

    testWidgets('renders clean suggested date in suggestion mode', (tester) async {
      final suggestDate = DateTime(2026, 4, 20);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 320,
                child: WHEntryGridCard(
                  tmdbId: 0,
                  title: 'Dune',
                  mediaType: 'movie',
                  mode: WHEntryCardMode.suggestion,
                  suggestedAt: suggestDate,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Apr 20, 2026'), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);
    });
  });
}
