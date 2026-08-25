import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../shared/widgets/app_shell.dart';
import '../../features/feed/screens/feed_screen.dart';
import '../../features/entries/screens/entries_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/user_profile_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/entries/screens/movie_details_screen.dart';
import '../../features/mindlens/screens/mindlens_screen.dart';
import '../../features/profile/screens/compare_history_screen.dart';
import '../../shared/models/user.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) => RouterNotifier(ref));

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuthenticated = authState.value?.isAuthenticated ?? false;
      final isLoading = authState.isLoading;

      if (isLoading) return null;

      final isSplash = state.matchedLocation == '/splash';
      final isAuthPage = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/signup') ||
          state.matchedLocation.startsWith('/forgot-password');

      if (!isAuthenticated && !isAuthPage && !isSplash) return '/login';
      if (isAuthenticated && (isAuthPage || isSplash)) return '/feed';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      // Shell route with bottom nav matching Web App (Home, MindLens, Entries, Search, Profile)
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/feed',
            builder: (context, state) => const FeedScreen(),
          ),
          GoRoute(
            path: '/mindlens',
            builder: (context, state) => const MindLensScreen(),
          ),
          GoRoute(
            path: '/entries',
            builder: (context, state) => const EntriesScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      // Full-screen routes (no bottom nav)
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/compare/:id',
        builder: (context, state) => CompareHistoryScreen(
          userId: state.pathParameters['id']!,
          initialUser: state.extra as User?,
        ),
      ),
      GoRoute(
        path: '/profile/:id',
        builder: (context, state) => UserProfileScreen(
          userId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/details/:mediaType/:tmdbId',
        builder: (context, state) => MovieDetailsScreen(
          mediaType: state.pathParameters['mediaType']!,
          tmdbId: int.parse(state.pathParameters['tmdbId']!),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: Center(
        child: Text(
          'Page not found',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
});
