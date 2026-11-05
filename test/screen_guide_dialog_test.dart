import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/onboarding/widgets/screen_guide_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScreenGuideData Model Tests', () {
    test('Every ScreenGuideType has valid badge, title, highlights, and pro-tip', () {
      for (final type in ScreenGuideType.values) {
        final data = ScreenGuideData.forType(type);
        expect(data.badgeText, isNotEmpty, reason: 'Badge empty for $type');
        expect(data.title, isNotEmpty, reason: 'Title empty for $type');
        expect(data.description, isNotEmpty, reason: 'Description empty for $type');
        expect(data.highlights, isNotEmpty, reason: 'Highlights empty for $type');
        expect(data.proTip, isNotEmpty, reason: 'ProTip empty for $type');
        for (final item in data.highlights) {
          expect(item.title, isNotEmpty);
          expect(item.description, isNotEmpty);
        }
      }
    });

    test('All expected screen guide types are supported', () {
      expect(
        ScreenGuideType.values,
        containsAll([
          ScreenGuideType.feed,
          ScreenGuideType.entries,
          ScreenGuideType.search,
          ScreenGuideType.rankings,
          ScreenGuideType.profile,
          ScreenGuideType.movieDetails,
          ScreenGuideType.notifications,
          ScreenGuideType.mindlens,
          ScreenGuideType.scanner,
          ScreenGuideType.userProfile,
          ScreenGuideType.compareHistory,
        ]),
      );
    });
  });

  group('ScreenGuideDialog Widget Tests', () {
    testWidgets('renders feed screen guide correctly and closes on "Got It!"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ScreenGuideDialog.show(context, ScreenGuideType.feed),
                child: const Text('Open Feed Guide'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Feed Guide'));
      await tester.pumpAndSettle();

      expect(find.text('COMMUNITY FEED'), findsOneWidget);
      expect(find.text('Hive Community Feed'), findsOneWidget);
      expect(find.text('Reviews & Watch Moments'), findsOneWidget);
      expect(find.text('PRO TIP'), findsOneWidget);
      expect(find.text('Got It!'), findsOneWidget);

      await tester.tap(find.text('Got It!'));
      await tester.pumpAndSettle();

      expect(find.text('Hive Community Feed'), findsNothing);
    });

    testWidgets('renders entries guide correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ScreenGuideDialog.show(context, ScreenGuideType.entries),
                child: const Text('Open Entries Guide'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Entries Guide'));
      await tester.pumpAndSettle();

      expect(find.text('ENTRIES & WATCHLIST'), findsOneWidget);
      expect(find.text('Your Entertainment Sanctuary'), findsOneWidget);
      expect(find.text('Currently Watching'), findsOneWidget);
      expect(find.text('Watched Diary & History'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    });

    testWidgets('renders search guide correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ScreenGuideDialog.show(context, ScreenGuideType.search),
                child: const Text('Open Search Guide'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Search Guide'));
      await tester.pumpAndSettle();

      expect(find.text('EXPLORE & SEARCH'), findsOneWidget);
      expect(find.text('Discover Movies, Shows & Friends'), findsOneWidget);
      expect(find.text('Universal Media Search'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    });

    testWidgets('renders profile guide with replay tour button when userId is provided', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ScreenGuideDialog.show(
                    context,
                    ScreenGuideType.profile,
                    userId: 'test_user_123',
                  ),
                  child: const Text('Open Profile Guide'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Profile Guide'));
      await tester.pumpAndSettle();

      expect(find.text('PROFILE & MILESTONES'), findsOneWidget);
      expect(find.text('Your Cinema Identity & Stats'), findsOneWidget);
      expect(find.text('Replay Full App Tour'), findsOneWidget);
    });

    testWidgets('closes dialog when close icon button is tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ScreenGuideDialog.show(context, ScreenGuideType.movieDetails),
                child: const Text('Open Movie Guide'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Movie Guide'));
      await tester.pumpAndSettle();

      expect(find.text('TITLE DETAILS'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('TITLE DETAILS'), findsNothing);
    });
  });
}
