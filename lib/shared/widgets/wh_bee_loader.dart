import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum WHBeeLoaderSize {
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

    final floatOffset = widget.size == WHBeeLoaderSize.small
        ? -6.0
        : (widget.size == WHBeeLoaderSize.large ? -14.0 : -10.0);

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
          vertical: widget.size == WHBeeLoaderSize.small ? 12 : 28,
          horizontal: 16,
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
