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
  bool _isLoadingFriends = true;
  bool _isSending = false;

  // For movie search when no tmdbId is passed
  MediaResult? _selectedMedia;
  List<MediaResult> _searchResults = [];
  bool _isSearchingMedia = false;
  Timer? _debounce;
  final _movieSearchController = TextEditingController();

  String _friendSearchQuery = '';
  final _messageController = TextEditingController();

  final _scrollController = ScrollController();
  final _messageFocusNode = FocusNode();
  final _friendSearchFocusNode = FocusNode();
  final _movieSearchFocusNode = FocusNode();

  final _movieSearchKey = GlobalKey();
  final _friendSearchKey = GlobalKey();
  final _messageKey = GlobalKey();
  double _lastBottomInset = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialToUserId != null) {
      _selectedUserIds.add(widget.initialToUserId!);
    }
    _loadFriends();

    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus) {
        _scrollToKey(_messageKey, alignment: 0.0);
      }
    });

    _friendSearchFocusNode.addListener(() {
      if (_friendSearchFocusNode.hasFocus) {
        _scrollToKey(_friendSearchKey, alignment: 0.0);
      }
    });

    _movieSearchFocusNode.addListener(() {
      if (_movieSearchFocusNode.hasFocus) {
        _scrollToKey(_movieSearchKey, alignment: 0.0);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _friendSearchFocusNode.dispose();
    _movieSearchFocusNode.dispose();
    _movieSearchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _scrollToKey(GlobalKey key, {double alignment = 0.05}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 140), () {
        if (!mounted) return;
        final ctx = key.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(
            ctx,
            alignment: alignment,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        } else if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    });
  }

  Future<void> _loadFriends() async {
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final me = await userRepo.getCurrentUser();
      
      final followers = await userRepo.getFollowers(me.id).catchError((_) => <User>[]);

      final friendMap = <String, User>{};
      for (final u in followers) {
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

    if (widget.initialToUserId != null &&
        !_isLoadingFriends &&
        !_friends.any((u) => u.id == widget.initialToUserId)) {
      WHAlert.showWarning(
        context,
        '@${widget.initialToUserName ?? "This user"} is not following you yet. Only followers can receive suggestions.',
      );
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final isKeyboardOpen = bottomInset > 0;
    final bool isSingleRecipientNotFollower = widget.initialToUserId != null &&
        !_isLoadingFriends &&
        !_friends.any((u) => u.id == widget.initialToUserId);

    if (bottomInset > _lastBottomInset && _messageFocusNode.hasFocus) {
      _scrollToKey(_messageKey, alignment: 0.0);
    }
    _lastBottomInset = bottomInset;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: WHModalLoadingOverlay(
          isLoading: _isSending,
          message: 'Delivering your recommendation...',
          child: Container(
            constraints: BoxConstraints(
              maxHeight: (screenHeight - bottomInset).clamp(300.0, screenHeight * 0.90),
            ),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // ── Header (Pinned at top) ──────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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

                    // Title Row
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
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.border),
                  ],
                ),
              ),

              // ── Scrollable Body ───────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Movie Selection if no initial title
                      if (widget.tmdbId == null) ...[
                        if (_selectedMedia == null) ...[
                          const Text(
                            '1. CHOOSE MOVIE OR TV SHOW',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1.0),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            key: _movieSearchKey,
                            child: TextField(
                              controller: _movieSearchController,
                              focusNode: _movieSearchFocusNode,
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
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                              ),
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
                                physics: const ClampingScrollPhysics(),
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

                      // Recipients Section
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
                        Container(
                          key: _friendSearchKey,
                          child: TextField(
                            focusNode: _friendSearchFocusNode,
                            onChanged: _onFriendSearchChanged,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search followers...',
                              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 18),
                              filled: true,
                              fillColor: AppColors.surface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Recipient List
                      if (widget.initialToUserId != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
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
                        if (isSingleRecipientNotFollower) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '@${widget.initialToUserName ?? "This user"} is not following you yet. Only followers can receive movie suggestions.',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: Colors.amber,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ]
                      else if (_isLoadingFriends)
                        const WHSkeletonUserList(count: 3)
                      else
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: isKeyboardOpen ? 150 : 230,
                          ),
                          child: _buildFriendsList(),
                        ),

                      const SizedBox(height: 16),

                      // Optional Note / Suggestion Comments (Auto-scrolls when focused)
                      Container(
                        key: _messageKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ADD A NOTE (OPTIONAL)',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textMuted,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _messageController,
                              focusNode: _messageFocusNode,
                              scrollPadding: const EdgeInsets.only(bottom: 120),
                              maxLines: 3,
                              minLines: 1,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. "You gotta watch this, the ending blew my mind!"',
                                hintStyle: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: AppColors.textMuted,
                                  fontSize: 12.5,
                                ),
                                prefixIcon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: AppColors.textMuted,
                                  size: 18,
                                ),
                                filled: true,
                                fillColor: AppColors.surface,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Send Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSingleRecipientNotFollower ? AppColors.surfaceHighest : AppColors.primary,
                            foregroundColor: isSingleRecipientNotFollower ? AppColors.textMuted : Colors.black,
                            elevation: isSingleRecipientNotFollower ? 0 : 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: (_isSending || isSingleRecipientNotFollower) ? null : _handleSend,
                          child: _isSending
                              ? const WHBeeSpinner(size: 20)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isSingleRecipientNotFollower ? Icons.block_rounded : Icons.send_rounded,
                                      size: 16,
                                      color: isSingleRecipientNotFollower ? AppColors.textMuted : Colors.black,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isSingleRecipientNotFollower
                                          ? 'Cannot Suggest (Not a Follower)'
                                          : 'Send Suggestion (${_selectedUserIds.length})',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: isSingleRecipientNotFollower ? AppColors.textMuted : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  List<User> _getDisplayUsers() {
    if (_friendSearchQuery.isEmpty) return _friends;
    final q = _friendSearchQuery.toLowerCase();
    return _friends.where((u) {
      final name = (u.displayName ?? '').toLowerCase();
      final username = u.username.toLowerCase();
      return name.contains(q) || username.contains(q);
    }).toList();
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
              _friendSearchQuery.isNotEmpty ? 'No followers found matching "$_friendSearchQuery"' : 'No followers yet',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
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


