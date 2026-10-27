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
    test('contains 8 curated steps covering the complete user journey', () {
      const steps = InteractiveOnboardingStep.steps;
      expect(steps.length, equals(8));

      // 1. Feed
      expect(steps[0].stepBadge, contains('COMMUNITY FEED'));
      expect(steps[0].route, equals('/feed'));
      expect(steps[0].title, contains('Community & Feed'));

      // 2. First Watch Entry
      expect(steps[1].stepBadge, contains('FIRST WATCH ENTRY'));
      expect(steps[1].secondaryActionLabel, isNotNull);
      expect(steps[1].secondaryActionLabel, contains('Log a Movie Now'));

      // 3. Quick Add FAB
      expect(steps[2].stepBadge, contains('QUICK SHORTCUT'));
      expect(steps[2].title, contains('Quick Add'));

      // 4. Entries Vault
      expect(steps[3].stepBadge, contains('ENTRIES & VAULT'));
      expect(steps[3].route, equals('/entries'));

      // 5. Friend Suggestions
      expect(steps[4].stepBadge, contains('FRIEND SUGGESTIONS'));
      expect(steps[4].route, contains('suggestions'));

      // 6. Rankings & Stacks
      expect(steps[5].stepBadge, contains('RANKINGS & STACKS'));
      expect(steps[5].route, contains('rankings'));

      // 7. Data Migration & Privacy
      expect(steps[6].stepBadge, contains('DATA MIGRATION & PRIVACY'));
      expect(steps[6].route, equals('/profile'));
      expect(steps[6].description, contains('Letterboxd'));

      // 8. Discover Friends & Search
      expect(steps[7].stepBadge, contains('DISCOVER & CONNECT'));
      expect(steps[7].route, equals('/search'));
      expect(steps[7].primaryActionLabel, contains('Finish'));
    });
  });

  group('OnboardingGuideNotifier State Tests', () {
    test('transitions through steps and dismisses when tour is completed', () async {
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
      expect(notifier.state.currentStep.title, contains('Community & Feed'));
      expect(notifier.state.isLastStep, isFalse);

      // Advance to step 1
      notifier.state = notifier.state.copyWith(currentStepIndex: 1);
      expect(notifier.state.currentStep.title, contains('Record What You Have Watched'));

      // Advance to last step (step 7)
      notifier.state = notifier.state.copyWith(currentStepIndex: 7);
      expect(notifier.state.isLastStep, isTrue);
      expect(notifier.state.currentStep.title, contains('Find Friends'));

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
      expect(find.text('STEP 1 OF 8 · COMMUNITY FEED'), findsOneWidget);
      expect(find.text('Your Hive Community & Feed'), findsOneWidget);
      expect(find.text('Skip Tour'), findsOneWidget);

      // Tap Skip Tour
      await tester.tap(find.text('Skip Tour'));
      await tester.pumpAndSettle();

      // Overlay should be dismissed
      expect(find.text('STEP 1 OF 8 · COMMUNITY FEED'), findsNothing);
      expect(container.read(onboardingGuideProvider).isActive, isFalse);
    });
  });
}
