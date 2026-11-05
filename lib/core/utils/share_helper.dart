import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../config/web_urls.dart';
import '../router/app_router.dart';
import '../../features/share/widgets/instagram_story_card.dart';
import '../../features/share/widgets/story_share_modal.dart';

export '../../features/share/widgets/instagram_story_card.dart' show StoryShareMode;

/// Helper utility for generating formatted social sharing content for WatchersHive entries.
class ShareHelper {
  ShareHelper._();

  /// Displays the interactive 9:16 Instagram Story share preview modal.
  static Future<void> showStoryShareModal(
    BuildContext context, {
    required String title,
    String? posterPath,
    String? backdropPath,
    double? rating,
    String? review,
    int? tmdbId,
    String mediaType = 'movie',
    String? releaseYear,
    String? userDisplayName,
    String? username,
    String? userAvatarUrl,
    bool isCompleted = true,
    StoryShareMode? shareMode,
  }) {
    return StoryShareModal.show(
      context,
      title: title,
      posterPath: posterPath,
      backdropPath: backdropPath,
      rating: rating,
      review: review,
      tmdbId: tmdbId,
      mediaType: mediaType,
      releaseYear: releaseYear,
      userDisplayName: userDisplayName,
      username: username,
      userAvatarUrl: userAvatarUrl,
      isCompleted: isCompleted,
      shareMode: shareMode,
    );
  }

  /// Shares a watch post. If a [context] is provided, opens the visual
  /// 9:16 Instagram Story modal with live card preview, pictorial rating, and image generation.
  /// Otherwise, falls back to text sharing with deep link.
  static Future<void> shareCompletedWatch({
    BuildContext? context,
    required String title,
    String? posterPath,
    String? backdropPath,
    double? rating,
    String? review,
    int? tmdbId,
    String mediaType = 'movie',
    String? releaseYear,
    String? userDisplayName,
    String? username,
    String? userAvatarUrl,
    bool isCompleted = true,
    StoryShareMode? shareMode,
  }) async {
    final effectiveMode = shareMode ?? (isCompleted ? StoryShareMode.logged : StoryShareMode.watching);

    final safeContext = (context != null && context.mounted)
        ? context
        : (rootNavigatorKey.currentContext?.mounted == true
            ? rootNavigatorKey.currentContext
            : null);

    if (safeContext != null) {
      await showStoryShareModal(
        safeContext,
        title: title,
        posterPath: posterPath,
        backdropPath: backdropPath,
        rating: rating,
        review: review,
        tmdbId: tmdbId,
        mediaType: mediaType,
        releaseYear: releaseYear,
        userDisplayName: userDisplayName,
        username: username,
        userAvatarUrl: userAvatarUrl,
        isCompleted: isCompleted,
        shareMode: effectiveMode,
      );
      return;
    }

    HapticFeedback.lightImpact();

    final buffer = StringBuffer();
    final name = userDisplayName ?? username;

    switch (effectiveMode) {
      case StoryShareMode.logged:
        final namePrefix = (name != null && name.trim().isNotEmpty)
            ? '$name finished'
            : 'Finished';
        buffer.writeln('🍿 $namePrefix watching "$title" on WatchersHive! 🐝');
        if (rating != null && rating > 0) {
          buffer.writeln('⭐️ Rating: ${rating.toStringAsFixed(1)}/10');
        }
        if (review != null && review.trim().isNotEmpty) {
          final clean = review.trim();
          final snippet = clean.length > 140 ? '${clean.substring(0, 137)}...' : clean;
          buffer.writeln('"$snippet"');
        }
        break;

      case StoryShareMode.watching:
        final namePrefix = (name != null && name.trim().isNotEmpty)
            ? '$name is currently watching'
            : 'Currently watching';
        buffer.writeln('📺 $namePrefix "$title" on WatchersHive! 🐝');
        break;

      case StoryShareMode.general:
        buffer.writeln('🎬 Check out "$title" on WatchersHive! 🐝');
        if (rating != null && rating > 0) {
          buffer.writeln('★ TMDB Rating: ${rating.toStringAsFixed(1)}/10');
        }
        break;
    }

    buffer.writeln();
    if (tmdbId != null && tmdbId > 0) {
      buffer.writeln(WebUrls.movieDetails(mediaType, tmdbId, source: 'share'));
    } else {
      buffer.writeln('Track movies & series with me on WatchersHive: https://watchershive.com');
    }

    await Share.share(
      buffer.toString().trim(),
      subject: 'WatchersHive: $title',
    );
  }
}
