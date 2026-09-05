import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/shared/widgets/wh_skeleton.dart';

void main() {
  group('WatchHive Skeleton System Tests', () {
    testWidgets('WHSkeletonMovieDetails renders successfully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WHSkeletonMovieDetails(),
        ),
      );

      expect(find.byType(WHSkeletonMovieDetails), findsOneWidget);
      expect(find.byType(WHSkeleton), findsOneWidget);
    });

    testWidgets('WHSkeletonGrid renders skeleton cards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WHSkeletonGrid(itemCount: 4),
          ),
        ),
      );

      expect(find.byType(WHSkeletonGrid), findsOneWidget);
      expect(find.byType(WHSkeletonCard), findsWidgets);
    });

    testWidgets('WHSkeletonEpisodeList renders episode items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WHSkeletonEpisodeList(count: 3),
          ),
        ),
      );

      expect(find.byType(WHSkeletonEpisodeList), findsOneWidget);
    });

    testWidgets('WHSkeletonFeed renders feed placeholders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WHSkeletonFeed(itemCount: 2),
          ),
        ),
      );

      expect(find.byType(WHSkeletonFeed), findsOneWidget);
    });

    testWidgets('WHSkeletonProfile renders profile placeholders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WHSkeletonProfile(),
        ),
      );

      expect(find.byType(WHSkeletonProfile), findsOneWidget);
    });

    testWidgets('WHSkeletonCommentsList renders comment rows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WHSkeletonCommentsList(count: 3),
          ),
        ),
      );

      expect(find.byType(WHSkeletonCommentsList), findsOneWidget);
      expect(find.byType(WHSkeleton), findsOneWidget);
    });

    testWidgets('WHSkeletonMindLens renders AI Persona and taste charts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WHSkeletonMindLens(),
          ),
        ),
      );

      expect(find.byType(WHSkeletonMindLens), findsOneWidget);
    });

    testWidgets('WHSkeletonRankings renders stack carousel and ranked cards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WHSkeletonRankings(),
          ),
        ),
      );

      expect(find.byType(WHSkeletonRankings), findsOneWidget);
    });

    testWidgets('WHSkeletonCompare renders dual avatars and comparison cards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WHSkeletonCompare(),
          ),
        ),
      );

      expect(find.byType(WHSkeletonCompare), findsOneWidget);
    });

    testWidgets('WHSkeletonUserList renders user rows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WHSkeletonUserList(count: 4),
          ),
        ),
      );

      expect(find.byType(WHSkeletonUserList), findsOneWidget);
    });

    testWidgets('WHSkeletonMediaSearchList renders media search result cards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WHSkeletonMediaSearchList(count: 3),
          ),
        ),
      );

      expect(find.byType(WHSkeletonMediaSearchList), findsOneWidget);
    });

    testWidgets('WHSkeletonSuggestedUsersHorizontal renders horizontal friends list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WHSkeletonSuggestedUsersHorizontal(),
          ),
        ),
      );

      expect(find.byType(WHSkeletonSuggestedUsersHorizontal), findsOneWidget);
    });

    testWidgets('WHSkeletonStackList renders stack items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WHSkeletonStackList(count: 3),
          ),
        ),
      );

      expect(find.byType(WHSkeletonStackList), findsOneWidget);
    });

    testWidgets('WHSkeletonFeedFooter renders pagination skeleton footer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WHSkeletonFeedFooter(),
          ),
        ),
      );

      expect(find.byType(WHSkeletonFeedFooter), findsOneWidget);
    });

    testWidgets('WHSkeletonProfileStats renders profile stats skeleton cards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WHSkeletonProfileStats(),
          ),
        ),
      );

      expect(find.byType(WHSkeletonProfileStats), findsOneWidget);
    });
  });
}
