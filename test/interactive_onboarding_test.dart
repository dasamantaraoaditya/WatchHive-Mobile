import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/onboarding/models/interactive_onboarding_step.dart';
import 'package:watchhive_mobile/features/onboarding/providers/onboarding_guide_provider.dart';
import 'package:watchhive_mobile/features/onboarding/services/tour_service.dart';
import 'package:watchhive_mobile/features/onboarding/widgets/interactive_onboarding_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('InteractiveOnboardingStep Model Tests', () {
    test('contains 6 focused steps covering feed, quick add, log watch flow, entries, search, and profile', () {
      const steps = InteractiveOnboardingStep.steps;
      expect(steps.length, equals(6));

      // 1. Hive Feed (Home Tab)
      expect(steps[0].stepBadge, contains('STEP 1 OF 6'));
      expect(steps[0].route, equals('/feed'));
      expect(steps[0].target, equals(OnboardingTarget.homeTab));

      // 2. Quick Add (+)
      expect(steps[1].stepBadge, contains('STEP 2 OF 6'));
      expect(steps[1].route, equals('/feed'));
      expect(steps[1].target, equals(OnboardingTarget.quickAddFab));

      // 3. Log a Watch Flow
      expect(steps[2].stepBadge, contains('STEP 3 OF 6'));
      expect(steps[2].route, equals('/feed'));
      expect(steps[2].target, equals(OnboardingTarget.logWatchFlow));
      expect(steps[2].subSteps.length, equals(5));
      expect(steps[2].secondaryActionLabel, equals('Try Logging Now'));

      // 4. Entries & Watchlist
      expect(steps[3].stepBadge, contains('STEP 4 OF 6'));
      expect(steps[3].route, equals('/entries'));
      expect(steps[3].target, equals(OnboardingTarget.entriesTab));

      // 5. Search Friends
      expect(steps[4].stepBadge, contains('STEP 5 OF 6'));
      expect(steps[4].route, equals('/search'));
      expect(steps[4].target, equals(OnboardingTarget.searchTab));

      // 6. Manage Profile
      expect(steps[5].stepBadge, contains('STEP 6 OF 6'));
      expect(steps[5].route, equals('/profile'));
      expect(steps[5].target, equals(OnboardingTarget.profileTab));
      expect(steps[5].primaryActionLabel, contains('Get Started'));
    });
  });

  group('OnboardingGuideNotifier State Tests', () {
    test('transitions through 6 steps, sets hasStartedThisSession, and dismisses cleanly', () async {
      final tourService = TourService();
      final notifier = OnboardingGuideNotifier(tourService);

      expect(notifier.state.isActive, isFalse);
      expect(notifier.state.currentStepIndex, 0);
      expect(notifier.state.hasStartedThisSession, isFalse);

      // Start tour state
      notifier.state = const OnboardingGuideState(
        isActive: true,
        currentStepIndex: 0,
        userId: 'test_user_789',
        hasStartedThisSession: true,
      );

      expect(notifier.state.isActive, isTrue);
      expect(notifier.state.hasStartedThisSession, isTrue);
      expect(notifier.state.currentStep.title, contains('Social Cinema Feed'));
      expect(notifier.state.isLastStep, isFalse);

      // Step 2 (Log Watch Flow)
      notifier.state = notifier.state.copyWith(currentStepIndex: 2);
      expect(notifier.state.currentStep.title, contains('How to Log a Watch'));
      expect(notifier.state.isLastStep, isFalse);

      // Advance to last step (step 5)
      notifier.state = notifier.state.copyWith(currentStepIndex: 5);
      expect(notifier.state.isLastStep, isTrue);
      expect(notifier.state.currentStep.title, contains('Manage Your Profile'));

      // Dismiss tour
      await notifier.dismissTour();
      expect(notifier.state.isActive, isFalse);
      expect(notifier.state.hasStartedThisSession, isTrue);

      // Verification of completion in storage
      final isCompleted = await tourService.isTourCompleted('test_user_789');
      expect(isCompleted, isTrue);
    });
  });

  group('InteractiveOnboardingOverlay Widget Tests', () {
    testWidgets('renders Step 1, Step 3 (5-step Log Watch), and responds to Skip', (tester) async {
      final tourService = TourService();
      final container = ProviderContainer(
        overrides: [
          tourServiceProvider.overrideWithValue(tourService),
        ],
      );

      // Initialize tour as active at Step 1
      container.read(onboardingGuideProvider.notifier).state = const OnboardingGuideState(
        isActive: true,
        currentStepIndex: 0,
        userId: 'widget_user_1',
        hasStartedThisSession: true,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(
                child: Stack(
                  children: [
                    Text('App Background Content'),
                    InteractiveOnboardingOverlay(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Step 1 is rendered
      expect(find.text('STEP 1 OF 6 · THE HIVE FEED'), findsOneWidget);
      expect(find.text('See Your Social Cinema Feed'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Jump to Step 3 (Log a Watch Flow)
      container.read(onboardingGuideProvider.notifier).state =
          container.read(onboardingGuideProvider).copyWith(currentStepIndex: 2);
      await tester.pumpAndSettle();

      expect(find.text('STEP 3 OF 6 · LOG A WATCH'), findsOneWidget);
      expect(find.text('How to Log a Watch'), findsOneWidget);
      expect(find.text('Try Logging Now'), findsOneWidget);

      // Tap Skip
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Overlay should be dismissed
      expect(find.text('STEP 3 OF 6 · LOG A WATCH'), findsNothing);
      expect(container.read(onboardingGuideProvider).isActive, isFalse);
    });

    testWidgets('renders without overflow on compact mobile screens (320x568)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final tourService = TourService();
      final container = ProviderContainer(
        overrides: [
          tourServiceProvider.overrideWithValue(tourService),
        ],
      );

      container.read(onboardingGuideProvider.notifier).state = const OnboardingGuideState(
        isActive: true,
        currentStepIndex: 2, // tallest card (5 sub-steps)
        userId: 'compact_user',
        hasStartedThisSession: true,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(
                child: Stack(
                  children: [
                    Text('Background'),
                    InteractiveOnboardingOverlay(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('How to Log a Watch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
