import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:watchhive_mobile/features/entries/screens/add_entry_sheet.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';

void main() {
  group('AddEntrySheet Started Watching Date Tests', () {
    testWidgets('Completed mode displays both Started Watching and Completed Watching sections', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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

      // Verify both headers exist
      expect(find.text('Started Watching'), findsOneWidget);
      expect(find.text('Completed Watching'), findsOneWidget);

      // By default for new completed watch, start date is omitted (unknown)
      expect(find.text("Don't know when I started watching"), findsOneWidget);
      expect(find.text('Start date omitted · You can add or edit it anytime'), findsOneWidget);
      expect(find.text('Watched Date'), findsOneWidget);
      expect(find.text('Watched Time'), findsOneWidget);
    });

    testWidgets('Tapping Set Date in completed mode reveals Started Date and Started Time tiles', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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

      // Find Set Date button in Started Watching section
      final setDateButtons = find.widgetWithText(TextButton, 'Set Date');
      expect(setDateButtons, findsWidgets);

      await tester.ensureVisible(setDateButtons.first);
      await tester.tap(setDateButtons.first);
      await tester.pumpAndSettle();

      // Now Started Date and Started Time should be visible
      expect(find.text('Started Date'), findsOneWidget);
      expect(find.text('Started Time'), findsOneWidget);
      expect(find.text("Don't know start"), findsOneWidget);

      // Tap Don't know start
      await tester.ensureVisible(find.text("Don't know start"));
      await tester.tap(find.text("Don't know start"));
      await tester.pumpAndSettle();

      // It should revert to the banner
      expect(find.text("Don't know when I started watching"), findsOneWidget);
    });

    testWidgets('Watching mode allows toggling to unknown start date and back', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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
      expect(find.text("Don't know start"), findsOneWidget);

      // Tap Don't know start
      await tester.ensureVisible(find.text("Don't know start"));
      await tester.tap(find.text("Don't know start"));
      await tester.pumpAndSettle();

      expect(find.text("Don't know when I started watching"), findsOneWidget);
      expect(find.text('Tracking progress without an exact start date · Edit anytime'), findsOneWidget);
    });

    testWidgets('Editing entry with startedAt pre-fills Started Date and Started Time in completed mode', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final startedDate = DateTime(2025, 12, 1, 14, 0);
      final completedDate = DateTime(2025, 12, 25, 20, 0);

      final mockEntry = Entry(
        id: 'entry-test-1',
        userId: 'user-1',
        tmdbId: 0,
        title: 'Fight Club',
        type: 'MOVIE',
        startedAt: startedDate,
        completedAt: completedDate,
        watchedAt: completedDate,
        createdAt: startedDate,
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

      expect(find.text('Started Date'), findsOneWidget);
      expect(find.text('Started Time'), findsOneWidget);
      expect(find.text(DateFormat('MMM dd, yyyy').format(startedDate)), findsOneWidget);
      expect(find.text(DateFormat('MMM dd, yyyy').format(completedDate)), findsOneWidget);
    });
  });
}
