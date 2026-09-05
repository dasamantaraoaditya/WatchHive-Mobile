import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/api/api_endpoints.dart';
import '../../profile/widgets/profile_stats_view.dart';
import '../repositories/mindlens_repository.dart';
import '../widgets/watch_frequency_chart.dart';
import '../../../shared/widgets/wh_skeleton.dart';

class MindLensScreen extends ConsumerStatefulWidget {
  const MindLensScreen({super.key});

  @override
  ConsumerState<MindLensScreen> createState() => _MindLensScreenState();
}

class _MindLensScreenState extends ConsumerState<MindLensScreen> {
  Map<String, dynamic>? _insights;
  bool _isLoading = true;
  String? _error;
  String _activeSubTab = 'highlights'; // 'highlights' or 'analytics'

  @override
  void initState() {
    super.initState();
    _fetchMindLensData();
  }

  Future<void> _fetchMindLensData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(mindLensRepositoryProvider);
      final data = await repo.getInsights();
      if (mounted) {
        setState(() {
          _insights = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserFriendlyMessage(e, defaultMessage: 'Could not generate MindLens insights at this time.');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.psychology_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text(
              'MindLens AI',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const WHSkeletonMindLens()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.psychology_alt_rounded, size: 40, color: AppColors.error),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'MindLens Unavailable',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetchMindLensData,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchMindLensData,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sub-tab Navigation (Psych Highlights vs Detailed Analytics)
                        _buildSubTabSelector(),
                        const SizedBox(height: 20),

                        // Active Sub-tab View
                        if (_activeSubTab == 'analytics') ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.analytics_rounded, color: AppColors.primary, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Deep Hive Analytics',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const ProfileStatsView(),
                        ] else ...[
                          // Psych Highlights Tab
                          if (_insights?['hasEnoughData'] == false)
                            _buildUnlockingState()
                          else ...[
                            // 1. Mood Forecast Hero Card
                            _buildMoodForecastCard(),
                            const SizedBox(height: 16),

                            // 2. Soul Persona Card
                            _buildSoulPersonaCard(),
                            const SizedBox(height: 16),

                            // 3. Interactive Watch Frequency Stream Chart
                            if (_insights?['dailyTimeSeries'] is List)
                              WatchFrequencyChart(
                                timeSeries: _insights!['dailyTimeSeries'] as List<dynamic>,
                              ),
                            const SizedBox(height: 16),

                            // 4. Behavioral Trails Grid
                            _buildBehavioralTrailsSection(),
                            const SizedBox(height: 16),

                            // 5. Suggestion Influence & Network Impact
                            _buildSuggestionInfluenceSection(),
                            const SizedBox(height: 16),

                            // 6. Psychological Insights (AI narrative)
                            _buildPsychologicalInsightsSection(),
                            const SizedBox(height: 16),

                            // 7. Aesthetic Palette Grid
                            _buildAestheticPaletteSection(),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  // ─── Sub-Tab Selector ──────────────────────────────────────────────────────

  Widget _buildSubTabSelector() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabPill('highlights', 'Psych Highlights'),
            _buildTabPill('analytics', 'Detailed Analytics'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill(String tabKey, String label) {
    final isSelected = _activeSubTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => _activeSubTab = tabKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.8,
            color: isSelected ? Colors.black : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  // ─── Unlocking / Not Enough Data State ──────────────────────────────────────

  Widget _buildUnlockingState() {
    final msg = _insights?['message'] as String? ??
        'Log at least 3 titles to generate your mood prediction and psychological traits.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: const Center(
              child: Text('🌱', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'MindLens Profile Unlocking...',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            msg,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'LOG AT LEAST 3 TITLES TO GENERATE YOUR MOOD PREDICTION AND PSYCHOLOGICAL TRAITS',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 9,
              letterSpacing: 1.0,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.push('/entries'),
            icon: const Icon(Icons.movie_filter_rounded, size: 18),
            label: const Text(
              'Log Watches Now',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. Mood Forecast Hero Card ────────────────────────────────────────────

  Widget _buildMoodForecastCard() {
    final moodData = _insights?['moodPrediction'] as Map<String, dynamic>?;
    if (moodData == null) return const SizedBox.shrink();

    final mood = moodData['mood'] as String? ?? 'Explorative & Cinematic';
    final status = moodData['status'] as String? ?? 'Active';
    final description = moodData['description'] as String? ?? '';
    final icon = moodData['icon'] as String? ?? '🎬';
    final confidence = (moodData['confidence'] as num?)?.toInt() ?? 88;
    final recentTitles = (moodData['recentTitles'] as List<dynamic>?) ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badges Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    const Text(
                      'PREDICTED MOOD STATE',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 1.0,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$confidence% Confidence',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Mood Title
          Text(
            mood,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),

          // Status subtitle
          Text(
            'Status: $status',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.5,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),

          // Description
          if (description.isNotEmpty)
            Text(
              description,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),

          // Recent Triggers
          if (recentTitles.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            const Text(
              'RECENT TRIGGERS (LAST LOGGED)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w900,
                fontSize: 9,
                letterSpacing: 1.0,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: recentTitles.map((title) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    title.toString(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 2. Soul Persona Card ──────────────────────────────────────────────────

  Widget _buildSoulPersonaCard() {
    final persona = _insights?['persona'] as Map<String, dynamic>?;
    if (persona == null) return const SizedBox.shrink();

    final name = persona['name'] as String? ?? 'Cinematic Voyager';
    final desc = persona['description'] as String? ?? '';
    final icon = persona['icon'] as String? ?? '🎬';
    final imageUrl = persona['imageUrl'] as String?;
    final colorHex = persona['color'] as String? ?? '#FFB700';

    Color themeColor = AppColors.primary;
    try {
      final hex = colorHex.replaceAll('#', '');
      themeColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}

    final primaryMood = _insights?['userProfile']?['primaryMood'] as String? ?? 'Balanced';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: themeColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Persona Avatar
          Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [themeColor, AppColors.primary],
              ),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Container(
                color: AppColors.surfaceElevated,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: Text(icon, style: const TextStyle(fontSize: 32)),
                        ),
                      )
                    : Center(
                        child: Text(icon, style: const TextStyle(fontSize: 32)),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Persona Tag
          Text(
            'SOUL PERSONA',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 2.0,
              color: themeColor,
            ),
          ),
          const SizedBox(height: 4),

          // Persona Title
          Text(
            name,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w900,
              fontSize: 19,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Persona Description
          Text(
            desc,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Dominant Vibe Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DOMINANT VIBE',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                  letterSpacing: 1.0,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                primaryMood,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 4. Behavioral Trails Section ──────────────────────────────────────────

  Widget _buildBehavioralTrailsSection() {
    final rawTrails = _insights?['behavioralTrails'] as List<dynamic>?;
    if (rawTrails == null || rawTrails.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.psychology_outlined, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Behavioral Trails',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rawTrails.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.88,
          ),
          itemBuilder: (context, index) {
            final trail = rawTrails[index] as Map<String, dynamic>;
            final title = trail['title'] as String? ?? 'Trail';
            final value = trail['value']?.toString() ?? '-';
            final subtitle = trail['subtitle'] as String? ?? '';
            final description = trail['description'] as String? ?? '';
            final colorHex = trail['color'] as String? ?? '#FFB700';

            Color color = AppColors.primary;
            try {
              final hex = colorHex.replaceAll('#', '');
              color = Color(int.parse('FF$hex', radix: 16));
            } catch (_) {}

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getIconForTrail(title),
                          color: color,
                          size: 16,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                              color: color,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: color,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  IconData _getIconForTrail(String title) {
    final t = title.toLowerCase();
    if (t.contains('velocity') || t.contains('pace') || t.contains('speed')) {
      return Icons.speed_rounded;
    }
    if (t.contains('rewatch') || t.contains('repeat')) {
      return Icons.repeat_rounded;
    }
    if (t.contains('versatility') || t.contains('diversity') || t.contains('genre')) {
      return Icons.pie_chart_outline_rounded;
    }
    if (t.contains('impact') || t.contains('influence') || t.contains('network')) {
      return Icons.hub_rounded;
    }
    return Icons.insights_rounded;
  }

  // ─── 5. Suggestion Influence & Network Impact ──────────────────────────────

  Widget _buildSuggestionInfluenceSection() {
    final analytics = _insights?['suggestionAnalytics'] as Map<String, dynamic>?;
    if (analytics == null) return const SizedBox.shrink();

    final summary = analytics['summary'] as Map<String, dynamic>?;
    final recommenders = (analytics['recommenders'] as List<dynamic>?) ?? [];
    final overallConversion = (summary?['overallConversionRate'] as num?)?.toInt() ?? 0;
    final watched = (summary?['totalSuggestionsWatched'] as num?)?.toInt() ?? 0;
    final received = (summary?['totalSuggestionsReceived'] as num?)?.toInt() ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.insights_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Suggestion Influence & Network',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Discover who recommended your favorite movies and how friends shape your watch history',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),

          // Summary conversion pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text(
                      'CONVERSION RATE',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w900,
                        fontSize: 8,
                        letterSpacing: 0.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$overallConversion%',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 24, color: AppColors.border),
                Column(
                  children: [
                    const Text(
                      'WATCHED / SUGGESTED',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w900,
                        fontSize: 8,
                        letterSpacing: 0.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$watched / $received',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Recommenders List / Empty state
          if (recommenders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.group_outlined, size: 36, color: AppColors.textMuted),
                    SizedBox(height: 8),
                    Text(
                      'No suggestion influence tracked yet',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'When friends recommend titles, their influence score and conversion will appear here!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recommenders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final rec = recommenders[index] as Map<String, dynamic>;
                final userId = rec['userId'] as String? ?? '';
                final username = rec['username'] as String? ?? 'friend';
                final displayName = rec['displayName'] as String? ?? username;
                final avatar = rec['profilePictureUrl'] as String?;
                final totalSuggested = (rec['totalSuggested'] as num?)?.toInt() ?? 0;
                final watchedCount = (rec['watchedCount'] as num?)?.toInt() ?? 0;
                final conversion = (rec['conversionRate'] as num?)?.toDouble() ?? 0.0;
                final avgRating = rec['avgRating']?.toString();
                final badge = rec['badge'] as String? ?? 'Taste Match';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      // User header
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: index == 0 ? AppColors.primary : AppColors.surfaceHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '#${index + 1}',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: index == 0 ? Colors.black : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              if (userId.isNotEmpty) {
                                context.push('/profile/$userId');
                              }
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.primary,
                                  backgroundImage: (avatar != null && avatar.isNotEmpty)
                                      ? CachedNetworkImageProvider(ApiEndpoints.resolveAvatarUrl(avatar))
                                      : null,
                                  child: (avatar == null || avatar.isEmpty)
                                      ? Text(
                                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w900,
                                            fontSize: 10,
                                            color: Colors.black,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '@$username',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 3-Metric Stats Row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  'SUGGESTED',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 8,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                Text(
                                  '$totalSuggested',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text(
                                  'WATCHED',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 8,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                Text(
                                  '$watchedCount',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: Color(0xFF22C55E),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text(
                                  'AVG RATING',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w800,
                                    fontSize: 8,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                Text(
                                  avgRating != null && avgRating.isNotEmpty ? '★ $avgRating' : '-',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Conversion Bar
                      Row(
                        children: [
                          const Text(
                            'Conversion',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${conversion.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (conversion / 100).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: AppColors.surface,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── 6. Psychological Insights Section ─────────────────────────────────────

  Widget _buildPsychologicalInsightsSection() {
    final insightsList = _insights?['insights'] as List<dynamic>?;
    if (insightsList == null || insightsList.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Psychological Insights',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...insightsList.map((ins) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildFormattedInsightText(ins.toString()),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFormattedInsightText(String text) {
    final spans = <TextSpan>[];
    final parts = text.split(RegExp(r'(\*\*.*?\*\*)'));

    for (final part in parts) {
      if (part.startsWith('**') && part.endsWith('**')) {
        spans.add(
          TextSpan(
            text: part.substring(2, part.length - 2),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: part,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        );
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13),
        children: spans,
      ),
    );
  }

  // ─── 7. Aesthetic Palette Section ──────────────────────────────────────────

  Widget _buildAestheticPaletteSection() {
    final aesthetics = _insights?['aesthetics'] as List<dynamic>?;
    if (aesthetics == null || aesthetics.isEmpty) return const SizedBox.shrink();

    final paletteStyles = {
      'Noir': (
        bg: const Color(0xFF1E1E1E),
        border: const Color(0xFF333333),
        text: const Color(0xFFFFF9F0),
      ),
      'Amber': (
        bg: const Color(0xFFB45309),
        border: const Color(0xFFF59E0B),
        text: Colors.black,
      ),
      'Concrete': (
        bg: const Color(0xFF475569),
        border: const Color(0xFF64748B),
        text: const Color(0xFFF1F5F9),
      ),
      'Forest': (
        bg: const Color(0xFF064E3B),
        border: const Color(0xFF059669),
        text: const Color(0xFFECFDF5),
      ),
      'Grit': (
        bg: const Color(0xFF292524),
        border: const Color(0xFF78716C),
        text: const Color(0xFFFDE68A),
      ),
      'Void': (
        bg: const Color(0xFF020617),
        border: const Color(0xFF1E293B),
        text: const Color(0xFF94A3B8),
      ),
      'Neon': (
        bg: const Color(0xFF9333EA),
        border: const Color(0xFFEC4899),
        text: Colors.white,
      ),
      'Pastel': (
        bg: const Color(0xFF332B1E),
        border: const Color(0xFFF59E0B),
        text: const Color(0xFFFEF3C7),
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.palette_outlined, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Aesthetic Palette',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: aesthetics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.8,
            ),
            itemBuilder: (context, index) {
              final aes = aesthetics[index].toString();
              final style = paletteStyles[aes] ?? paletteStyles['Void']!;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: style.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: style.border),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    aes.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: style.text,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
