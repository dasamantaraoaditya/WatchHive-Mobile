import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum WHBeeLoaderSize {
  mini,
  small,
  medium,
  large,
}

class WHBeeLoader extends StatefulWidget {
  final String? message;
  final WHBeeLoaderSize size;
  final bool showBackgroundHoneycomb;

  const WHBeeLoader({
    super.key,
    this.message,
    this.size = WHBeeLoaderSize.medium,
    this.showBackgroundHoneycomb = true,
  });

  @override
  State<WHBeeLoader> createState() => _WHBeeLoaderState();
}

class _WHBeeLoaderState extends State<WHBeeLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _translateAnimation;
  late final Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    final floatOffset = widget.size == WHBeeLoaderSize.mini
        ? -3.0
        : (widget.size == WHBeeLoaderSize.small
            ? -6.0
            : (widget.size == WHBeeLoaderSize.large ? -14.0 : -10.0));

    _translateAnimation = Tween<double>(begin: 0.0, end: floatOffset).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: -0.07, end: 0.07).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _iconSize {
    switch (widget.size) {
      case WHBeeLoaderSize.mini:
        return 16.0;
      case WHBeeLoaderSize.small:
        return 22.0;
      case WHBeeLoaderSize.medium:
        return 42.0;
      case WHBeeLoaderSize.large:
        return 60.0;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case WHBeeLoaderSize.mini:
        return 9.0;
      case WHBeeLoaderSize.small:
        return 11.0;
      case WHBeeLoaderSize.medium:
        return 13.0;
      case WHBeeLoaderSize.large:
        return 15.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: widget.size == WHBeeLoaderSize.mini
              ? 4
              : (widget.size == WHBeeLoaderSize.small ? 12 : 28),
          horizontal: widget.size == WHBeeLoaderSize.mini ? 4 : 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _translateAnimation.value),
                  child: Transform.rotate(
                    angle: _rotateAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.showBackgroundHoneycomb)
                    Container(
                      width: _iconSize * 1.55,
                      height: _iconSize * 1.55,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.hexagon_rounded,
                          size: _iconSize * 1.3,
                          color: AppColors.primary.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: _iconSize,
                    height: _iconSize,
                    child: Image.asset(
                      'assets/images/watchhive-logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('🐝', style: TextStyle(fontSize: 26)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.message != null && widget.message!.isNotEmpty) ...[
              SizedBox(height: widget.size == WHBeeLoaderSize.small ? 6 : 12),
              Text(
                widget.message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: _fontSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A list/grid footer that renders a compact animated bee loader when loading more,
/// or "🐝 All caught up" when reached end of list.
class WHBeeLoadingFooter extends StatelessWidget {
  final bool isLoadingMore;
  final bool hasMore;
  final bool showCaughtUp;
  final String loadingText;

  const WHBeeLoadingFooter({
    super.key,
    required this.isLoadingMore,
    this.hasMore = false,
    this.showCaughtUp = true,
    this.loadingText = 'Buzzing for more...',
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return WHBeeLoader(
        size: WHBeeLoaderSize.small,
        message: loadingText,
      );
    }

    if (!hasMore && showCaughtUp) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Row(
          children: [
            Expanded(child: Container(height: 1, color: AppColors.border)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🐝', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 6),
                  Text(
                    'ALL CAUGHT UP',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: Container(height: 1, color: AppColors.border)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// A lightweight animated bee spinner for buttons, inline action chips, and inputs.
/// Drops in effortlessly wherever a CircularProgressIndicator was previously used.
class WHBeeSpinner extends StatefulWidget {
  final double size;
  final String? message;
  final Color? color;

  const WHBeeSpinner({
    super.key,
    this.size = 18.0,
    this.message,
    this.color,
  });

  @override
  State<WHBeeSpinner> createState() => _WHBeeSpinnerState();
}

class _WHBeeSpinnerState extends State<WHBeeSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -2.5, end: 2.5).animate(
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
    final beeWidget = AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: Image.asset(
        'assets/images/watchhive-logo.png',
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Text(
          '🐝',
          style: TextStyle(fontSize: widget.size * 0.8),
        ),
      ),
    );

    if (widget.message == null || widget.message!.isEmpty) {
      return SizedBox(
        width: widget.size + 4,
        height: widget.size + 4,
        child: Center(child: beeWidget),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: widget.size + 4,
          height: widget.size + 4,
          child: Center(child: beeWidget),
        ),
        const SizedBox(width: 8),
        Text(
          widget.message!,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: widget.size * 0.72,
            fontWeight: FontWeight.w700,
            color: widget.color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// A modal/sheet semi-transparent loading overlay with the animated bee,
/// ensuring users get clear visual feedback and that modals don't abruptly close
/// or finish without an explicit loading indicator.
class WHModalLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String message;
  final Widget child;

  const WHModalLoadingOverlay({
    super.key,
    required this.isLoading,
    this.message = 'Saving to your Hive...',
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const WHBeeLoader(
                        size: WHBeeLoaderSize.small,
                        showBackgroundHoneycomb: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

