import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class WHSortOption {
  final String value;
  final String label;

  const WHSortOption({
    required this.value,
    required this.label,
  });
}

class WHFilterBar extends StatelessWidget {
  final String search;
  final ValueChanged<String>? onSearchChanged;
  final String placeholder;
  final String sortBy;
  final List<WHSortOption> sortOptions;
  final ValueChanged<String> onSortChanged;
  final int? count;
  final String countLabel;
  final bool isLoading;

  const WHFilterBar({
    super.key,
    this.search = '',
    this.onSearchChanged,
    this.placeholder = 'Search items...',
    required this.sortBy,
    required this.sortOptions,
    required this.onSortChanged,
    this.count,
    this.countLabel = 'items',
    this.isLoading = false,
  });

  String _formatShortLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('recently watched') || lower.contains('recent watch')) {
      return 'Recent';
    } else if (lower.contains('oldest watched') || lower.contains('oldest added') || lower.contains('oldest')) {
      return 'Oldest';
    } else if (lower.contains('highest rated') || lower.contains('top rated')) {
      return 'Top Rated';
    } else if (lower.contains('lowest rated')) {
      return 'Lowest';
    } else if (lower.contains('recently suggested')) {
      return 'Recent';
    } else if (lower.contains('recently added') || lower.contains('newest')) {
      return 'Newest';
    } else if (lower.contains('a-z') || lower.contains('a to z')) {
      return 'A to Z';
    } else if (lower.contains('z-a') || lower.contains('z to a')) {
      return 'Z to A';
    }
    return label;
  }

  void _showSortPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.sort_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'SORT BY',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (count != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count $countLabel',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            ...sortOptions.map((opt) {
              final isSelected = opt.value == sortBy;
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                title: Text(
                  opt.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                    : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                onTap: () {
                  Navigator.pop(ctx);
                  if (!isSelected) {
                    onSortChanged(opt.value);
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentOption = sortOptions.firstWhere(
      (opt) => opt.value == sortBy,
      orElse: () => sortOptions.isNotEmpty ? sortOptions.first : const WHSortOption(value: '', label: 'Sort'),
    );
    final shortLabel = _formatShortLabel(currentOption.label);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Search box
          if (onSearchChanged != null)
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: TextField(
                  controller: TextEditingController.fromValue(
                    TextEditingValue(
                      text: search,
                      selection: TextSelection.collapsed(offset: search.length),
                    ),
                  ),
                  onChanged: onSearchChanged,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: placeholder,
                    hintStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    prefixIcon: isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                    suffixIcon: search.isNotEmpty
                        ? GestureDetector(
                            onTap: () => onSearchChanged!(''),
                            child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  ),
                ),
              ),
            ),

          const SizedBox(width: 8),

          // Sort selector pill
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showSortPicker(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sort_rounded, size: 16, color: AppColors.primaryDark),
                    const SizedBox(width: 6),
                    Text(
                      shortLabel.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.primaryDark),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
