import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../feed/providers/feed_provider.dart';
import '../models/user_preferences.dart';

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return OnboardingService(apiClient);
});

class OnboardingService {
  final ApiClient _apiClient;
  bool _hasPromptedThisLaunch = false;

  OnboardingService(this._apiClient);

  bool get hasPromptedThisLaunch => _hasPromptedThisLaunch;

  void markPrompted() {
    _hasPromptedThisLaunch = true;
  }

  /// Determines if the first-time watch preferences dialog should be shown.
  bool shouldShowPreferences(User? user) {
    if (user == null || user.id.isEmpty) return false;
    if (_hasPromptedThisLaunch) return false;

    // Show if the user has not completed onboarding
    if (!user.hasCompletedOnboarding) return true;

    // Or if preferences are empty
    if (user.preferences == null || user.preferences!.isEmpty) return true;

    final langs = user.preferences?['languages'] as List?;
    final genres = user.preferences?['genres'] as List?;
    if ((langs == null || langs.isEmpty) && (genres == null || genres.isEmpty)) {
      return true;
    }

    return false;
  }

  /// Saves the user's watch preferences and marks onboarding as completed.
  Future<bool> savePreferences({
    required UserPreferences preferences,
    required WidgetRef ref,
  }) async {
    try {
      final response = await _apiClient.put(
        ApiEndpoints.userPreferences,
        data: {
          'preferences': preferences.toJson(),
          'hasCompletedOnboarding': true,
        },
      );

      if (response.statusCode == 200) {
        final currentUser = ref.read(authStateProvider).value?.user;
        if (currentUser != null) {
          final updatedUser = currentUser.copyWith(
            preferences: preferences.toJson(),
            hasCompletedOnboarding: true,
          );
          ref.read(authStateProvider.notifier).updateUser(updatedUser);
        }

        // Trigger feed refresh so recommendations immediately reflect new preferences
        ref.read(feedRefreshTriggerProvider.notifier).state++;
        return true;
      }
    } catch (e) {
      debugPrint('[OnboardingService] Error saving watch preferences: $e');
    }
    return false;
  }
}
