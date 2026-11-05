import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _stackNameController = TextEditingController();
  final _stackDescController = TextEditingController();
  bool _isStackPublic = true;
  bool _isCreatingStack = false;
  bool _isCreatingSubmitting = false;
  String? _addingStackId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myRankingsProvider.notifier).loadStacks();
    });
  }

  @override
  void dispose() {
    _stackNameController.dispose();
    _stackDescController.dispose();
    super.dispose();
  }

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
        WHAlert.showSuccess(context, 'Added "${widget.title}" to ${stack.name}.');
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

  Future<void> _createStackAndAdd() async {
    final name = _stackNameController.text.trim();
    if (name.isEmpty) {
      WHAlert.showWarning(context, 'Please enter a stack name');
      return;
    }

    setState(() => _isCreatingSubmitting = true);
    try {
      final newStack = await ref.read(myRankingsProvider.notifier).createStack(
            name: name,
            description: _stackDescController.text.trim().isNotEmpty
                ? _stackDescController.text.trim()
                : null,
            isPublic: _isStackPublic,
          );

      if (newStack == null) {
        if (mounted) {
          WHAlert.showError(context, 'Failed to create stack. Please try again.');
        }
        return;
      }

      try {
        final repo = ref.read(rankingsRepositoryProvider);
        await repo.addItemToStack(
          listId: newStack.id,
          tmdbId: widget.tmdbId,
          mediaType: widget.mediaType,
        );
        ref.read(myRankingsProvider.notifier).loadStacks();

        if (mounted) {
          Navigator.pop(context);
          WHAlert.showSuccess(
            context,
            'Created "${newStack.name}" and added "${widget.title}".',
          );
        }
      } catch (itemErr) {
        ref.read(myRankingsProvider.notifier).loadStacks();
        if (mounted) {
          setState(() {
            _isCreatingStack = false;
            _stackNameController.clear();
            _stackDescController.clear();
          });
          WHAlert.showWarning(
            context,
            'Created "${newStack.name}", but could not add item: ${AppErrorHandler.toUserFriendlyMessage(itemErr)}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Could not create ranking stack.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingSubmitting = false);
      }
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add to Stack',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
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
                            errorWidget: (_, __, ___) => Container(
                              width: 32,
                              height: 48,
                              color: AppColors.surfaceHighest,
                              child: const Icon(Icons.movie_rounded, size: 16, color: AppColors.textMuted),
                            ),
                          )
                        : Container(
                            width: 32,
                            height: 48,
                            color: AppColors.surfaceHighest,
                            child: const Icon(Icons.movie_creation_outlined, color: AppColors.primary, size: 16),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select a Stack:',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (!_isCreatingStack)
                  TextButton.icon(
                    key: const Key('add_stack_button_header'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isCreatingStack = true);
                    },
                    icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                    label: const Text(
                      'Add Stack',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (state.isLoading)
              const WHSkeletonStackList(count: 3)
            else if (_isCreatingStack)
              _buildCreateStackForm()
            else if (state.error != null && state.stacks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        state.error!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceElevated,
                          foregroundColor: AppColors.textPrimary,
                        ),
                        onPressed: () => ref.read(myRankingsProvider.notifier).loadStacks(),
                      ),
                    ],
                  ),
                ),
              )
            else if (state.stacks.isEmpty)
              _buildEmptyStacksView()
            else
              _buildStacksList(state.stacks),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStacksView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.format_list_numbered_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Ranking Stacks Yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create a ranking stack to rank and organize your favorite titles.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              key: const Key('add_stack_button_empty'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() => _isCreatingStack = true);
              },
              icon: const Icon(Icons.add_rounded, size: 20, color: Colors.black),
              label: const Text(
                'Add Stack',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateStackForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Create New Stack',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _isCreatingStack = false;
                    _stackNameController.clear();
                    _stackDescController.clear();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Stack Name',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _stackNameController,
              autofocus: true,
              maxLength: 100,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'e.g. Top Sci-Fi Films, Best of 2026',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Description (Optional)',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _stackDescController,
              maxLines: 2,
              maxLength: 500,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'What represents this ranking stack…',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Public Visibility',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Show on your public profile',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              Switch.adaptive(
                value: _isStackPublic,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => setState(() => _isStackPublic = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              key: const Key('create_and_add_stack_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _isCreatingSubmitting ? null : _createStackAndAdd,
              child: _isCreatingSubmitting
                  ? const WHBeeSpinner(size: 22)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 20, color: Colors.black),
                        SizedBox(width: 6),
                        Text(
                          'Create and Add to Stack',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStacksList(List<RankingStack> stacks) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stacks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
          final stack = stacks[i];
          final isAdding = _addingStackId == stack.id;

          return Material(
            color: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
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
                  ? const WHBeeSpinner(size: 18)
                  : const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 22),
              onTap: isAdding ? null : () => _addToStack(stack),
            ),
          );
        },
      );
  }
}
