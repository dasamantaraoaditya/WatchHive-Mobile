import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/navigation_extensions.dart';
import '../../../shared/models/entry.dart';
import '../../auth/providers/auth_provider.dart';
import '../../feed/screens/feed_screen.dart';
import '../../feed/repositories/feed_repository.dart';
import '../../feed/widgets/comments_sheet.dart';
import '../../feed/widgets/wh_feed_card.dart';
import '../repositories/entries_repository.dart';

class EntryDetailScreen extends ConsumerStatefulWidget {
  final String entryId;
  final Entry? initialEntry;
  final bool openComments;

  const EntryDetailScreen({
    super.key,
    required this.entryId,
    this.initialEntry,
    this.openComments = false,
  });

  @override
  ConsumerState<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends ConsumerState<EntryDetailScreen> {
  Entry? _entry;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  bool _hasOpenedComments = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEntry != null) {
      _entry = widget.initialEntry;
      _isLiked = widget.initialEntry!.isLiked;
      _likesCount = widget.initialEntry!.likesCount;
      _commentsCount = widget.initialEntry!.commentsCount;
    }
    _loadEntry();

    if (widget.openComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasOpenedComments) {
          _hasOpenedComments = true;
          _showComments();
        }
      });
    }
  }

  Future<void> _loadEntry() async {
    if (_entry == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final fetched = await ref.read(entriesRepositoryProvider).getEntryById(widget.entryId);
      if (mounted) {
        setState(() {
          _entry = fetched;
          _isLiked = fetched.isLiked;
          _likesCount = fetched.likesCount;
          _commentsCount = fetched.commentsCount;
          _isLoading = false;
        });

        if (widget.openComments && !_hasOpenedComments) {
          _hasOpenedComments = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showComments();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_entry == null) {
            _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
          }
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_entry == null) return;
    final wasLiked = _isLiked;
    final prevCount = _likesCount;

    setState(() {
      _isLiked = !wasLiked;
      _likesCount = wasLiked ? (prevCount > 0 ? prevCount - 1 : 0) : prevCount + 1;
    });

    try {
      if (wasLiked) {
        await ref.read(feedRepositoryProvider).unlikeEntry(widget.entryId);
      } else {
        await ref.read(feedRepositoryProvider).likeEntry(widget.entryId);
      }
      try {
        ref.read(feedProvider.notifier).toggleLike(widget.entryId);
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likesCount = prevCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like: $e')),
        );
      }
    }
  }

  void _showComments() {
    if (_entry == null) return;
    CommentsSheet.show(
      context,
      entryId: _entry!.id,
      entryTitle: _entry!.title,
      entryAuthorId: _entry!.userId,
      onCommentCountChanged: (count) {
        if (mounted) {
          setState(() {
            _commentsCount = count;
          });
        }
        try {
          ref.read(feedProvider.notifier).updateCommentsCount(_entry!.id, count);
        } catch (_) {}
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value?.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.safePop(),
        ),
        title: const Text(
          'Post',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _buildBody(currentUser?.id),
    );
  }

  Widget _buildBody(String? currentUserId) {
    if (_isLoading && _entry == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null && _entry == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Post not found',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadEntry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    if (_entry == null) {
      return const SizedBox.shrink();
    }

    final entryToDisplay = _entry!.copyWith(
      isLiked: _isLiked,
      likesCount: _likesCount,
      commentsCount: _commentsCount,
      isCommented: _commentsCount > 0,
    );

    return RefreshIndicator(
      onRefresh: _loadEntry,
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceElevated,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          WHFeedCard(
            entry: entryToDisplay,
            isLiked: _isLiked,
            isOwnEntry: currentUserId == entryToDisplay.userId,
            onLike: _toggleLike,
            onCommentTap: _showComments,
            onUserTap: () {
              final targetId = (entryToDisplay.user?.id != null && entryToDisplay.user!.id.isNotEmpty)
                  ? entryToDisplay.user!.id
                  : entryToDisplay.userId;
              if (targetId.isNotEmpty) {
                context.push('/profile/$targetId');
              }
            },
            onMediaTap: () => context.push(
              '/details/${entryToDisplay.type == "MOVIE" ? "movie" : "tv"}/${entryToDisplay.tmdbId}',
              extra: entryToDisplay,
            ),
          ),
        ],
      ),
    );
  }
}
