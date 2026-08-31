import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../search/repositories/search_repository.dart';
import '../../../shared/models/models.dart';
import '../models/ranking_stack.dart';
import '../providers/rankings_provider.dart';

class RankingsScreen extends ConsumerStatefulWidget {
  final String? initialStackId;

  const RankingsScreen({super.key, this.initialStackId});

  @override
  ConsumerState<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends ConsumerState<RankingsScreen> {
  String? _selectedStackId;

  @override
  void initState() {
    super.initState();
    _selectedStackId = widget.initialStackId;
  }

  void _onStackSelected(String stackId) {
    if (_selectedStackId == stackId) return;
    setState(() => _selectedStackId = stackId);
    ref.read(activeStackProvider.notifier).loadStack(stackId);
  }

  void _openCreateStackModal() {
    final state = ref.read(myRankingsProvider);
    if (state.stacks.length >= 5) {
      WHAlert.showWarning(context, 'You have reached the maximum limit of 5 ranking stacks.');
      return;
    }
    _showCreateEditModal();
  }

  void _openEditStackModal(RankingStack stack) {
    _showCreateEditModal(stack: stack);
  }

  void _showCreateEditModal({RankingStack? stack}) {
    final isEditing = stack != null;
    final nameController = TextEditingController(text: stack?.name ?? '');
    final descController = TextEditingController(text: stack?.description ?? '');
    bool isPublic = stack?.isPublic ?? true;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollable: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                      Text(
                        isEditing ? 'Edit Ranking Stack ✏️' : 'Create New Stack 🏆',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Stack Name', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: TextField(
                      controller: nameController,
                      maxLength: 100,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Top 10 Christopher Nolan Films, Best of 2026',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Description (Optional)', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: TextField(
                      controller: descController,
                      maxLines: 3,
                      maxLength: 500,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Add some context about what this ranking stack represents…',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(14),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Public Visibility', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          Text('Show on your public profile', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                      Switch.adaptive(
                        value: isPublic,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setModalState(() => isPublic = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                WHAlert.showWarning(context, 'Please enter a stack name');
                                return;
                              }
                              setModalState(() => isSubmitting = true);
                              try {
                                if (isEditing) {
                                  await ref.read(myRankingsProvider.notifier).updateStack(
                                        stack.id,
                                        name: name,
                                        description: descController.text.trim(),
                                        isPublic: isPublic,
                                      );
                                  await ref.read(activeStackProvider.notifier).loadStack(stack.id);
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    WHAlert.showSuccess(context, 'Stack updated! ✨');
                                  }
                                } else {
                                  final newStack = await ref.read(myRankingsProvider.notifier).createStack(
                                        name: name,
                                        description: descController.text.trim(),
                                        isPublic: isPublic,
                                      );
                                  if (mounted && newStack != null) {
                                    Navigator.pop(ctx);
                                    _onStackSelected(newStack.id);
                                    WHAlert.showSuccess(context, 'Created "${newStack.name}"! 🏆');
                                  }
                                }
                              } catch (e) {
                                if (mounted) WHAlert.showError(context, 'Failed to save stack: $e');
                              } finally {
                                if (mounted) setModalState(() => isSubmitting = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                          : Text(
                              isEditing ? 'Save Changes' : 'Create Stack 🏆',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openSearchAddModal(String stackId) {
    showModalBottomSheet(
      context: context,
      isScrollable: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _SearchAddModal(
        stackId: stackId,
        onAdded: () => ref.read(activeStackProvider.notifier).loadStack(stackId),
      ),
    );
  }

  Future<void> _confirmDeleteStack(RankingStack stack) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Stack?', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        content: Text('Are you sure you want to delete "${stack.name}"? This action cannot be undone.', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(myRankingsProvider.notifier).deleteStack(stack.id);
      setState(() => _selectedStackId = null);
      if (mounted) WHAlert.showSuccess(context, 'Deleted "${stack.name}"');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myRankingsState = ref.watch(myRankingsProvider);
    final activeState = ref.watch(activeStackProvider);

    // Auto-select first stack if none selected
    if (myRankingsState.stacks.isNotEmpty && _selectedStackId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onStackSelected(myRankingsState.stacks.first.id);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rankings & Stacks 📚',
              style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            ),
            Text(
              'Rank your favorite films & TV series in order',
              style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _openCreateStackModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'New Stack',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: myRankingsState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : myRankingsState.stacks.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    await ref.read(myRankingsProvider.notifier).loadStacks();
                    if (_selectedStackId != null) {
                      await ref.read(activeStackProvider.notifier).loadStack(_selectedStackId!);
                    }
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      // ── Horizontal Stack Pill Carousel ──
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: myRankingsState.stacks.map((stack) {
                            final isSelected = stack.id == _selectedStackId;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => _onStackSelected(stack.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : AppColors.border,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary.withValues(alpha: 0.3),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.format_list_numbered_rounded,
                                        size: 16,
                                        color: isSelected ? Colors.black : AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        stack.name,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isSelected ? Colors.black : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.black.withValues(alpha: 0.15) : AppColors.surfaceHighest,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${stack.items.length}',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.black : AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Active Stack Header Card ──
                      if (activeState.stack != null)
                        _buildStackHeroCard(activeState.stack!),

                      const SizedBox(height: 16),

                      // ── Ranked Items List ──
                      if (activeState.isLoading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        )
                      else if (activeState.items.isEmpty)
                        _buildEmptyItemsState(activeState.stack?.id ?? '')
                      else
                        ...activeState.items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return _buildRankedItemCard(item, index, activeState.items.length);
                        }),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.format_list_numbered_rounded, color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Ranking Stacks Yet',
              style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create ordered lists to rank your absolute favorites, director filmographies, or yearly best-of stacks!',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openCreateStackModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Your First Stack 🏆', style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStackHeroCard(RankingStack stack) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stack.name,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stack.isPublic ? Colors.green.withValues(alpha: 0.15) : AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: stack.isPublic ? Colors.green.withValues(alpha: 0.4) : AppColors.border),
                ),
                child: Text(
                  stack.isPublic ? '🌐 Public' : '🔒 Private',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: stack.isPublic ? Colors.greenAccent : AppColors.textMuted),
                ),
              ),
            ],
          ),
          if (stack.description != null && stack.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(stack.description!, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              // + Add Title Button
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () => _openSearchAddModal(stack.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: const Text('Add Title 🎬', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 8),

              // Edit Button
              IconButton.filledTonal(
                onPressed: () => _openEditStackModal(stack),
                tooltip: 'Edit Stack',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceHighest,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              const SizedBox(width: 6),

              // Share Button
              IconButton.filledTonal(
                onPressed: () {
                  final text = 'Check out my "${stack.name}" ranked stack on WatchHive! 🐝🎬';
                  Share.share(text);
                },
                tooltip: 'Share Stack',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceHighest,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.share_outlined, size: 18),
              ),
              const SizedBox(width: 6),

              // Delete Button
              IconButton.filledTonal(
                onPressed: () => _confirmDeleteStack(stack),
                tooltip: 'Delete Stack',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.12),
                  foregroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyItemsState(String stackId) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.movie_creation_outlined, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 10),
            const Text('Stack is empty', style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Search and add movies or series to rank them in order.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openSearchAddModal(stackId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.search_rounded, size: 16),
              label: const Text('Search & Add Title', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankedItemCard(RankedItem item, int index, int totalCount) {
    final rankNumber = index + 1;
    final isTop3 = rankNumber <= 3;

    Color badgeBgColor;
    Color badgeTextColor;
    String medalEmoji = '';

    if (rankNumber == 1) {
      badgeBgColor = const Color(0xFFFFD700);
      badgeTextColor = Colors.black;
      medalEmoji = ' 🥇';
    } else if (rankNumber == 2) {
      badgeBgColor = const Color(0xFFE0E0E0);
      badgeTextColor = Colors.black;
      medalEmoji = ' 🥈';
    } else if (rankNumber == 3) {
      badgeBgColor = const Color(0xFFCD7F32);
      badgeTextColor = Colors.white;
      medalEmoji = ' 🥉';
    } else {
      badgeBgColor = AppColors.surfaceHighest;
      badgeTextColor = AppColors.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTop3 ? badgeBgColor.withValues(alpha: 0.5) : AppColors.border,
          width: isTop3 ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.push('/details/${item.mediaType}/${item.tmdbId}');
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Rank Number Badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '#$rankNumber',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Poster Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.posterPath != null && item.posterPath!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: ApiEndpoints.tmdbPoster(item.posterPath!),
                        width: 44,
                        height: 66,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(width: 44, height: 66, color: AppColors.surfaceHighest),
                        errorWidget: (_, __, ___) => Container(width: 44, height: 66, color: AppColors.surfaceHighest, child: const Icon(Icons.movie_rounded, color: AppColors.textMuted, size: 20)),
                      )
                    : Container(
                        width: 44,
                        height: 66,
                        decoration: BoxDecoration(color: AppColors.surfaceHighest, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.movie_creation_outlined, color: AppColors.primary, size: 20),
                      ),
              ),
              const SizedBox(width: 12),

              // Title and Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item.title ?? 'Movie #${item.tmdbId}') + medalEmoji,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.mediaType == 'tv' ? 'TV' : 'MOVIE',
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        if (item.year.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(item.year, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                        if (item.localRating != null && item.localRating! > 0) ...[
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          const SizedBox(width: 4),
                          Icon(Icons.star_rounded, size: 12, color: Colors.amber[400]),
                          const SizedBox(width: 2),
                          Text(
                            item.localRating!.toStringAsFixed(1),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber[400]),
                          ),
                        ] else if (item.voteAverage != null && item.voteAverage! > 0) ...[
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          const SizedBox(width: 4),
                          const Icon(Icons.star_rounded, size: 12, color: AppColors.primary),
                          const SizedBox(width: 2),
                          Text(
                            item.voteAverage!.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Reorder Buttons (Up / Down) + Remove
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                    color: index > 0 ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.2),
                    tooltip: 'Move Up',
                    onPressed: index > 0
                        ? () {
                            HapticFeedback.lightImpact();
                            ref.read(activeStackProvider.notifier).moveItem(index, index - 1);
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                    color: index < totalCount - 1 ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.2),
                    tooltip: 'Move Down',
                    onPressed: index < totalCount - 1
                        ? () {
                            HapticFeedback.lightImpact();
                            ref.read(activeStackProvider.notifier).moveItem(index, index + 1);
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                    tooltip: 'Remove from Stack',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: const Text('Remove from Stack?', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          content: Text('Remove "${item.title ?? 'this title'}" from the stack?', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        ref.read(activeStackProvider.notifier).removeItem(item.tmdbId);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchAddModal extends ConsumerStatefulWidget {
  final String stackId;
  final VoidCallback onAdded;

  const _SearchAddModal({required this.stackId, required this.onAdded});

  @override
  ConsumerState<_SearchAddModal> createState() => _SearchAddModalState();
}

class _SearchAddModalState extends ConsumerState<_SearchAddModal> {
  final _searchController = TextEditingController();
  List<MediaResult> _results = [];
  bool _isSearching = false;
  int? _addingTmdbId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await ref.read(searchRepositoryProvider).searchMedia(q.trim());
      if (mounted) setState(() => _results = results.take(8).toList());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _addTitle(MediaResult media) async {
    setState(() => _addingTmdbId = media.id);
    try {
      await ref.read(activeStackProvider.notifier).addItem(
            tmdbId: media.id,
            mediaType: media.mediaType,
          );
      widget.onAdded();
      if (mounted) {
        Navigator.pop(context);
        WHAlert.showSuccess(context, 'Added "${media.title}" to stack! 🎬');
      }
    } catch (e) {
      if (mounted) WHAlert.showError(context, 'Failed to add item: $e');
    } finally {
      if (mounted) setState(() => _addingTmdbId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add Title to Stack 🎬',
                style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary),
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search movie or TV show title…',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_results.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                itemBuilder: (ctx, i) {
                  final media = _results[i];
                  final isAdding = _addingTmdbId == media.id;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: media.posterPath != null && media.posterPath!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: ApiEndpoints.tmdbPoster(media.posterPath!),
                                  width: 34,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(width: 34, height: 50, color: AppColors.surfaceHighest),
                                  errorWidget: (_, __, ___) => Container(width: 34, height: 50, color: AppColors.surfaceHighest, child: const Icon(Icons.movie_rounded, color: AppColors.textMuted, size: 16)),
                                )
                              : Container(width: 34, height: 50, color: AppColors.surfaceHighest, child: const Icon(Icons.movie_rounded, color: AppColors.primary, size: 16)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(media.title, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                                    child: Text(media.mediaType == 'movie' ? 'MOVIE' : 'TV', style: const TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  ),
                                  if (media.year.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text(media.year, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: isAdding ? null : () => _addTitle(media),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: isAdding
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('+ Add', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black)),
                        ),
                      ],
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
