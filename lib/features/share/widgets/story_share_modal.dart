import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/web_urls.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/wh_alert.dart';
import '../../../shared/widgets/wh_button.dart';
import 'instagram_story_card.dart';

/// Interactive modal sheet that renders a 9:16 Instagram Story card preview
/// and enables 1-tap sharing to Instagram, WhatsApp, Stories, or saving to device.
class StoryShareModal extends StatefulWidget {
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final double? rating;
  final String? review;
  final int? tmdbId;
  final String mediaType;
  final String? releaseYear;
  final String? userDisplayName;
  final String? username;
  final String? userAvatarUrl;
  final bool isCompleted;
  final StoryShareMode shareMode;

  const StoryShareModal({
    super.key,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.rating,
    this.review,
    this.tmdbId,
    this.mediaType = 'movie',
    this.releaseYear,
    this.userDisplayName,
    this.username,
    this.userAvatarUrl,
    this.isCompleted = true,
    StoryShareMode? shareMode,
  }) : shareMode = shareMode ?? (isCompleted ? StoryShareMode.logged : StoryShareMode.watching);

  /// Displays the StoryShareModal as a responsive modal bottom sheet.
  static Future<void> show(
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StoryShareModal(
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
      ),
    );
  }

  @override
  State<StoryShareModal> createState() => _StoryShareModalState();
}

class _StoryShareModalState extends State<StoryShareModal> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _isGenerating = false;

  String get _movieUrl {
    if (widget.tmdbId != null && widget.tmdbId! > 0) {
      return WebUrls.movieDetails(
        widget.mediaType,
        widget.tmdbId!,
        suggestedByUsername: widget.username,
        source: 'story',
      );
    }
    return WebUrls.baseUrl;
  }

  String get _shareText {
    final name = widget.userDisplayName ?? widget.username;
    switch (widget.shareMode) {
      case StoryShareMode.logged:
        final namePrefix = (name != null && name.trim().isNotEmpty)
            ? '$name watched'
            : 'Watched';
        final ratingPart = (widget.rating != null && widget.rating! > 0)
            ? ' (⭐️ ${widget.rating!.toStringAsFixed(1)}/10)'
            : '';
        return '🍿 $namePrefix "${widget.title}"$ratingPart on WatchersHive! 🐝\n\nView details: $_movieUrl';

      case StoryShareMode.watching:
        final namePrefix = (name != null && name.trim().isNotEmpty)
            ? '$name is currently watching'
            : 'Currently watching';
        return '📺 $namePrefix "${widget.title}" on WatchersHive! 🐝\n\nJoin the watch: $_movieUrl';

      case StoryShareMode.general:
        return '🎬 Check out "${widget.title}" on WatchersHive! 🐝\n\nDiscover movies, rate & track together: $_movieUrl';
    }
  }

  Future<void> _shareToStory() async {
    if (_isGenerating) return;

    setState(() => _isGenerating = true);
    HapticFeedback.mediumImpact();

    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        // Fallback to text sharing if render boundary is unavailable
        await Share.share(_shareText, subject: 'WatchersHive: ${widget.title}');
        return;
      }

      // Generate ultra-sharp 3.0x pixel ratio image (1080x1920)
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        await Share.share(_shareText, subject: 'WatchersHive: ${widget.title}');
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/watchershive_story_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes, flush: true);

      if (!mounted) return;

      // Invoke system share sheet with image file (supports Instagram Stories, Feed, Chats, etc.)
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: 'watchershive_${widget.title}.png')],
        text: _shareText,
        subject: 'WatchersHive: ${widget.title}',
      );
    } catch (e) {
      debugPrint('[StoryShareModal] Share error: $e');
      if (mounted) {
        // Fallback to text share on any unexpected failure
        await Share.share(_shareText, subject: 'WatchersHive: ${widget.title}');
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _movieUrl));
    HapticFeedback.lightImpact();
    if (mounted) {
      WHAlert.showSuccess(context, 'Link copied to clipboard! 📋');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: AppColors.primaryDark, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Share to Story',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Story Card Live Preview (9:16 aspect ratio preview)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 320,
                  height: 568.8, // 320 * 16 / 9 = 568.8 (standard 9:16 story ratio)
                  child: RepaintBoundary(
                    key: _repaintBoundaryKey,
                    child: InstagramStoryCard(
                      title: widget.title,
                      posterPath: widget.posterPath,
                      backdropPath: widget.backdropPath,
                      rating: widget.rating,
                      review: widget.review,
                      tmdbId: widget.tmdbId,
                      mediaType: widget.mediaType,
                      releaseYear: widget.releaseYear,
                      userDisplayName: widget.userDisplayName,
                      username: widget.username,
                      userAvatarUrl: widget.userAvatarUrl,
                      isCompleted: widget.isCompleted,
                      shareMode: widget.shareMode,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Action Buttons
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main Share Button
                  WHButton(
                    label: _isGenerating ? 'Preparing Story Card...' : 'Share to Instagram / Stories',
                    isLoading: _isGenerating,
                    onPressed: _shareToStory,
                  ),
                  const SizedBox(height: 10),

                  // Secondary Actions: Copy Link & Text Share
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _copyLink,
                          icon: const Icon(Icons.link_rounded, size: 18, color: AppColors.primaryDark),
                          label: const Text(
                            'Copy Link',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Share.share(_shareText, subject: 'WatchersHive: ${widget.title}');
                          },
                          icon: const Icon(Icons.text_fields_rounded, size: 18, color: AppColors.primaryDark),
                          label: const Text(
                            'Share Text',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
