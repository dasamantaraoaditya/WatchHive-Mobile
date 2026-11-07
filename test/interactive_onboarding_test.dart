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
    test('contains 3 focused steps covering the essential value journey', () {
      const steps = InteractiveOnboardingStep.steps;
      expect(steps.length, equals(3));

      // 1. Quick Log (+) Focus
      expect(steps[0].stepBadge, contains('QUICK LOG'));
      expect(steps[0].route, equals('/feed'));
      expect(steps[0].title, contains('Track What You Watch'));
      expect(steps[0].target, equals(OnboardingTarget.quickAddFab));
      expect(steps[0].secondaryActionLabel, isNotNull);
      expect(steps[0].secondaryActionLabel, contains('Try Logging Now'));

      // 2. Entries & Watchlist Focus
      expect(steps[1].stepBadge, contains('ENTRIES & WATCHLIST'));
      expect(steps[1].route, equals('/entries'));
      expect(steps[1].title, contains('Your Watchlist & History'));
      expect(steps[1].target, equals(OnboardingTarget.entriesTab));

      // 3. Discover & Connect Focus
      expect(steps[2].stepBadge, contains('DISCOVER & CONNECT'));
      expect(steps[2].route, equals('/feed'));
      expect(steps[2].title, contains('Discover & Share'));
      expect(steps[2].target, equals(OnboardingTarget.feedCommunity));
      expect(steps[2].primaryActionLabel, contains('Personalize'));
    });
  });

  group('OnboardingGuideNotifier State Tests', () {
    test('transitions through 3 steps and dismisses when tour is completed', () async {
      final tourService = TourService();
      final notifier = OnboardingGuideNotifier(tourService);

      expect(notifier.state.isActive, isFalse);
      expect(notifier.state.currentStepIndex, 0);

      // Start tour
      notifier.state = const OnboardingGuideState(
        isActive: true,
        currentStepIndex: 0,
        userId: 'test_user_789',
      );

      expect(notifier.state.isActive, isTrue);
      expect(notifier.state.currentStep.title, contains('Track What You Watch'));
      expect(notifier.state.isLastStep, isFalse);

      // Advance to step 1
      notifier.state = notifier.state.copyWith(currentStepIndex: 1);
      expect(notifier.state.currentStep.title, contains('Your Watchlist & History'));
      expect(notifier.state.isLastStep, isFalse);

      // Advance to last step (step 2)
      notifier.state = notifier.state.copyWith(currentStepIndex: 2);
      expect(notifier.state.isLastStep, isTrue);
      expect(notifier.state.currentStep.title, contains('Discover & Share'));

      // Dismiss tour
      await notifier.dismissTour();
      expect(notifier.state.isActive, isFalse);

      // Verification of completion in storage
      final isCompleted = await tourService.isTourCompleted('test_user_789');
      expect(isCompleted, isTrue);
    });
  });

  group('InteractiveOnboardingOverlay Widget Tests', () {
    testWidgets('renders overlay when guide is active and responds to skip', (tester) async {
      final tourService = TourService();
      final container = ProviderContainer(
        overrides: [
          tourServiceProvider.overrideWithValue(tourService),
        ],
      );

      // Initialize tour as active
      container.read(onboardingGuideProvider.notifier).state = const OnboardingGuideState(
        isActive: true,
        currentStepIndex: 0,
        userId: 'widget_user_1',
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
      expect(find.text('STEP 1 OF 3 · QUICK LOG'), findsOneWidget);
      expect(find.text('Track What You Watch'), findsOneWidget);
      expect(find.text('Skip Tour'), findsOneWidget);

      // Tap Skip Tour
      await tester.tap(find.text('Skip Tour'));
      await tester.pumpAndSettle();

      // Overlay should be dismissed
      expect(find.text('STEP 1 OF 3 · QUICK LOG'), findsNothing);
      expect(container.read(onboardingGuideProvider).isActive, isFalse);
    });
  });
}
