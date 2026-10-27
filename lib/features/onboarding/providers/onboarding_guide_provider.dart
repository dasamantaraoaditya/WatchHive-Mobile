import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/interactive_onboarding_step.dart';
import '../services/tour_service.dart';
import '../../entries/screens/add_entry_sheet.dart';

class OnboardingGuideState {
  final bool isActive;
  final int currentStepIndex;
  final String userId;
  final bool isReplay;

  const OnboardingGuideState({
    this.isActive = false,
    this.currentStepIndex = 0,
    this.userId = '',
    this.isReplay = false,
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
  }) {
    return OnboardingGuideState(
      isActive: isActive ?? this.isActive,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      userId: userId ?? this.userId,
      isReplay: isReplay ?? this.isReplay,
    );
  }
}

class OnboardingGuideNotifier extends StateNotifier<OnboardingGuideState> {
  final TourService _tourService;

  OnboardingGuideNotifier(this._tourService)
      : super(const OnboardingGuideState());

  /// Starts the interactive guided tour for the given user.
  void startTour(BuildContext context,
      {required String userId, bool isReplay = false}) {
    state = OnboardingGuideState(
      isActive: true,
      currentStepIndex: 0,
      userId: userId,
      isReplay: isReplay,
    );

    // Navigate to step 1 route
    final firstRoute = InteractiveOnboardingStep.steps.first.route;
    context.go(firstRoute);
  }

  /// Advances to the next step and navigates to the target route.
  void nextStep(BuildContext context) {
    if (state.isLastStep) {
      dismissTour(context: context);
      return;
    }

    final nextIndex = state.currentStepIndex + 1;
    state = state.copyWith(currentStepIndex: nextIndex);

    final nextStep = InteractiveOnboardingStep.steps[nextIndex];
    context.go(nextStep.route);
  }

  /// Moves back to the previous step.
  void previousStep(BuildContext context) {
    if (state.currentStepIndex <= 0) return;

    final prevIndex = state.currentStepIndex - 1;
    state = state.copyWith(currentStepIndex: prevIndex);

    final prevStep = InteractiveOnboardingStep.steps[prevIndex];
    context.go(prevStep.route);
  }

  /// Jumps to a specific step.
  void goToStep(BuildContext context, int stepIndex) {
    const steps = InteractiveOnboardingStep.steps;
    if (stepIndex < 0 || stepIndex >= steps.length) return;

    state = state.copyWith(currentStepIndex: stepIndex);
    context.go(steps[stepIndex].route);
  }

  /// Dismisses and marks the tour completed.
  Future<void> dismissTour({BuildContext? context}) async {
    final userId = state.userId;
    state = state.copyWith(isActive: false);

    if (userId.isNotEmpty) {
      await _tourService.markTourCompleted(userId);
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
  return OnboardingGuideNotifier(tourService);
});
