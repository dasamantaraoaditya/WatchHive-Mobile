import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/wh_skeleton.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _minBrandingElapsed = false;
  Timer? _brandingTimer;

  @override
  void initState() {
    super.initState();
    _brandingTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _minBrandingElapsed = true);
      _checkAndNavigate();
    });
  }

  @override
  void dispose() {
    _brandingTimer?.cancel();
    super.dispose();
  }

  void _checkAndNavigate() {
    if (!_minBrandingElapsed) return;
    final authState = ref.read(authStateProvider);
    if (authState.isLoading) return; // Keep waiting while auto-login is active!

    final isAuthenticated = authState.value?.isAuthenticated ?? false;
    if (!mounted) return;

    if (isAuthenticated) {
      context.go('/feed');
    } else {
      context.go('/login');
    }
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
            // Logo
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text('🎬', style: TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'WatchHive',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Track Movies, Anime, K-Drama & Series',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 52),
            if (isResolvingSession) ...[
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Signing you in...',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ] else ...[
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
