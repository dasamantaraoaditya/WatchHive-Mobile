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
  });
}
