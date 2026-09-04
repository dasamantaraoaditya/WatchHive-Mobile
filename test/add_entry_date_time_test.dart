import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:watchhive_mobile/features/entries/screens/add_entry_sheet.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';

void main() {
  group('AddEntrySheet Date & Time Selection Tests', () {
    testWidgets('renders Watched Date and Watched Time tiles with formatted strings', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AddEntrySheet(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify Section Header
      expect(find.text('When Did You Watch?'), findsOneWidget);
      expect(find.text('Date and time of your screening'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);

      // Verify Date and Time tiles exist
      expect(find.text('Watched Date'), findsOneWidget);
      expect(find.text('Watched Time'), findsOneWidget);

      // Verify format matches current date/time
      final todayStr = DateFormat('MMM dd, yyyy').format(DateTime.now());
      expect(find.text(todayStr), findsOneWidget);
    });

    testWidgets('renders Started Date and Started Time in watching mode', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AddEntrySheet(prefillIsWatching: true),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Started Watching'), findsOneWidget);
      expect(find.text('Started Date'), findsOneWidget);
      expect(find.text('Started Time'), findsOneWidget);
    });

    testWidgets('preserves and displays existing entry date and time when editing', (tester) async {
      final specificDate = DateTime(2025, 12, 25, 20, 45); // Dec 25, 2025 at 8:45 PM

      final mockEntry = Entry(
        id: 'entry-123',
        userId: 'user-1',
        tmdbId: 550,
        title: 'Fight Club',
        type: 'MOVIE',
        watchedAt: specificDate,
        createdAt: specificDate,
        tags: ['classic'],
        isRewatch: false,
        isWatching: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AddEntrySheet(editEntry: mockEntry),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text(DateFormat('MMM dd, yyyy').format(specificDate)), findsOneWidget);
      expect(find.text(DateFormat('h:mm a').format(specificDate)), findsOneWidget);
    });
  });
}
