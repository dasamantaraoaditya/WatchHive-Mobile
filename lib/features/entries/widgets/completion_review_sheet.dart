import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/wh_rating_picker.dart';

class CompletionReviewSheetResult {
  final double? rating;
  final String? review;
  final bool postToFeed;
  final bool skipped;

  const CompletionReviewSheetResult({
    this.rating,
    this.review,
    this.postToFeed = true,
    this.skipped = false,
  });
}

class CompletionReviewSheet extends StatefulWidget {
  final String title;
  final int seasonNumber;
  final int episodeNumber;
  final bool isSeriesComplete;
  final String? posterPath;
  final double? initialRating;
  final String? initialReview;

  const CompletionReviewSheet({
    super.key,
    required this.title,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.isSeriesComplete,
    this.posterPath,
    this.initialRating,
    this.initialReview,
  });

  static Future<CompletionReviewSheetResult?> show(
    BuildContext context, {
    required String title,
    required int seasonNumber,
    required int episodeNumber,
    required bool isSeriesComplete,
    String? posterPath,
    double? initialRating,
    String? initialReview,
  }) {
    return showModalBottomSheet<CompletionReviewSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: CompletionReviewSheet(
          title: title,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
          isSeriesComplete: isSeriesComplete,
          posterPath: posterPath,
          initialRating: initialRating,
          initialReview: initialReview,
        ),
      ),
    );
  }

  @override
  State<CompletionReviewSheet> createState() => _CompletionReviewSheetState();
}

class _CompletionReviewSheetState extends State<CompletionReviewSheet> {
  late double _rating;
  late final TextEditingController _reviewController;
  bool _postToFeed = true;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating ?? 0.0;
    _reviewController = TextEditingController(text: widget.initialReview ?? '');
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  void _submit() {
    HapticFeedback.mediumImpact();
    final reviewText = _reviewController.text.trim();
    Navigator.of(context).pop(
      CompletionReviewSheetResult(
        rating: _rating > 0 ? ((_rating * 10).round() / 10).clamp(0.5, 10.0) : null,
        review: reviewText.isNotEmpty ? reviewText : null,
        postToFeed: _postToFeed,
        skipped: false,
      ),
    );
  }

  void _skip() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(
      const CompletionReviewSheetResult(
        skipped: true,
        postToFeed: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final celebrationTitle = widget.isSeriesComplete
        ? 'Series Completed! 🏆'
        : 'Season ${widget.seasonNumber} Complete! 🎉';

    final celebrationSubtitle = widget.isSeriesComplete
        ? 'You just finished the finale! Drop a rating & review to share your verdict with the Hive.'
        : 'You finished the final episode of Season ${widget.seasonNumber}! How did it hold up?';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Celebration header card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.18),
                      AppColors.surfaceElevated,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.posterPath != null && widget.posterPath!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: 'https://image.tmdb.org/t/p/w185${widget.posterPath}',
                          width: 54,
                          height: 80,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 54,
                            height: 80,
                            color: AppColors.surface,
                            child: const Icon(Icons.tv_rounded, color: AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 54,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.celebration_rounded,
                          color: Color(0xFF2D2926),
                          size: 30,
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              celebrationTitle.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF262626),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            celebrationSubtitle,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Rating section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.star_rounded, size: 18, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'Honey Star Rating',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (_rating > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '⭐ ${_rating.toStringAsFixed(1)} / 10',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF262626),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    WHRatingPicker(
                      rating: _rating,
                      onRatingChanged: (val) {
                        setState(() => _rating = val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Review input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'Review & Thoughts',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '(Optional)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _reviewController,
                      maxLines: 4,
                      minLines: 2,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.isSeriesComplete
                            ? 'What made this series unforgettable? Share your takeaway...'
                            : 'Highlights, cliffhangers, or standout performances from this season...',
                        hintStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
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

              const SizedBox(height: 14),

              // Feed Visibility Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _postToFeed
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _postToFeed ? AppColors.primary : AppColors.border,
                    width: _postToFeed ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.rss_feed_rounded,
                      size: 18,
                      color: _postToFeed ? const Color(0xFF2D2926) : AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Feed Visibility',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _postToFeed ? 'Share to Community Feed' : 'Keep Private',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _postToFeed,
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withValues(alpha: 0.35),
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        setState(() => _postToFeed = val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF262626),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF262626)),
                      const SizedBox(width: 8),
                      Text(
                        _rating > 0 || _reviewController.text.trim().isNotEmpty
                            ? 'Submit Review & Complete'
                            : 'Complete Watching',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF262626),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Center(
                child: TextButton(
                  onPressed: _skip,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Skip & Mark Completed without Review',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
