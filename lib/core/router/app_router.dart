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

/// Tracks a pending deep link received during cold startup or before auth resolution.
String? _pendingDeepLink;

/// Consumes and returns any saved pending deep link.
String? consumePendingDeepLink() {
  final link = _pendingDeepLink;
  _pendingDeepLink = null;
  return link;
}

/// Normalizes web and custom scheme deep link URIs into canonical GoRouter routes.
String? normalizeIncomingRoute(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  final path = uri.path;

  // 1. Custom URL Scheme: watchershive:// or watchhive://
  if (scheme == 'watchershive' || scheme == 'watchhive') {
    final query = uri.hasQuery ? '?${uri.query}' : '';
    // e.g. watchershive://details/movie/550
    if (host == 'details') {
      return '/details$path$query';
    }
    // e.g. watchershive://movie/550 or watchershive://tv/123
    if (host == 'movie' || host == 'tv') {
      return '/details/$host$path$query';
    }
    // e.g. watchershive://profile/:id or watchershive://user/:id
    if (host == 'profile' || host == 'user') {
      return '/profile$path$query';
    }
    if (host == 'feed' || host == 'entries' || host == 'search' || host == 'notifications') {
      return '/$host$path$query';
    }
    if (path.isNotEmpty && path != '/') {
      return '$path$query';
    }
  }

  // 2. Web Paths with /watch-hive or /watchers-hive or /watcher-hive prefix
  if (path.startsWith('/watch-hive') || path.startsWith('/watchers-hive') || path.startsWith('/watcher-hive')) {
    final stripped = path.replaceFirst(RegExp(r'^/watch(?:ers?)?-hive'), '');
    final cleanPath = stripped.isEmpty ? '/feed' : stripped;
    final resolvedPath = cleanPath.startsWith('/user/')
        ? cleanPath.replaceFirst('/user/', '/profile/')
        : cleanPath;
    final query = uri.hasQuery ? '?${uri.query}' : '';
    return '$resolvedPath$query';
  }

  // 3. /user/:id -> /profile/:id
  if (path.startsWith('/user/')) {
    final query = uri.hasQuery ? '?${uri.query}' : '';
    return path.replaceFirst('/user/', '/profile/') + query;
  }

  return null;
}

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

      // 0. Handle incoming deep link normalization
      final normalized = normalizeIncomingRoute(state.uri);
      if (normalized != null &&
          normalized != state.uri.toString() &&
          normalized != state.matchedLocation) {
        return normalized;
      }

      final isSplash = state.matchedLocation == '/splash';
      final isAuthPage = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/signup') ||
          state.matchedLocation.startsWith('/forgot-password');
      final isPublicPage = isAuthPage ||
          state.matchedLocation.startsWith('/privacy-policy') ||
          state.matchedLocation.startsWith('/support');

      // Preserve deep link destination if navigating during initial cold start / loading
      if (!isSplash &&
          !isAuthPage &&
          !isPublicPage &&
          (state.matchedLocation.startsWith('/details') ||
              state.matchedLocation.startsWith('/profile') ||
              state.matchedLocation.startsWith('/entry'))) {
        final currentFullUri = state.uri.toString();
        if (currentFullUri != '/feed' && currentFullUri != '/splash') {
          _pendingDeepLink = currentFullUri;
        }
      }

      // 1. If currently on splash screen:
      if (isSplash) {
        // While still resolving initial session / auto-login, STAY on splash screen
        if (isLoading) return null;
        // Once resolved: if we have a pending deep link, navigate there!
        if (isAuthenticated) {
          if (_pendingDeepLink != null && _pendingDeepLink!.isNotEmpty && _pendingDeepLink != '/splash') {
            final dest = _pendingDeepLink!;
            _pendingDeepLink = null;
            return dest;
          }
          return '/feed';
        }
        return '/login';
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
        if (_pendingDeepLink != null && _pendingDeepLink!.isNotEmpty && _pendingDeepLink != '/splash') {
          final dest = _pendingDeepLink!;
          _pendingDeepLink = null;
          return dest;
        }
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

          suggestedByUserId ??= state.uri.queryParameters['suggestedByUserId'] ??
              state.uri.queryParameters['suggestedBy'] ??
              state.uri.queryParameters['ref'];
          final suggestedByUsername = state.uri.queryParameters['suggestedByUsername'] ??
              state.uri.queryParameters['refUsername'] ??
              state.uri.queryParameters['username'];
          if (suggestedByUser == null && suggestedByUsername != null && suggestedByUsername.isNotEmpty) {
            suggestedByUser = User(
              id: suggestedByUserId ?? '',
              username: suggestedByUsername,
              createdAt: DateTime.now(),
            );
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
      // Deep link compatibility routes for web URLs and external QR scans
      GoRoute(
        path: '/watch-hive/details/:mediaType/:tmdbId',
        redirect: (context, state) {
          final query = state.uri.hasQuery ? '?${state.uri.query}' : '';
          return '/details/${state.pathParameters['mediaType']}/${state.pathParameters['tmdbId']}$query';
        },
      ),
      GoRoute(
        path: '/watch-hive/profile/:id',
        redirect: (context, state) {
          final query = state.uri.hasQuery ? '?${state.uri.query}' : '';
          return '/profile/${state.pathParameters['id']}$query';
        },
      ),
      GoRoute(
        path: '/user/:id',
        redirect: (context, state) {
          final query = state.uri.hasQuery ? '?${state.uri.query}' : '';
          return '/profile/${state.pathParameters['id']}$query';
        },
      ),
      GoRoute(
        path: '/watch-hive/user/:id',
        redirect: (context, state) {
          final query = state.uri.hasQuery ? '?${state.uri.query}' : '';
          return '/profile/${state.pathParameters['id']}$query';
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
