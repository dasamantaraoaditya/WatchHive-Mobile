import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
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
import '../../features/rankings/screens/rankings_screen.dart';
import '../../features/profile/screens/privacy_policy_screen.dart';
import '../../features/support/screens/support_screen.dart';
import '../../shared/models/user.dart';
import '../../shared/models/entry.dart';
import '../../features/entries/screens/entry_detail_screen.dart';
import '../../features/scanner/screens/hive_scanner_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) => RouterNotifier(ref));

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoading = authState.isLoading;
      final isAuthenticated = authState.value?.isAuthenticated ?? false;

      final isSplash = state.matchedLocation == '/splash';
      final isAuthPage = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/signup') ||
          state.matchedLocation.startsWith('/forgot-password');
      final isPublicPage = isAuthPage ||
          state.matchedLocation.startsWith('/privacy-policy') ||
          state.matchedLocation.startsWith('/support');

      // 1. If currently on splash screen:
      if (isSplash) {
        // While still resolving initial session / auto-login, STAY on splash screen
        if (isLoading) return null;
        // Once resolved, go to /feed if authenticated, or /login if not
        return isAuthenticated ? '/feed' : '/login';
      }

      // 2. If session restore is in flight and user is on a protected route:
      if (isLoading && !isPublicPage) {
        return '/splash';
      }

      // 3. User is not authenticated and attempting to view a protected page:
      if (!isAuthenticated && !isPublicPage) {
        return '/login';
      }

      // 4. User is authenticated and attempting to view auth pages:
      if (isAuthenticated && isAuthPage) {
        return '/feed';
      }

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
            builder: (context, state) {
              final tabParam = state.uri.queryParameters['tab']?.toLowerCase();
              int initialIndex = 0;
              if (tabParam == 'rankings' || tabParam == 'stacks') {
                initialIndex = 3;
              } else if (tabParam == 'history') {
                initialIndex = 1;
              } else if (tabParam == 'watchlist') {
                initialIndex = 2;
              } else if (tabParam == 'suggestions') {
                initialIndex = 4;
              }
              return EntriesScreen(initialIndex: initialIndex);
            },
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
        path: '/scanner',
        builder: (context, state) => const HiveScannerScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/entry/:id',
        builder: (context, state) {
          final entryId = state.pathParameters['id']!;
          final openComments = state.uri.queryParameters['openComments'] == 'true';
          final initialEntry = state.extra is Entry ? state.extra as Entry : null;
          return EntryDetailScreen(
            entryId: entryId,
            initialEntry: initialEntry,
            openComments: openComments,
          );
        },
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) {
          final catName = state.uri.queryParameters['category'];
          final initialCat = SupportCategory.values.firstWhere(
            (c) => c.name.toLowerCase() == catName?.toLowerCase(),
            orElse: () => SupportCategory.bug,
          );
          return SupportScreen(
            initialCategory: initialCat,
            prefillSubject: state.uri.queryParameters['subject'],
            prefillMessage: state.uri.queryParameters['message'],
          );
        },
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
          initialUser: state.extra as User?,
        ),
      ),
      GoRoute(
        path: '/details/:mediaType/:tmdbId',
        builder: (context, state) {
          Entry? initialEntry;
          User? authorUser;
          User? suggestedByUser;
          String? suggestedByUserId;
          if (state.extra is Entry) {
            initialEntry = state.extra as Entry;
            authorUser = initialEntry.user;
            suggestedByUser = initialEntry.suggestedByUser;
            suggestedByUserId = initialEntry.suggestedByUserId;
          } else if (state.extra is Map) {
            final map = state.extra as Map;
            if (map['entry'] is Entry) {
              initialEntry = map['entry'] as Entry;
              suggestedByUser = initialEntry.suggestedByUser;
              suggestedByUserId = initialEntry.suggestedByUserId;
            }
            if (map['user'] is User) {
              authorUser = map['user'] as User;
            } else {
              authorUser = initialEntry?.user;
            }
            if (map['suggestedByUser'] is User) {
              suggestedByUser = map['suggestedByUser'] as User;
            } else if (map['suggestedByUser'] is Map) {
              try {
                suggestedByUser = User.fromJson(Map<String, dynamic>.from(map['suggestedByUser'] as Map));
              } catch (_) {}
            }
            if (map['suggestedByUserId'] is String) {
              suggestedByUserId = map['suggestedByUserId'] as String;
            } else if (suggestedByUser != null && suggestedByUser.id.isNotEmpty) {
              suggestedByUserId = suggestedByUser.id;
            }
          }
          return MovieDetailsScreen(
            mediaType: state.pathParameters['mediaType']!,
            tmdbId: int.parse(state.pathParameters['tmdbId']!),
            initialEntry: initialEntry,
            authorUser: authorUser,
            suggestedByUser: suggestedByUser,
            suggestedByUserId: suggestedByUserId,
          );
        },
      ),
      GoRoute(
        path: '/rankings',
        builder: (context, state) => RankingsScreen(
          initialStackId: state.extra as String?,
        ),
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          'Page not found',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    ),
  );
});
