import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_manager.dart';
import '../../../shared/models/user.dart';
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

    if (!hasSession) return const AuthState(isAuthenticated: false);

    try {
      final user = await ref.read(authRepositoryProvider).getMe();
      return AuthState(user: user, isAuthenticated: true);
    } catch (e) {
      // Only logout if explicitly unauthorized (401/403) and refresh failed
      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        await authManager.logout();
        return const AuthState(isAuthenticated: false);
      }
      // For network errors / connection drops / offline mode,
      // keep the user authenticated so saved tokens are never wiped!
      return const AuthState(isAuthenticated: true);
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
          );
      return AuthState(user: user, isAuthenticated: true);
    });
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authRepositoryProvider).register(
            username: username,
            email: email,
            password: password,
          );
      return AuthState(user: user, isAuthenticated: true);
    });
  }

  Future<void> googleSignIn(String idToken) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authRepositoryProvider).googleSignIn(idToken);
      return AuthState(user: user, isAuthenticated: true);
    });
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(AuthState(isAuthenticated: false));
  }

  void updateUser(User updatedUser) {
    state = AsyncData(
      state.value!.copyWith(user: updatedUser, isAuthenticated: true),
    );
  }
}
