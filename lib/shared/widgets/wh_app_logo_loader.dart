import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Standalone pulsing/breathing WatchersHive logo badge with soft golden glow.
class WHAppLogoBadge extends StatefulWidget {
  final double size;

  const WHAppLogoBadge({super.key, this.size = 88.0});

  @override
  State<WHAppLogoBadge> createState() => _WHAppLogoBadgeState();
}

class _WHAppLogoBadgeState extends State<WHAppLogoBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _floatAnimation = Tween<double>(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(widget.size * 0.28),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.all(widget.size * 0.16),
              child: child,
            ),
          ),
        );
      },
      child: Image.asset(
        'assets/images/watchhive-logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('🐝', style: TextStyle(fontSize: 36)),
        ),
      ),
    );
  }
}

/// An animated brand logo loader that prominently features the WatchersHive app logo
/// with a gentle floating pulse and golden glow aura.
///
/// Used during initial cold startup, session restoration, and when signing in.
class WHAppLogoLoader extends StatefulWidget {
  final String? message;
  final String? submessage;
  final double logoSize;
  final bool showBrandName;
  final bool showSpinner;

  const WHAppLogoLoader({
    super.key,
    this.message = 'Loading your hive...',
    this.submessage,
    this.logoSize = 72.0,
    this.showBrandName = true,
    this.showSpinner = true,
  });

  /// Full-screen scaffold variant for splash and standalone loading states
  static Widget fullScreen({
    String? message = 'Loading your hive...',
    String? submessage,
    double logoSize = 76.0,
    bool showBrandName = true,
    bool showSpinner = true,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: WHAppLogoLoader(
            message: message,
            submessage: submessage,
            logoSize: logoSize,
            showBrandName: showBrandName,
            showSpinner: showSpinner,
          ),
        ),
      ),
    );
  }

  /// Full-screen modal overlay variant with subtle backdrop blur.
  /// Typically stacked over login/signup forms while signing in.
  static Widget overlay({
    String? message = 'Signing you into WatchersHive...',
    String? submessage,
    double logoSize = 72.0,
    bool showSpinner = true,
  }) {
    return Positioned.fill(
      child: PopScope(
        canPop: false,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: AppColors.background.withValues(alpha: 0.92),
            child: Center(
              child: WHAppLogoLoader(
                message: message,
                submessage: submessage,
                logoSize: logoSize,
                showBrandName: true,
                showSpinner: showSpinner,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<WHAppLogoLoader> createState() => _WHAppLogoLoaderState();
}

class _WHAppLogoLoaderState extends State<WHAppLogoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _floatAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _floatAnimation = Tween<double>(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.55).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: widget.logoSize * 1.35,
                    height: widget.logoSize * 1.35,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(widget.logoSize * 0.38),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: _glowAnimation.value),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(widget.logoSize * 0.22),
                    child: child,
                  ),
                ),
              );
            },
            child: Image.asset(
              'assets/images/watchhive-logo.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const Center(
                child: Text('🐝', style: TextStyle(fontSize: 36)),
              ),
            ),
          ),
          if (widget.showBrandName) ...[
            const SizedBox(height: 20),
            const Text(
              'WatchersHive',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ],
          if (widget.showSpinner) ...[
            const SizedBox(height: 18),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
          if (widget.message != null && widget.message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
                letterSpacing: 0.3,
              ),
            ),
          ],
          if (widget.submessage != null && widget.submessage!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.submessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
