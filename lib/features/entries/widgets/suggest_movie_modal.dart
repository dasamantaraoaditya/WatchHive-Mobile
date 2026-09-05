import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../profile/repositories/user_repository.dart';
import '../../search/repositories/search_repository.dart';
import '../repositories/suggestions_repository.dart';
import '../../../core/utils/error_handler.dart';

class SuggestMovieModal extends ConsumerStatefulWidget {
  final int? tmdbId;
  final String? title;
  final String? mediaType;
  final String? initialToUserId;
  final String? initialToUserName;

  const SuggestMovieModal({
    super.key,
    this.tmdbId,
    this.title,
    this.mediaType,
    this.initialToUserId,
    this.initialToUserName,
  });

  static Future<void> show(
    BuildContext context, {
    int? tmdbId,
    String? title,
    String? mediaType,
    String? initialToUserId,
    String? initialToUserName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SuggestMovieModal(
        tmdbId: tmdbId,
        title: title,
        mediaType: mediaType,
        initialToUserId: initialToUserId,
        initialToUserName: initialToUserName,
      ),
    );
  }

  @override
  ConsumerState<SuggestMovieModal> createState() => _SuggestMovieModalState();
}

class _SuggestMovieModalState extends ConsumerState<SuggestMovieModal> {
  final Set<String> _selectedUserIds = {};
  List<User> _friends = [];
  List<User> _searchedUsers = [];
  bool _isLoadingFriends = true;
  bool _isSearchingUsers = false;
  bool _isSending = false;

  // For movie search when no tmdbId is passed
  MediaResult? _selectedMedia;
  List<MediaResult> _searchResults = [];
  bool _isSearchingMedia = false;
  Timer? _debounce;
  Timer? _friendDebounce;
  final _movieSearchController = TextEditingController();

  String _friendSearchQuery = '';
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialToUserId != null) {
      _selectedUserIds.add(widget.initialToUserId!);
    }
    _loadFriends();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _friendDebounce?.cancel();
    _movieSearchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final searchRepo = ref.read(searchRepositoryProvider);
      final me = await userRepo.getCurrentUser();
      
      final results = await Future.wait([
        userRepo.getFollowing(me.id).catchError((_) => <User>[]),
        userRepo.getFollowers(me.id).catchError((_) => <User>[]),
        searchRepo.getSuggestedUsers().catchError((_) => <User>[]),
      ]);

      final following = results[0];
      final followers = results[1];
      final suggested = results[2];

      final friendMap = <String, User>{};
      for (final u in [...following, ...followers, ...suggested]) {
        if (u.id != me.id) {
          friendMap[u.id] = u;
        }
      }

      if (mounted) {
        setState(() {
          _friends = friendMap.values.toList();
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  void _onFriendSearchChanged(String query) {
    setState(() => _friendSearchQuery = query.trim());
    _friendDebounce?.cancel();

    if (query.trim().length < 2) {
      setState(() {
        _searchedUsers = [];
        _isSearchingUsers = false;
      });
      return;
    }

    _friendDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isSearchingUsers = true);
      try {
        final users = await ref.read(searchRepositoryProvider).searchUsers(query.trim());
        if (mounted) {
          setState(() {
            _searchedUsers = users;
            _isSearchingUsers = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearchingUsers = false);
      }
    });
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearchingMedia = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _isSearchingMedia = true);
      try {
        final results = await ref.read(searchRepositoryProvider).searchMedia(query.trim());
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearchingMedia = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearchingMedia = false);
      }
    });
  }


  Future<void> _handleSend() async {
    final int? tmdbId = widget.tmdbId ?? _selectedMedia?.id;
    final String? title = widget.title ?? _selectedMedia?.title;
    final String mediaType = widget.mediaType ?? _selectedMedia?.mediaType ?? 'movie';

    if (tmdbId == null || title == null) {
      WHAlert.showWarning(context, 'Please select a movie or show to suggest.');
      return;
    }

    if (_selectedUserIds.isEmpty) {
      WHAlert.showWarning(context, 'Please select at least one recipient.');
      return;
    }

    setState(() => _isSending = true);
    try {
      final suggRepo = ref.read(suggestionsRepositoryProvider);
      await suggRepo.sendSuggestion(
        toUserIds: _selectedUserIds.toList(),
        tmdbId: tmdbId,
        title: title,
        mediaType: mediaType,
        message: _messageController.text.trim().isNotEmpty ? _messageController.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context);
        final recipientDesc = widget.initialToUserName != null
            ? '@${widget.initialToUserName}'
            : '${_selectedUserIds.length} friend${_selectedUserIds.length > 1 ? "s" : ""}';
        WHAlert.showSuccess(context, 'Suggestion for "$title" sent to $recipientDesc! ✨');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Could not send suggestion. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }

  }

  @override
  Widget build(BuildContext context) {
    final targetTitle = widget.title ?? _selectedMedia?.title;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.initialToUserName != null
                          ? 'Suggest to @${widget.initialToUserName}'
                          : 'Suggest to Hive Friends',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (targetTitle != null)
                      Text(
                        targetTitle,
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Movie Selection if no initial title
          if (widget.tmdbId == null) ...[
            if (_selectedMedia == null) ...[
              const Text(
                '1. CHOOSE MOVIE OR TV SHOW',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1.0),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _movieSearchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search TMDB for a title...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
              if (_isSearchingMedia)
                const WHSkeletonMediaSearchList(count: 2)
              else if (_searchResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (ctx, i) {
                      final item = _searchResults[i];
                      return ListTile(
                        dense: true,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: item.posterPath != null
                              ? Image.network(
                                  ApiEndpoints.tmdbPoster(item.posterPath),
                                  width: 28,
                                  height: 42,
                                  fit: BoxFit.cover,
                                )
                              : Container(width: 28, height: 42, color: AppColors.surfaceHighest),
                        ),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                        subtitle: Text('${item.mediaType.toUpperCase()} · ${item.year}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                        onTap: () => setState(() => _selectedMedia = item),
                      );
                    },
                  ),
                ),
            ] else ...[
              // Selected Movie Chip
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _selectedMedia!.posterPath != null
                          ? Image.network(
                              ApiEndpoints.tmdbPoster(_selectedMedia!.posterPath),
                              width: 36,
                              height: 52,
                              fit: BoxFit.cover,
                            )
                          : Container(width: 36, height: 52, color: AppColors.surfaceHighest),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedMedia!.title,
                            style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                          ),
                          Text(
                            '${_selectedMedia!.mediaType.toUpperCase()} · ${_selectedMedia!.year}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                      onPressed: () => setState(() => _selectedMedia = null),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Friends List (if not fixed to 1 user or to pick friends)
          if (widget.initialToUserId == null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '2. SELECT RECIPIENTS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1.0),
                ),
                if (_friends.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      final currentDisplayList = _getDisplayUsers();
                      setState(() {
                        if (_selectedUserIds.length >= currentDisplayList.length && currentDisplayList.isNotEmpty) {
                          _selectedUserIds.clear();
                        } else {
                          _selectedUserIds.addAll(currentDisplayList.map((u) => u.id));
                        }
                      });
                    },
                    child: Text(
                      _selectedUserIds.isNotEmpty && _selectedUserIds.length >= _getDisplayUsers().length
                          ? 'CLEAR ALL'
                          : 'SELECT ALL',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              onChanged: _onFriendSearchChanged,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search friends or cinephiles...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 18),
                suffixIcon: _isSearchingUsers
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Recipient List View
          Expanded(
            child: widget.initialToUserId != null
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_rounded, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Recipient: @${widget.initialToUserName ?? widget.initialToUserId}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  )
                : _isLoadingFriends
                    ? const WHSkeletonUserList(count: 3)
                    : _buildFriendsList(),
          ),
          const SizedBox(height: 12),

          // Optional Note
          TextField(
            controller: _messageController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Add an optional note ("You gotta watch this!")...',
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 14),

          // Send Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSending ? null : _handleSend,
              child: _isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                  : Text(
                      'Send Suggestion (${_selectedUserIds.length})',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<User> _getDisplayUsers() {
    final map = <String, User>{};
    for (final u in _friends) {
      if (_friendSearchQuery.isEmpty) {
        map[u.id] = u;
      } else {
        final full = '${u.displayName ?? ''} ${u.username}'.toLowerCase();
        if (full.contains(_friendSearchQuery.toLowerCase())) {
          map[u.id] = u;
        }
      }
    }
    for (final u in _searchedUsers) {
      map[u.id] = u;
    }
    return map.values.toList();
  }

  Widget _buildFriendsList() {
    final displayList = _getDisplayUsers();

    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline_rounded, size: 36, color: AppColors.textMuted),
            const SizedBox(height: 8),
            Text(
              _friendSearchQuery.isNotEmpty ? 'No users found matching "$_friendSearchQuery"' : 'No friends connected yet',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: displayList.length,
      itemBuilder: (ctx, i) {
        final user = displayList[i];
        final isSelected = _selectedUserIds.contains(user.id);

        return InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedUserIds.remove(user.id);
              } else {
                _selectedUserIds.add(user.id);
              }
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                WHAvatar(
                  imageUrl: user.profilePictureUrl,
                  name: user.name,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '@${user.username}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.black)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


