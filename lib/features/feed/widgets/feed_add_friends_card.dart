import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// An interactive panel shown in the Feed when a user has 0 friends/following,
/// encouraging them to add friends to diversify their feed and suggestions,
/// alongside inline suggested friends to follow immediately.
class FeedAddFriendsCard extends StatefulWidget {
  final VoidCallback onAddFriends;
  final VoidCallback onDismiss;
  final List<User> suggestedUsers;
  final Function(User)? onFollowUser;
  final Function(User)? onUserTap;
  final Map<String, bool>? followingMap;
  final Map<String, bool>? loadingFollowMap;

  static const String _storagePrefix = 'wh_dismissed_feed_add_friends_banner_';

  static FlutterSecureStorage _getStorage() => const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );

  /// Check whether the user has previously dismissed this card.
  static Future<bool> isDismissed(String userId, [FlutterSecureStorage? storage]) async {
    if (userId.trim().isEmpty) return false;
    try {
      final s = storage ?? _getStorage();
      final val = await s.read(key: '$_storagePrefix${userId.trim()}');
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Mark the card as dismissed for this user.
  static Future<void> setDismissed(String userId, [FlutterSecureStorage? storage]) async {
    if (userId.trim().isEmpty) return;
    try {
      final s = storage ?? _getStorage();
      await s.write(key: '$_storagePrefix${userId.trim()}', value: 'true');
    } catch (_) {}
  }

  /// Reset the dismissed state (useful for tests or user settings).
  static Future<void> resetDismissed(String userId, [FlutterSecureStorage? storage]) async {
    if (userId.trim().isEmpty) return;
    try {
      final s = storage ?? _getStorage();
      await s.delete(key: '$_storagePrefix${userId.trim()}');
    } catch (_) {}
  }

  const FeedAddFriendsCard({
    super.key,
    required this.onAddFriends,
    required this.onDismiss,
    this.suggestedUsers = const [],
    this.onFollowUser,
    this.onUserTap,
    this.followingMap,
    this.loadingFollowMap,
  });

  @override
  State<FeedAddFriendsCard> createState() => _FeedAddFriendsCardState();
}

class _FeedAddFriendsCardState extends State<FeedAddFriendsCard> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title + Close Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Diversify Your Feed & Suggestions',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 18,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                tooltip: 'Dismiss',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  widget.onDismiss();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Message Body
          const Text(
            'You haven’t added any friends yet! Connect with fellow cinephiles to populate your swarm feed with varied ratings, reviews, and diverse recommendations.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),

          // Inline Suggested Friends Horizontal Carousel
          if (widget.suggestedUsers.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: AppColors.primaryDark,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'SUGGESTED FRIENDS TO FOLLOW',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.suggestedUsers.length > 2) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        icon: const Icon(Icons.chevron_left_rounded, size: 20, color: AppColors.textSecondary),
                        tooltip: 'Scroll left',
                        onPressed: () {
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              (_scrollController.offset - 160).clamp(0.0, _scrollController.position.maxScrollExtent),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        icon: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
                        tooltip: 'Scroll right',
                        onPressed: () {
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              (_scrollController.offset + 160).clamp(0.0, _scrollController.position.maxScrollExtent),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      '${widget.suggestedUsers.length} cinephiles',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 176,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                ),
                child: ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.suggestedUsers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final user = widget.suggestedUsers[index];
                    final isFollowing = widget.followingMap?[user.id] ?? user.isFollowing;
                    final isLoadingFollow = widget.loadingFollowMap?[user.id] ?? false;
                    final reason = user.suggestionReason?.isNotEmpty == true
                        ? user.suggestionReason!
                        : (user.bio?.isNotEmpty == true ? user.bio! : 'Active Cinephile');

                    return Container(
                      width: 144,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFollowing
                              ? Colors.green.withValues(alpha: 0.35)
                              : AppColors.primary.withValues(alpha: 0.18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Clickable Profile Header (Avatar, Name, Handle, Reason)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  widget.onUserTap?.call(user);
                                },
                                mouseCursor: SystemMouseCursors.click,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                child: Tooltip(
                                  message: 'View @${user.username}\'s profile',
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                                    child: Column(
                                      children: [
                                        WHAvatar(
                                          imageUrl: user.profilePictureUrl,
                                          name: user.displayName ?? user.username,
                                          radius: 21,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          user.displayName ?? user.username,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '@${user.username}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 10.5,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            reason,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Follow / Following Action Button
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                              child: SizedBox(
                                width: double.infinity,
                                height: 28,
                                child: isFollowing
                                    ? OutlinedButton(
                                        onPressed: isLoadingFollow
                                            ? null
                                            : () {
                                                HapticFeedback.lightImpact();
                                                widget.onFollowUser?.call(user);
                                              },
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          side: BorderSide(
                                            color: Colors.green.withValues(alpha: 0.6),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        child: isLoadingFollow
                                            ? const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 1.5,
                                                  color: Colors.green,
                                                ),
                                              )
                                            : const Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.check, size: 12, color: Colors.green),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Following',
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      )
                                    : ElevatedButton(
                                        onPressed: isLoadingFollow
                                            ? null
                                            : () {
                                                HapticFeedback.lightImpact();
                                                widget.onFollowUser?.call(user);
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.black,
                                          padding: EdgeInsets.zero,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                        child: isLoadingFollow
                                            ? const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 1.5,
                                                  color: Colors.black,
                                                ),
                                              )
                                            : const Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.person_add_rounded, size: 12),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Follow',
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Actions Row: "Add Friends" Primary + "Cancel" Secondary
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onAddFriends();
                },
                icon: const Icon(Icons.person_search_rounded, size: 16),
                label: const Text(
                  'Add Friends',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  widget.onDismiss();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
