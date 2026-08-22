import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../profile/repositories/user_repository.dart';
import '../repositories/suggestions_repository.dart';

class SuggestMovieModal extends ConsumerStatefulWidget {
  final int tmdbId;
  final String title;
  final String? mediaType;
  final String? initialToUserId;
  final String? initialToUserName;

  const SuggestMovieModal({
    super.key,
    required this.tmdbId,
    required this.title,
    this.mediaType,
    this.initialToUserId,
    this.initialToUserName,
  });

  @override
  ConsumerState<SuggestMovieModal> createState() => _SuggestMovieModalState();
}

class _SuggestMovieModalState extends ConsumerState<SuggestMovieModal> {
  final Set<String> _selectedUserIds = {};
  List<User> _friends = [];
  bool _isLoading = true;
  bool _isSending = false;
  String _searchQuery = '';
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
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final me = await userRepo.getCurrentUser();
      final following = await userRepo.getFollowing(me.id);
      if (mounted) {
        setState(() {
          _friends = following;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSend() async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one friend.')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final suggRepo = ref.read(suggestionsRepositoryProvider);
      await suggRepo.sendSuggestion(
        toUserIds: _selectedUserIds.toList(),
        tmdbId: widget.tmdbId,
        title: widget.title,
        mediaType: widget.mediaType ?? 'movie',
        message: _messageController.text.trim().isNotEmpty ? _messageController.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Suggestion sent successfully! ✨')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send suggestion: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredFriends = _friends.where((f) {
      if (_searchQuery.isEmpty) return true;
      final full = '${f.displayName ?? ''} ${f.username}'.toLowerCase();
      return full.contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Suggest "${widget.title}"',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search friends...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
              filled: true,
              fillColor: AppColors.cardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : filteredFriends.isEmpty
                    ? const Center(
                        child: Text('No friends found', style: TextStyle(color: AppColors.textMuted)),
                      )
                    : ListView.builder(
                        itemCount: filteredFriends.length,
                        itemBuilder: (ctx, i) {
                          final friend = filteredFriends[i];
                          final isSelected = _selectedUserIds.contains(friend.id);
                          return CheckboxListTile(
                            activeColor: AppColors.primary,
                            checkColor: Colors.white,
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedUserIds.add(friend.id);
                                } else {
                                  _selectedUserIds.remove(friend.id);
                                }
                              });
                            },
                            secondary: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primary,
                              backgroundImage: friend.profilePictureUrl != null
                                  ? NetworkImage(friend.profilePictureUrl!)
                                  : null,
                              onBackgroundImageError: (_, __) {},
                              child: friend.profilePictureUrl == null
                                  ? Text(
                                      (friend.displayName ?? friend.username)[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            title: Text(
                              friend.displayName ?? friend.username,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '@${friend.username}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add an optional note...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              filled: true,
              fillColor: AppColors.cardBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSending ? null : _handleSend,
              child: _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Send Suggestion (${_selectedUserIds.length})',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
