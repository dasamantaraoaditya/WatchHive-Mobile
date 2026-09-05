import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../features/entries/screens/add_entry_sheet.dart';
import '../../features/entries/widgets/quick_currently_watching_sheet.dart';
import '../../features/entries/widgets/quick_search_media_sheet.dart';

class WHQuickAddFAB extends StatefulWidget {
  const WHQuickAddFAB({super.key});

  @override
  State<WHQuickAddFAB> createState() => _WHQuickAddFABState();
}

class _WHQuickAddFABState extends State<WHQuickAddFAB> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        if (mounted && _isOpen) {
          setState(() => _isOpen = false);
        } else if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    if (_isOpen) {
      setState(() => _isOpen = false);
      _controller.reverse();
    }
  }

  void _onAction(VoidCallback action) {
    HapticFeedback.mediumImpact();
    _close();
    Future.delayed(const Duration(milliseconds: 150), action);
  }

  Widget _buildMainFab() {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isOpen ? Colors.white : AppColors.primary,
          border: Border.all(
            color: _isOpen ? AppColors.primary : Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: _isOpen ? 0.2 : 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: RotationTransition(
            turns: _rotateAnimation,
            child: Icon(
              Icons.add_rounded,
              size: 32,
              color: _isOpen ? AppColors.primary : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hide FAB when keyboard is open to prevent blocking text inputs and submit buttons
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    if (isKeyboardOpen && !_isOpen) {
      return const SizedBox.shrink();
    }

    final isVisible = _isOpen || _controller.value > 0;

    // When closed and animation finished: DO NOT render full-screen stack!
    // Render only the FAB at bottom: 16, right: 16 to never block screen touches.
    if (!isVisible) {
      return Positioned(
        bottom: 16,
        right: 16,
        child: _buildMainFab(),
      );
    }

    final actions = [
      _FABAction(
        label: 'Log an Entry',
        icon: Icons.edit_note_rounded,
        color: const Color(0xFF3B82F6),
        bgColor: const Color(0xFFEFF6FF),
        onTap: () => _onAction(() {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const AddEntrySheet(),
          );
        }),
      ),
      _FABAction(
        label: 'Add Currently Watching',
        icon: Icons.visibility_rounded,
        color: const Color(0xFF22C55E),
        bgColor: const Color(0xFFF0FDF4),
        onTap: () => _onAction(() => QuickCurrentlyWatchingSheet.show(context)),
      ),
      _FABAction(
        label: 'Suggest to Friends',
        icon: Icons.send_rounded,
        color: const Color(0xFFA855F7),
        bgColor: const Color(0xFFFAF5FF),
        onTap: () => _onAction(() => QuickSearchMediaSheet.show(context, intent: QuickSearchIntent.suggest)),
      ),
      _FABAction(
        label: 'Add to Watchlist',
        icon: Icons.bookmark_add_rounded,
        color: AppColors.primary,
        bgColor: AppColors.primary.withValues(alpha: 0.12),
        onTap: () => _onAction(() => QuickSearchMediaSheet.show(context, intent: QuickSearchIntent.watchlist)),
      ),
    ];

    return Positioned.fill(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          // Backdrop overlay when open
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_isOpen,
              child: GestureDetector(
                onTap: _close,
                behavior: HitTestBehavior.opaque,
                child: AnimatedBuilder(
                  animation: _expandAnimation,
                  builder: (context, child) {
                    if (_expandAnimation.value == 0.0) return const SizedBox.shrink();
                    return Opacity(
                      opacity: _expandAnimation.value,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 4 * _expandAnimation.value,
                          sigmaY: 4 * _expandAnimation.value,
                        ),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.55 * _expandAnimation.value),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Action Items Column
          Positioned(
            bottom: 84,
            right: 16,
            child: IgnorePointer(
              ignoring: !_isOpen,
              child: AnimatedBuilder(
                animation: _expandAnimation,
                builder: (context, child) {
                  if (_expandAnimation.value == 0.0) return const SizedBox.shrink();
                  return Opacity(
                    opacity: _expandAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(actions.length, (index) {
                        final action = actions[index];
                        final offset = (actions.length - 1 - index) * 12.0 * (1 - _expandAnimation.value);

                        return Transform.translate(
                          offset: Offset(0, offset),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Label Pill
                                GestureDetector(
                                  onTap: action.onTap,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      action.label,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Circular Action Button
                                GestureDetector(
                                  onTap: action.onTap,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: action.color.withValues(alpha: 0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      action.icon,
                                      color: action.color,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
            ),
          ),

          // Main FAB Button
          Positioned(
            bottom: 16,
            right: 16,
            child: _buildMainFab(),
          ),
        ],
      ),
    );
  }
}

class _FABAction {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _FABAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
}
