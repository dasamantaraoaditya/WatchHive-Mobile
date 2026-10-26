import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/suggestion.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Interactive modal sheet displaying complete read-only metadata for a suggestion:
/// - To whom it was suggested (recipients, usernames, avatars)
/// - Who suggested it (if received)
/// - Exact date and time when it was suggested
/// - Personal note / message
/// - Movie details & actions
class SuggestionDetailsModal extends StatelessWidget {
  final GroupedSuggestion group;
  final bool isSent;
  final String title;
  final String? posterPath;
  final VoidCallback? onMoveToWatching;
  final VoidCallback? onMarkWatched;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;

  const SuggestionDetailsModal({
    super.key,
    required this.group,
    required this.isSent,
    required this.title,
    this.posterPath,
    this.onMoveToWatching,
    this.onMarkWatched,
    this.onDelete,
    this.onViewDetails,
  });

  static Future<void> show(
    BuildContext context, {
    required GroupedSuggestion group,
    required bool isSent,
    String? title,
    String? posterPath,
    VoidCallback? onMoveToWatching,
    VoidCallback? onMarkWatched,
    VoidCallback? onDelete,
    VoidCallback? onViewDetails,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SuggestionDetailsModal(
        group: group,
        isSent: isSent,
        title: title ?? (group.mediaType == 'tv' ? 'TV Show #${group.tmdbId}' : 'Movie #${group.tmdbId}'),
        posterPath: posterPath,
        onMoveToWatching: onMoveToWatching,
        onMarkWatched: onMarkWatched,
        onDelete: onDelete,
        onViewDetails: onViewDetails,
      ),
    );
  }

  List<User> get _effectiveRecipients {
    if (group.recipients.isNotEmpty) return group.recipients;
    final fromSuggestions = group.suggestions
        .map((s) => s.recipient)
        .whereType<User>()
        .toList();
    if (fromSuggestions.isNotEmpty) return fromSuggestions;
    // Fallback pseudo-users if only IDs exist
    return group.suggestions
        .where((s) => s.toUserId.isNotEmpty && s.toUserId != 'me')
        .map((s) => User(
              id: s.toUserId,
              username: s.toUserId,
              displayName: 'Hive Member',
              createdAt: DateTime.now(),
            ))
        .toList();
  }

  List<User> get _effectiveSuggestors {
    if (group.suggestors.isNotEmpty) return group.suggestors;
    return group.suggestions
        .where((s) => s.fromUserId.isNotEmpty && s.fromUserId != 'me')
        .map((s) => User(
              id: s.fromUserId,
              username: s.fromUserId,
              displayName: 'Hive Friend',
              createdAt: DateTime.now(),
            ))
        .toList();
  }

  DateTime? get _earliestDate {
    final dates = group.suggestions
        .map((s) => DateTime.tryParse(s.createdAt))
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) return null;
    dates.sort((a, b) => a.compareTo(b));
    return dates.first;
  }

  DateTime? get _latestDate {
    final dates = group.suggestions
        .map((s) => DateTime.tryParse(s.createdAt))
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) return null;
    dates.sort((a, b) => b.compareTo(a));
    return dates.first;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isTv = group.mediaType == 'tv' || group.mediaType == 'TV_SHOW';
    final targetUsers = isSent ? _effectiveRecipients : _effectiveSuggestors;
    final primaryDate = _latestDate ?? _earliestDate;
    final fullPosterUrl = posterPath != null && posterPath!.isNotEmpty
        ? ApiEndpoints.resolveTmdbPosterUrl(posterPath!)
        : '';

    // Collect all unique non-empty messages
    final messages = group.suggestions
        .map((s) => s.message?.trim())
        .whereType<String>()
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Top Header: Title & Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSent ? Icons.send_rounded : Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSent ? 'Sent Suggestion Details' : 'Received Suggestion Details',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          isSent ? 'Metadata & recipients' : 'Metadata & sender notes',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceHighest,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Media Summary Banner
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
                            child: fullPosterUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: fullPosterUrl,
                                    width: 52,
                                    height: 76,
                                    fit: BoxFit.cover,
                                    placeholder: (ctx, url) => Container(
                                      color: AppColors.surfaceHighest,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (ctx, url, err) => Container(
                                      width: 52,
                                      height: 76,
                                      color: AppColors.surfaceHighest,
                                      child: const Icon(Icons.movie_rounded, color: AppColors.textMuted, size: 24),
                                    ),
                                  )
                                : Container(
                                    width: 52,
                                    height: 76,
                                    color: AppColors.surfaceHighest,
                                    child: const Icon(Icons.movie_rounded, color: AppColors.textMuted, size: 24),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isTv ? 'TV Show' : 'Movie',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceHighest,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Text(
                                        'TMDB #${group.tmdbId}',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section: Read-Only Metadata Header
                    Row(
                      children: [
                        Text(
                          isSent ? 'SUGGESTED TO' : 'SUGGESTED BY',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 10, color: AppColors.textMuted),
                              SizedBox(width: 3),
                              Text(
                                'Read-only',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // User List Card (Read-only)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: targetUsers.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.textMuted),
                                  const SizedBox(width: 8),
                                  Text(
                                    isSent ? 'Suggested to Hive member' : 'Suggested by Hive member',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: targetUsers.length,
                              separatorBuilder: (ctx, i) => const Divider(height: 1, color: AppColors.border),
                              itemBuilder: (ctx, i) {
                                final user = targetUsers[i];
                                final displayName = (user.displayName != null && user.displayName!.trim().isNotEmpty)
                                    ? user.displayName!.trim()
                                    : (user.username.isNotEmpty ? user.username : 'User');
                                final handle = user.username.startsWith('@') ? user.username : '@${user.username}';

                                return InkWell(
                                  onTap: user.id.isNotEmpty
                                      ? () {
                                          Navigator.of(context).pop();
                                          context.push('/profile/${user.id}');
                                        }
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Row(
                                      children: [
                                        WHAvatar(
                                          imageUrl: user.profilePictureUrl,
                                          name: displayName,
                                          radius: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                handle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primaryDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (user.id.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.surface,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Profile',
                                                  style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                                SizedBox(width: 2),
                                                Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.textMuted),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 16),

                    // Section: Suggestion Timestamp (Read-only)
                    const Text(
                      'SUGGESTION TIME',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF2D2926)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  primaryDate != null
                                      ? DateFormat('EEEE, MMMM d, yyyy').format(primaryDate.toLocal())
                                      : 'Date unavailable',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (primaryDate != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('h:mm a (z)').format(primaryDate.toLocal()),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2D2926),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Section: Attached Note / Message (if present)
                    if (messages.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'ATTACHED NOTE',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...messages.map(
                        (msg) => Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.format_quote_rounded, size: 20, color: Color(0xFF2D2926)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '“$msg”',
                                  style: const TextStyle(
                                    fontFamily: 'Georgia',
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13.5,
                                    height: 1.4,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Section: Status (Read-only)
                    const Text(
                      'STATUS',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSent ? Icons.outgoing_mail : Icons.mark_email_read_outlined,
                            size: 16,
                            color: AppColors.primaryDark,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isSent
                                ? 'Active recommendation sent to friends'
                                : 'Received recommendation waiting in your hive',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Actions Footer
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // View Movie Details Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onViewDetails?.call();
                          },
                          icon: const Icon(Icons.movie_outlined, size: 16),
                          label: const Text('View Title'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Delete / Dismiss Button
                      if (onDelete != null)
                        IconButton.filledTonal(
                          tooltip: isSent ? 'Delete Suggestion' : 'Dismiss Suggestion',
                          onPressed: () {
                            Navigator.of(context).pop();
                            onDelete?.call();
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.error.withValues(alpha: 0.12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                    ],
                  ),
                  if (!isSent && (onMoveToWatching != null || onMarkWatched != null)) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (onMoveToWatching != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                onMoveToWatching?.call();
                              },
                              icon: const Icon(Icons.play_circle_outline_rounded, size: 16, color: AppColors.info),
                              label: const Text('Log Watching'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.info,
                                side: BorderSide(color: AppColors.info.withValues(alpha: 0.4)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                textStyle: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        if (onMoveToWatching != null && onMarkWatched != null)
                          const SizedBox(width: 8),
                        if (onMarkWatched != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                onMarkWatched?.call();
                              },
                              icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.green),
                              label: const Text('Mark Watched'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green,
                                side: BorderSide(color: Colors.green.withValues(alpha: 0.4)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                textStyle: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
