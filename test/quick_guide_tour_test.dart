import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/onboarding/models/tour_step.dart';
import 'package:watchhive_mobile/features/onboarding/services/tour_service.dart';
import 'package:watchhive_mobile/features/onboarding/widgets/quick_guide_tour_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('TourService Tests', () {
    test('shouldShowTour returns true for new user ID', () async {
      final service = TourService();
      final shouldShow = await service.shouldShowTour('user_abc_123');
      expect(shouldShow, isTrue);
    });

    test('shouldShowTour returns false for empty or blank user ID', () async {
      final service = TourService();
      expect(await service.shouldShowTour(''), isFalse);
      expect(await service.shouldShowTour('   '), isFalse);
    });

    test('markTourCompleted persists completion and changes shouldShowTour to false', () async {
      final service = TourService();
      const userId = 'new_user_456';

      expect(await service.shouldShowTour(userId), isTrue);
      expect(await service.isTourCompleted(userId), isFalse);

      await service.markTourCompleted(userId);

      expect(await service.shouldShowTour(userId), isFalse);
      expect(await service.isTourCompleted(userId), isTrue);
    });

    test('resetTour clears completion so shouldShowTour returns true again', () async {
      final service = TourService();
      const userId = 'reset_user_789';

      await service.markTourCompleted(userId);
      expect(await service.shouldShowTour(userId), isFalse);

      await service.resetTour(userId);
      expect(await service.shouldShowTour(userId), isTrue);
    });
  });

  group('TourStep Model Tests', () {
    test('defaultSteps contains 6 curated steps covering core features', () {
      final steps = TourStep.defaultSteps;
      expect(steps.length, equals(6));

      expect(steps[0].title, contains('Movie & TV Sanctuary'));
      expect(steps[1].badgeText, equals('COMMUNITY & BUZZ'));
      expect(steps[2].title, contains('MindLens AI'));
      expect(steps[3].title, contains('Entries, Watchlists'));
      expect(steps[4].badgeText, equals('CINEMATIC IDENTITY'));
      expect(steps[5].title, contains('Quick Add'));
    });
  });

  group('QuickGuideTourDialog Widget Tests', () {
    testWidgets('renders first slide with badge, title, dots, and Next button', (tester) async {
      const testUserId = 'test_widget_user';
      bool completed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => QuickGuideTourDialog.show(
                    context,
                    userId: testUserId,
                    onCompleted: () => completed = true,
                  ),
                  child: const Text('Open Tour'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open Tour'));
      await tester.pumpAndSettle();

      // Verify Step 1 content is visible
      expect(find.text('STEP 1 OF 6'), findsOneWidget);
      expect(find.text('WELCOME ABOARD'), findsOneWidget);
      expect(find.text('Your Ultimate Movie & TV Sanctuary'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next Step'), findsOneWidget);
      expect(find.text('Back'), findsNothing); // No Back button on first page

      // Advance to Step 2
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.text('STEP 2 OF 6'), findsOneWidget);
      expect(find.text('COMMUNITY & BUZZ'), findsOneWidget);
      expect(find.text('See What the World is Watching'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget); // Back button now visible

      // Tap Back button to return to Step 1
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('STEP 1 OF 6'), findsOneWidget);

      // Tap Skip to complete the tour
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Verify dialog is dismissed and completion recorded
      expect(find.text('STEP 1 OF 6'), findsNothing);
      expect(completed, isTrue);

      final service = TourService();
      expect(await service.isTourCompleted(testUserId), isTrue);
    });
  });
}
