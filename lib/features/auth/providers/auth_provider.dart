import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_manager.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../shared/models/user.dart';
import '../../notifications/repositories/push_repository.dart';
import '../../profile/repositories/user_repository.dart';
import '../../onboarding/services/onboarding_service.dart';
import '../repositories/auth_repository.dart';

// Auth state model
class AuthState {
  final User? user;
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
  }) =>
      AuthState(
        user: user ?? this.user,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// Async state provider that initializes auth on app start
final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final authManager = ref.read(authManagerProvider);
    final hasSession = await authManager.hasValidSession();

    // Listen to token refresh events throughout the notifier lifecycle
    final tokenSubscription =
        PushNotificationService.instance.onTokenRefresh.listen((token) async {
      final auth = state.value;
      if (auth != null && auth.isAuthenticated && token.isNotEmpty) {
        debugPrint('[AuthNotifier] Token refreshed/retrieved, registering to backend...');
        try {
          await ref.read(pushRepositoryProvider).registerDeviceToken(token);
        } catch (e) {
          debugPrint('[AuthNotifier] Failed to sync refreshed token: $e');
        }
      }
    });
    ref.onDispose(() {
      tokenSubscription.cancel();
    });

    if (!hasSession) return const AuthState(isAuthenticated: false);

    // 1. Fast Path: If we have a cached user profile, restore session IMMEDIATELY (<15ms)
    final cachedUser = await authManager.getCachedUser();
    if (cachedUser != null) {
      final resolvedUser = await ref
          .read(onboardingServiceProvider)
          .resolveUserWithPreferences(cachedUser);
      // Optimistic instant auth! User enters app immediately.
      // Refresh profile & follow stats in the background, and verify session validity.
      unawaited(_refreshUserInBackground());
      return AuthState(user: resolvedUser, isAuthenticated: true);
    }

    // 2. Fallback Path: Tokens exist but no cached user (e.g. app upgrade or storage reset)
    try {
      final user = await ref.read(authRepositoryProvider).getMe();
      final resolvedUser = await ref
          .read(onboardingServiceProvider)
          .resolveUserWithPreferences(user);
      await authManager.saveUser(resolvedUser);
      unawaited(syncDeviceToken());
      return AuthState(user: resolvedUser, isAuthenticated: true);
    } catch (e) {
      // Only logout if explicitly unauthorized (401/403) and refresh failed
      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        await authManager.logout();
        return const AuthState(isAuthenticated: false);
      }
      // For network errors / connection drops / offline mode,
      // keep the user authenticated so saved tokens are never wiped!
      unawaited(syncDeviceToken());
      return const AuthState(isAuthenticated: true);
    }
  }

  Future<void> _refreshUserInBackground() async {
    final authManager = ref.read(authManagerProvider);
    try {
      final user = await ref.read(authRepositoryProvider).getMe();
      final resolvedUser = await ref
          .read(onboardingServiceProvider)
          .resolveUserWithPreferences(user);
      await authManager.saveUser(resolvedUser);
      state = AsyncData(
        state.value?.copyWith(user: resolvedUser, isAuthenticated: true) ??
            AuthState(user: resolvedUser, isAuthenticated: true),
      );
      unawaited(syncDeviceToken());
    } catch (e) {
      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        await authManager.logout();
        state = const AsyncData(AuthState(isAuthenticated: false));
      } else {
        unawaited(syncDeviceToken());
      }
    }
  }

  Future<void> syncDeviceToken() async {
    try {
      final token = await PushNotificationService.instance.getOrFetchToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[AuthNotifier] Syncing FCM device token with backend...');
        await ref.read(pushRepositoryProvider).registerDeviceToken(token);
      }
    } catch (e) {
      debugPrint('[AuthNotifier] Token sync skipped or failed: $e');
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      final user = await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
          );
      unawaited(syncDeviceToken());
      state = AsyncData(AuthState(user: user, isAuthenticated: true));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await ref.read(authRepositoryProvider).register(
            username: username,
            email: email,
            password: password,
          );
      unawaited(syncDeviceToken());
      state = AsyncData(AuthState(user: user, isAuthenticated: true));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> googleSignIn(String idToken) async {
    state = const AsyncLoading();
    try {
      final user = await ref.read(authRepositoryProvider).googleSignIn(idToken);
      unawaited(syncDeviceToken());
      state = AsyncData(AuthState(user: user, isAuthenticated: true));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> appleSignIn({
    required String identityToken,
    required String userIdentifier,
    String? email,
    String? givenName,
    String? familyName,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await ref.read(authRepositoryProvider).appleSignIn(
            identityToken: identityToken,
            userIdentifier: userIdentifier,
            email: email,
            givenName: givenName,
            familyName: familyName,
          );
      unawaited(syncDeviceToken());
      state = AsyncData(AuthState(user: user, isAuthenticated: true));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    final token = PushNotificationService.instance.currentToken;
    if (token != null && token.isNotEmpty) {
      try {
        await ref.read(pushRepositoryProvider).unregisterDeviceToken(token);
      } catch (_) {}
    }
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(AuthState(isAuthenticated: false));
  }

  Future<void> deleteAccount() async {
    final token = PushNotificationService.instance.currentToken;
    if (token != null && token.isNotEmpty) {
      try {
        await ref.read(pushRepositoryProvider).unregisterDeviceToken(token);
      } catch (_) {}
    }
    await ref.read(userRepositoryProvider).deleteAccount();
    await ref.read(authManagerProvider).logout();
    state = const AsyncData(AuthState(isAuthenticated: false));
  }

  void updateUser(User updatedUser) {
    unawaited(ref.read(authManagerProvider).saveUser(updatedUser));
    state = AsyncData(
      state.value!.copyWith(user: updatedUser, isAuthenticated: true),
    );
  }
}
