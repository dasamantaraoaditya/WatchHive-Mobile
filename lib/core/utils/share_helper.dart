import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../config/web_urls.dart';

/// Helper utility for generating formatted social sharing content for WatchersHive entries.
class ShareHelper {
  ShareHelper._();

  /// Shares a completed watch post to any installed social media app or system share sheet.
  static Future<void> shareCompletedWatch({
    required String title,
    double? rating,
    String? review,
    int? tmdbId,
    String mediaType = 'movie',
    String? userDisplayName,
  }) async {
    HapticFeedback.lightImpact();

    final buffer = StringBuffer();
    final namePrefix = (userDisplayName != null && userDisplayName.trim().isNotEmpty)
        ? '$userDisplayName finished'
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
