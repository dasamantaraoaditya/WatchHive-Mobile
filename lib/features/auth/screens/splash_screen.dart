import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/wh_skeleton.dart';
import '../../../shared/widgets/wh_app_logo_loader.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndNavigate();
    });
  }

  void _checkAndNavigate() {
    final authState = ref.read(authStateProvider);
    if (authState.isLoading) return; // Wait if initial session check is still resolving

    final isAuthenticated = authState.value?.isAuthenticated ?? false;
    if (!mounted) return;

    try {
      if (GoRouter.maybeOf(context) != null) {
        if (isAuthenticated) {
          final pending = consumePendingDeepLink();
          if (pending != null && pending.isNotEmpty && pending != '/splash') {
            context.go(pending);
          } else {
            context.go('/feed');
          }
        } else {
          context.go('/login');
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth state resolution
    ref.listen(authStateProvider, (previous, next) {
      if (!next.isLoading) {
        _checkAndNavigate();
      }
    });

    final authState = ref.watch(authStateProvider);
    final isResolvingSession = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            WHAppLogoLoader(
              logoSize: 84.0,
              showBrandName: true,
              showSpinner: isResolvingSession,
              message: isResolvingSession ? 'Signing you in...' : null,
              submessage: 'Track Movies, Anime, K-Drama & Series',
            ),
            if (!isResolvingSession) ...[
              const SizedBox(height: 28),
              WHSkeleton(
                child: Container(
                  width: 120,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
