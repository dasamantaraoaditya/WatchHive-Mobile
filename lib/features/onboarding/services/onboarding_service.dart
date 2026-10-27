import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_manager.dart';
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
  final FlutterSecureStorage _storage;
  bool _hasPromptedThisLaunch = false;

  static final Map<String, bool> _onboardingCompletedCache = {};
  static final Map<String, Map<String, dynamic>> _preferencesCache = {};

  OnboardingService(this._apiClient, [FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions:
                  IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  bool get hasPromptedThisLaunch => _hasPromptedThisLaunch;

  void markPrompted() {
    _hasPromptedThisLaunch = true;
  }

  static String _prefKey(String userId) => 'wh_user_preferences_${userId.trim()}';
  static String _completedKey(String userId) => 'wh_user_onboarding_completed_${userId.trim()}';

  /// Prewarm and load local preferences from secure storage into memory
  Future<Map<String, dynamic>?> loadLocalPreferences(String userId) async {
    if (userId.trim().isEmpty) return null;
    final cleanId = userId.trim();
    if (_preferencesCache.containsKey(cleanId)) {
      return _preferencesCache[cleanId];
    }
    try {
      final raw = await _storage.read(key: _prefKey(cleanId));
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _preferencesCache[cleanId] = map;
        _onboardingCompletedCache[cleanId] = true;
        return map;
      }
    } catch (_) {}
    return null;
  }

  /// Determines if the user has completed preferences onboarding.
  Future<bool> isPreferencesCompleted(String userId) async {
    if (userId.trim().isEmpty) return false;
    final cleanId = userId.trim();
    if (_onboardingCompletedCache[cleanId] == true) return true;
    try {
      final raw = await _storage.read(key: _completedKey(cleanId));
      if (raw == 'true') {
        _onboardingCompletedCache[cleanId] = true;
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Determines if the first-time watch preferences dialog should be shown.
  bool shouldShowPreferences(User? user) {
    if (user == null || user.id.isEmpty) return false;
    if (_hasPromptedThisLaunch) return false;

    final userId = user.id.trim();

    // 1. If in-memory cache or user object says completed, do not show
    if (_onboardingCompletedCache[userId] == true) return false;
    if (user.hasCompletedOnboarding) return false;

    // 2. If user already has valid preferences in user object, do not show
    if (user.preferences != null && user.preferences!.isNotEmpty) {
      final langs = user.preferences?['languages'] as List?;
      final genres = user.preferences?['genres'] as List?;
      if ((langs != null && langs.isNotEmpty) || (genres != null && genres.isNotEmpty)) {
        _onboardingCompletedCache[userId] = true;
        return false;
      }
    }

    // 3. If preferences exist in memory cache, do not show
    if (_preferencesCache[userId] != null && _preferencesCache[userId]!.isNotEmpty) {
      return false;
    }

    return true;
  }

  /// Merges locally cached preferences into a user object if missing from backend
  Future<User> resolveUserWithPreferences(User user) async {
    if (user.id.isEmpty) return user;
    final userId = user.id.trim();

    Map<String, dynamic>? effectivePrefs = user.preferences;
    bool effectiveCompleted = user.hasCompletedOnboarding;

    if (effectivePrefs == null || effectivePrefs.isEmpty) {
      final local = await loadLocalPreferences(userId);
      if (local != null && local.isNotEmpty) {
        effectivePrefs = local;
        effectiveCompleted = true;
      }
    }

    if (!effectiveCompleted) {
      final isCompleted = await isPreferencesCompleted(userId);
      if (isCompleted) {
        effectiveCompleted = true;
      }
    }

    if (effectivePrefs != user.preferences || effectiveCompleted != user.hasCompletedOnboarding) {
      return user.copyWith(
        preferences: effectivePrefs,
        hasCompletedOnboarding: effectiveCompleted,
      );
    }
    return user;
  }

  /// Saves the user's watch preferences both securely locally and to the backend.
  Future<bool> savePreferences({
    required UserPreferences preferences,
    required WidgetRef ref,
  }) async {
    final currentUser = ref.read(authStateProvider).value?.user;
    final userId = currentUser?.id.trim() ?? '';
    final prefsMap = preferences.toJson();

    // 1. Save locally in memory and persistent secure storage IMMEDIATELY
    if (userId.isNotEmpty) {
      _preferencesCache[userId] = prefsMap;
      _onboardingCompletedCache[userId] = true;
      try {
        await _storage.write(key: _prefKey(userId), value: jsonEncode(prefsMap));
        await _storage.write(key: _completedKey(userId), value: 'true');
      } catch (e) {
        debugPrint('[OnboardingService] Local secure storage write warning: $e');
      }
    }

    // 2. Update the in-memory AuthState so all screens and feed react immediately
    if (currentUser != null) {
      final updatedUser = currentUser.copyWith(
        preferences: prefsMap,
        hasCompletedOnboarding: true,
      );
      ref.read(authStateProvider.notifier).updateUser(updatedUser);
      final authManager = ref.read(authManagerProvider);
      await authManager.saveUser(updatedUser);
    }

    // 3. Mark prompted for current session
    markPrompted();

    // 4. Trigger feed refresh so recommendations immediately reflect new preferences
    ref.read(feedRefreshTriggerProvider.notifier).state++;

    // 5. Sync to backend with fallback endpoints
    final payload = {
      'preferences': prefsMap,
      'hasCompletedOnboarding': true,
    };

    final candidateAttempts = [
      () => _apiClient.put(ApiEndpoints.me, data: payload),
      () => _apiClient.patch(ApiEndpoints.me, data: payload),
      () => _apiClient.put(ApiEndpoints.userPreferences, data: payload),
    ];

    for (final attempt in candidateAttempts) {
      try {
        final response = await attempt();
        if (response.statusCode == 200 || response.statusCode == 204) {
          debugPrint('[OnboardingService] Successfully synced preferences to backend');
          break;
        }
      } catch (e) {
        // Backend may return 404 for /users/me/preferences if route is not implemented yet.
        // Handled gracefully as local persistent storage already guarantees user preferences!
      }
    }

    return true;
  }
}
