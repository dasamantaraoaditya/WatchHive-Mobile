import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/entries/widgets/wh_entry_grid_card.dart';
import 'package:watchhive_mobile/features/feed/widgets/wh_feed_card.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

void main() {
  group('WHEntryGridCard.formatSuggestedBy Unit Tests', () {
    test('keeps short username intact with @ prefix', () {
      expect(WHEntryGridCard.formatSuggestedBy('alice'), equals('@alice'));
      expect(WHEntryGridCard.formatSuggestedBy('@bob'), equals('@bob'));
      expect(WHEntryGridCard.formatSuggestedBy('1234567890'), equals('@1234567890'));
    });

    test('truncates username longer than 10 characters to 10 chars followed by ...', () {
      expect(
        WHEntryGridCard.formatSuggestedBy('adityadasamantharao'),
        equals('@adityadasa...'),
      );
      expect(
        WHEntryGridCard.formatSuggestedBy('@adityadasamantharao'),
        equals('@adityadasa...'),
      );
      expect(
        WHEntryGridCard.formatSuggestedBy('12345678901'),
        equals('@1234567890...'),
      );
    });

    test('formats "To: @" prefix correctly with 10-char truncation', () {
      expect(
        WHEntryGridCard.formatSuggestedBy('To: @alice'),
        equals('To: @alice'),
      );
      expect(
        WHEntryGridCard.formatSuggestedBy('To: @adityadasamantharao'),
        equals('To: @adityadasa...'),
      );
    });

    test('preserves count suffix (+N) when truncating username', () {
      expect(
        WHEntryGridCard.formatSuggestedBy('To: @adityadasamantharao (+2)'),
        equals('To: @adityadasa... (+2)'),
      );
      expect(
        WHEntryGridCard.formatSuggestedBy('adityadasamantharao (+3)'),
        equals('@adityadasa... (+3)'),
      );
      expect(
        WHEntryGridCard.formatSuggestedBy('alice (+1)'),
        equals('@alice (+1)'),
      );
    });

    test('handles empty string gracefully', () {
      expect(WHEntryGridCard.formatSuggestedBy(''), equals(''));
    });
  });

  group('WHEntryGridCard Widget Truncation Tests', () {
    testWidgets('displays truncated username with ... on card badge', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WHEntryGridCard(
                tmdbId: 100,
                title: 'Inception',
                mediaType: 'movie',
                mode: WHEntryCardMode.watchlist,
                initialPosterPath: '/poster.jpg',
                suggestedByUsername: 'adityadasamantharao',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Badge should display @adityadasa...
      expect(find.text('@adityadasa...'), findsOneWidget);
      // Full username should not be displayed in the badge
      expect(find.text('@adityadasamantharao'), findsNothing);
    });
  });

  group('WHFeedCard Suggested Username Truncation Tests', () {
    testWidgets('truncates username to 10 chars + ... when displayName is null', (tester) async {
      final user = User(
        id: 'user-1',
        username: 'cinephile_creator',
        displayName: null,
        email: 'user1@example.com',
        createdAt: DateTime(2025, 1, 1),
      );

      final entry = Entry(
        id: 'entry-1',
        userId: 'user-1',
        tmdbId: 550,
        title: 'Fight Club',
        type: 'MOVIE',
        watchedAt: DateTime(2025, 1, 1),
        user: user,
        suggestedByUser: User(
          id: 'sugg-user-1',
          username: 'adityadasamantharao',
          displayName: null,
          email: 'sugg@example.com',
          createdAt: DateTime(2025, 1, 1),
        ),
        createdAt: DateTime(2025, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: WHFeedCard(
                  entry: entry,
                  isLiked: false,
                  isOwnEntry: false,
                  onLike: () {},
                  onUserTap: () {},
                  onMediaTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Suggested by username should be truncated to 10 letters + ...
      expect(find.text('adityadasa...'), findsOneWidget);
      expect(find.text('adityadasamantharao'), findsNothing);
    });
  });
}
