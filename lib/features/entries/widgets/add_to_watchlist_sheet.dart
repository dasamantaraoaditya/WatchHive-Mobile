import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchhive_mobile/core/api/api_endpoints.dart';
import 'package:watchhive_mobile/core/theme/app_colors.dart';
import 'package:watchhive_mobile/core/utils/error_handler.dart';
import 'package:watchhive_mobile/features/entries/repositories/watchlist_repository.dart';
import 'package:watchhive_mobile/features/profile/repositories/user_repository.dart';
import 'package:watchhive_mobile/shared/models/user.dart';
import 'package:watchhive_mobile/shared/widgets/wh_alert.dart';
import 'package:watchhive_mobile/shared/widgets/wh_bee_loader.dart';

class AddToWatchlistSheet extends ConsumerStatefulWidget {
  final int tmdbId;
  final String title;
  final String mediaType;
  final String? posterPath;
  final String? overview;
  final String? prefillSuggestedByUserId;
  final User? prefillSuggestedByUser;

  const AddToWatchlistSheet({
    super.key,
    required this.tmdbId,
    required this.title,
    required this.mediaType,
    this.posterPath,
    this.overview,
    this.prefillSuggestedByUserId,
    this.prefillSuggestedByUser,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int tmdbId,
    required String title,
    required String mediaType,
    String? posterPath,
    String? overview,
    String? prefillSuggestedByUserId,
    User? prefillSuggestedByUser,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddToWatchlistSheet(
        tmdbId: tmdbId,
        title: title,
        mediaType: mediaType,
        posterPath: posterPath,
        overview: overview,
        prefillSuggestedByUserId: prefillSuggestedByUserId,
        prefillSuggestedByUser: prefillSuggestedByUser,
      ),
    );
  }

  @override
  ConsumerState<AddToWatchlistSheet> createState() => _AddToWatchlistSheetState();
}

class _AddToWatchlistSheetState extends ConsumerState<AddToWatchlistSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  User? _selectedUser;
  List<User> _searchResults = [];
  List<User>? _cachedFollowers;
  bool _isSearching = false;
  bool _showDropdown = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillSuggestedByUser != null) {
      _selectedUser = widget.prefillSuggestedByUser;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFollowers() async {
    if (_cachedFollowers != null) return;
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final me = await userRepo.getCurrentUser();
      final followers = await userRepo.getFollowers(me.id).catchError((_) => <User>[]);
      _cachedFollowers = followers.where((u) => u.id != me.id).toList();
    } catch (_) {
      _cachedFollowers = [];
    }
  }

  void _onSearchChanged(String query) async {
    _debounce?.cancel();
    final trimmed = query.trim().toLowerCase();

    setState(() => _isSearching = true);
    await _loadFollowers();

    final all = _cachedFollowers ?? <User>[];
    final results = trimmed.isEmpty
        ? all
        : all.where((u) {
            final name = (u.displayName ?? '').toLowerCase();
            final username = u.username.toLowerCase();
            return name.contains(trimmed) || username.contains(trimmed);
          }).toList();

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _handleConfirm() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final cleanTitle = widget.title.trim().isNotEmpty ? widget.title.trim() : 'Title';
      await ref.read(watchlistRepositoryProvider).addToWatchlist(
        tmdbId: widget.tmdbId,
        title: cleanTitle,
        mediaType: widget.mediaType,
        posterPath: widget.posterPath,
        overview: widget.overview,
        suggestedByUserId: _selectedUser?.id,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        final tag = _selectedUser != null
            ? ' (suggested by @${_selectedUser!.username})'
            : '';
        WHAlert.showSuccess(context, 'Added "$cleanTitle"$tag to Watchlist! 📌');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(e, action: 'Failed to add to Watchlist'),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTv = widget.mediaType.toLowerCase().contains('tv');
    final posterUrl = ApiEndpoints.tmdbPoster(widget.posterPath);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: WHModalLoadingOverlay(
          isLoading: _isSubmitting,
          message: 'Saving to your Watchlist...',
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add to Watchlist',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Media Card Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: posterUrl.isNotEmpty
                          ? Image.network(
                              posterUrl,
                              width: 48,
                              height: 68,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 48,
                                height: 68,
                                color: AppColors.surface,
                                child: Icon(
                                  isTv ? Icons.tv_rounded : Icons.movie_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : Container(
                              width: 48,
                              height: 68,
                              color: AppColors.surface,
                              child: Icon(
                                isTv ? Icons.tv_rounded : Icons.movie_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isTv ? '📺 TV SERIES' : '🎬 MOVIE',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Save to queue for later',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // "Suggested by" section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Text(
                        '💡 Suggested By',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '(optional)',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Track influence',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Selected Friend Chip or Search Box
              if (_selectedUser != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary,
                        backgroundImage: _selectedUser!.profilePictureUrl != null &&
                                _selectedUser!.profilePictureUrl!.isNotEmpty
                            ? NetworkImage(_selectedUser!.profilePictureUrl!)
                            : null,
                        child: _selectedUser!.profilePictureUrl == null ||
                                _selectedUser!.profilePictureUrl!.isEmpty
                            ? Text(
                                (_selectedUser!.displayName ?? _selectedUser!.username)[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedUser!.displayName ?? _selectedUser!.username,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '@${_selectedUser!.username}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.amber, size: 20),
                        onPressed: () {
                          setState(() {
                            _selectedUser = null;
                            _showDropdown = true;
                          });
                          _searchFocusNode.requestFocus();
                        },
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (val) {
                      setState(() => _showDropdown = true);
                      _onSearchChanged(val);
                    },
                    onTap: () {
                      setState(() => _showDropdown = true);
                      if (_searchResults.isEmpty) {
                        _onSearchChanged('');
                      }
                    },
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search follower username…',
                      hintStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.person_search_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: WHBeeSpinner(size: 16),
                            )
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                if (_showDropdown && _searchResults.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(6),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (ctx, i) {
                        final u = _searchResults[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _selectedUser = u;
                              _showDropdown = false;
                            });
                            _searchFocusNode.unfocus();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primary,
                                  backgroundImage: u.profilePictureUrl != null && u.profilePictureUrl!.isNotEmpty
                                      ? NetworkImage(u.profilePictureUrl!)
                                      : null,
                                  child: u.profilePictureUrl == null || u.profilePictureUrl!.isEmpty
                                      ? Text(
                                          (u.displayName ?? u.username)[0].toUpperCase(),
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        u.displayName ?? u.username,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '@${u.username}',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 18),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _handleConfirm,
                      icon: _isSubmitting
                          ? const WHBeeSpinner(size: 16)
                          : const Icon(Icons.bookmark_add_rounded, size: 18),
                      label: Text(
                        _isSubmitting
                            ? 'Adding…'
                            : (_selectedUser != null ? 'Add with Suggestion' : 'Add to Watchlist'),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
