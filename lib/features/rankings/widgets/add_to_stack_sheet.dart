import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../models/ranking_stack.dart';
import '../repositories/rankings_repository.dart';
import '../providers/rankings_provider.dart';
import '../../../core/utils/error_handler.dart';

class AddToStackSheet extends ConsumerStatefulWidget {
  final int tmdbId;
  final String title;
  final String? posterPath;
  final String mediaType;

  const AddToStackSheet({
    super.key,
    required this.tmdbId,
    required this.title,
    this.posterPath,
    this.mediaType = 'movie',
  });

  static Future<void> show(
    BuildContext context, {
    required int tmdbId,
    required String title,
    String? posterPath,
    String mediaType = 'movie',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => AddToStackSheet(
        tmdbId: tmdbId,
        title: title,
        posterPath: posterPath,
        mediaType: mediaType,
      ),
    );
  }

  @override
  ConsumerState<AddToStackSheet> createState() => _AddToStackSheetState();
}

class _AddToStackSheetState extends ConsumerState<AddToStackSheet> {
  String? _addingStackId;

  Future<void> _addToStack(RankingStack stack) async {
    setState(() => _addingStackId = stack.id);
    try {
      final repo = ref.read(rankingsRepositoryProvider);
      await repo.addItemToStack(
        listId: stack.id,
        tmdbId: widget.tmdbId,
        mediaType: widget.mediaType,
      );
      // Reload my rankings so count updates
      ref.read(myRankingsProvider.notifier).loadStacks();

      if (mounted) {
        Navigator.pop(context);
        WHAlert.showSuccess(context, 'Added "${widget.title}" to ${stack.name}! 🏆');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Could not add to stack. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _addingStackId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myRankingsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add to Ranking Stack 📚',
                style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Media preview banner
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: widget.posterPath != null && widget.posterPath!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: ApiEndpoints.tmdbPoster(widget.posterPath!),
                          width: 32,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(width: 32, height: 48, color: AppColors.surfaceHighest),
                          errorWidget: (_, __, ___) => Container(width: 32, height: 48, color: AppColors.surfaceHighest, child: const Icon(Icons.movie_rounded, size: 16, color: AppColors.textMuted)),
                        )
                      : Container(width: 32, height: 48, color: AppColors.surfaceHighest, child: const Icon(Icons.movie_creation_outlined, color: AppColors.primary, size: 16)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Select a Stack:',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),

          if (state.isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary)))
          else if (state.stacks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    const Text('You have not created any ranking stacks yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to rankings
                      },
                      child: const Text('Create a Stack', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: state.stacks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final stack = state.stacks[i];
                  final isAdding = _addingStackId == stack.id;

                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.format_list_numbered_rounded, color: AppColors.primary, size: 20),
                      ),
                      title: Text(
                        stack.name,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        '${stack.items.length} items · ${stack.isPublic ? "Public" : "Private"}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      trailing: isAdding
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                          : const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 22),
                      onTap: isAdding ? null : () => _addToStack(stack),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
