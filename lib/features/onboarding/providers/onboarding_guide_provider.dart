import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/interactive_onboarding_step.dart';
import '../services/tour_service.dart';
import '../services/onboarding_service.dart';
import '../widgets/watch_preferences_onboarding_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../entries/screens/add_entry_sheet.dart';

class OnboardingGuideState {
  final bool isActive;
  final int currentStepIndex;
  final String userId;
  final bool isReplay;
  final bool hasStartedThisSession;

  const OnboardingGuideState({
    this.isActive = false,
    this.currentStepIndex = 0,
    this.userId = '',
    this.isReplay = false,
    this.hasStartedThisSession = false,
  });

  InteractiveOnboardingStep get currentStep {
    const steps = InteractiveOnboardingStep.steps;
    if (currentStepIndex >= 0 && currentStepIndex < steps.length) {
      return steps[currentStepIndex];
    }
    return steps.first;
  }

  bool get isLastStep =>
      currentStepIndex >= InteractiveOnboardingStep.steps.length - 1;

  OnboardingGuideState copyWith({
    bool? isActive,
    int? currentStepIndex,
    String? userId,
    bool? isReplay,
    bool? hasStartedThisSession,
  }) {
    return OnboardingGuideState(
      isActive: isActive ?? this.isActive,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      userId: userId ?? this.userId,
      isReplay: isReplay ?? this.isReplay,
      hasStartedThisSession:
          hasStartedThisSession ?? this.hasStartedThisSession,
    );
  }
}

class OnboardingGuideNotifier extends StateNotifier<OnboardingGuideState> {
  final TourService _tourService;
  final Ref? _ref;

  OnboardingGuideNotifier(this._tourService, [this._ref])
      : super(const OnboardingGuideState());

  /// Starts the interactive guided tour for the given user.
  void startTour(BuildContext context,
      {required String userId, bool isReplay = false}) {
    // Prevent re-entry / infinite loop when screens remount during navigation
    if (!isReplay && (state.isActive || state.hasStartedThisSession)) {
      return;
    }

    state = OnboardingGuideState(
      isActive: true,
      currentStepIndex: 0,
      userId: userId,
      isReplay: isReplay,
      hasStartedThisSession: true,
    );

    // Mark completed immediately on start so route changes back to /feed never
    // re-trigger the automatic first-time tour.
    if (userId.isNotEmpty && !isReplay) {
      _tourService.markTourCompleted(userId);
    }

    // Navigate to step 1 route if not already there
    final firstRoute = InteractiveOnboardingStep.steps.first.route;
    final currentLocation = GoRouterState.of(context).matchedLocation;
    if (currentLocation != firstRoute) {
      context.go(firstRoute);
    }
  }

  /// Advances to the next step and navigates to the target route if needed.
  void nextStep(BuildContext context) {
    if (state.isLastStep) {
      dismissTour(context: context, returnToFeed: true);
      return;
    }

    final currentRoute = state.currentStep.route;
    final nextIndex = state.currentStepIndex + 1;
    state = state.copyWith(currentStepIndex: nextIndex);

    final nextRoute = InteractiveOnboardingStep.steps[nextIndex].route;
    if (nextRoute != currentRoute) {
      context.go(nextRoute);
    }
  }

  /// Moves back to the previous step.
  void previousStep(BuildContext context) {
    if (state.currentStepIndex <= 0) return;

    final currentRoute = state.currentStep.route;
    final prevIndex = state.currentStepIndex - 1;
    state = state.copyWith(currentStepIndex: prevIndex);

    final prevRoute = InteractiveOnboardingStep.steps[prevIndex].route;
    if (prevRoute != currentRoute) {
      context.go(prevRoute);
    }
  }

  /// Jumps to a specific step.
  void goToStep(BuildContext context, int stepIndex) {
    const steps = InteractiveOnboardingStep.steps;
    if (stepIndex < 0 || stepIndex >= steps.length) return;

    final currentRoute = state.currentStep.route;
    state = state.copyWith(currentStepIndex: stepIndex);

    final targetRoute = steps[stepIndex].route;
    if (targetRoute != currentRoute) {
      context.go(targetRoute);
    }
  }

  /// Dismisses and marks the tour completed.
  /// After onboarding is done, prompts preferences if the user hasn't set them yet.
  Future<void> dismissTour({
    BuildContext? context,
    bool returnToFeed = false,
  }) async {
    final userId = state.userId;
    state = state.copyWith(isActive: false, hasStartedThisSession: true);

    if (userId.isNotEmpty) {
      await _tourService.markTourCompleted(userId);
    }

    if (returnToFeed && context != null && context.mounted) {
      context.go('/feed');
    }

    // Preferences should only come after the onboarding is done!
    if (context != null && context.mounted && userId.isNotEmpty) {
      try {
        final onboardingService = _ref?.read(onboardingServiceProvider);
        final user = _ref?.read(authStateProvider).value?.user;
        if (onboardingService != null) {
          final shouldPrompt = await onboardingService.shouldPromptUser(user);
          if (shouldPrompt && context.mounted) {
            onboardingService.markPrompted(userId);
            await WatchPreferencesOnboardingDialog.show(context);
            await onboardingService.markPreferencesCompleted(userId);
          }
        }
      } catch (e) {
        debugPrint('[OnboardingGuideNotifier] Post-onboarding preferences error: $e');
      }
    }
  }

  /// Opens the Add Entry Sheet for the first watch log step.
  void openFirstWatchLogger(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddEntrySheet(),
    );
  }
}

final onboardingGuideProvider =
    StateNotifierProvider<OnboardingGuideNotifier, OnboardingGuideState>((ref) {
  final tourService = ref.read(tourServiceProvider);
  return OnboardingGuideNotifier(tourService, ref);
});
