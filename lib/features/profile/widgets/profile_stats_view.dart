import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../repositories/user_repository.dart';

class ProfileStatsView extends ConsumerStatefulWidget {
  const ProfileStatsView({super.key});

  @override
  ConsumerState<ProfileStatsView> createState() => _ProfileStatsViewState();
}

class _ProfileStatsViewState extends ConsumerState<ProfileStatsView> {
  int _days = 30;
  String _type = '';
  String _genre = '';
  double _minRating = 0;

  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await ref.read(userRepositoryProvider).getDetailedStats(
            days: _days,
            type: _type.isNotEmpty ? _type : null,
            genre: _genre.isNotEmpty ? _genre : null,
            minRating: _minRating > 0 ? _minRating : null,
          );

      if (mounted) {
        setState(() {
          _data = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Could not load watch analytics. Please try again.',
          );
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeframes = [
      {'label': '7D', 'value': 7},
      {'label': '30D', 'value': 30},
      {'label': '90D', 'value': 90},
      {'label': '1Y', 'value': 365},
      {'label': 'ALL TIME', 'value': 0},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeframe Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: timeframes.map((tf) {
                final isSelected = _days == tf['value'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      tf['label'] as String,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _days = tf['value'] as int);
                        _fetchStats();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Type Filter
                _buildDropdown(
                  value: _type,
                  hint: 'All Types',
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All Types')),
                    DropdownMenuItem(value: 'MOVIE', child: Text('Movies Only')),
                    DropdownMenuItem(value: 'TV_SHOW', child: Text('TV Shows')),
                  ],
                  onChanged: (val) {
                    setState(() => _type = val ?? '');
                    _fetchStats();
                  },
                ),
                const SizedBox(width: 8),

                // Rating Filter
                _buildDropdown(
                  value: _minRating.toString(),
                  hint: 'Any Rating',
                  items: const [
                    DropdownMenuItem(value: '0.0', child: Text('Any Rating')),
                    DropdownMenuItem(value: '9.0', child: Text('⭐ 9+ Stars')),
                    DropdownMenuItem(value: '8.0', child: Text('⭐ 8+ Stars')),
                    DropdownMenuItem(value: '7.0', child: Text('⭐ 7+ Stars')),
                    DropdownMenuItem(value: '6.0', child: Text('⭐ 6+ Stars')),
                  ],
                  onChanged: (val) {
                    setState(() => _minRating = double.tryParse(val ?? '0') ?? 0);
                    _fetchStats();
                  },
                ),

                // Clear Filters Button
                if (_type.isNotEmpty || _genre.isNotEmpty || _minRating > 0) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _type = '';
                        _genre = '';
                        _minRating = 0;
                      });
                      _fetchStats();
                    },
                    icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                    label: const Text('Reset', style: TextStyle(fontSize: 12, color: AppColors.error)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main Content
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _fetchStats,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_data == null || (_data!['summary']?['totalCount'] ?? 0) == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No Watches in this Range',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'No watch entries match the current timeframe and filters. Try changing your filters or choosing All Time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _days = 0;
                        _type = '';
                        _genre = '';
                        _minRating = 0;
                      });
                      _fetchStats();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('View All-Time Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else
            _buildAnalyticsContent(_data!),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textMuted),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          dropdownColor: AppColors.surface,
        ),
      ),
    );
  }

  Widget _buildAnalyticsContent(Map<String, dynamic> data) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final totalCount = summary['totalCount'] ?? 0;
    final avgRating = (summary['averageRating'] as num?)?.toDouble() ?? 0.0;
    final typeBreakdown = (data['typeBreakdown'] as List<dynamic>?) ?? [];
    final viewingRhythm = (data['viewingRhythm'] as List<dynamic>?) ?? [];
    final timeSeries = (data['timeSeries'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.movie_outlined,
                value: '$totalCount',
                label: 'Watches',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.star_rounded,
                value: avgRating > 0 ? avgRating.toStringAsFixed(1) : '—',
                label: 'Avg Rating',
                color: Colors.amber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.calendar_today_rounded,
                value: _days == 0 ? 'All' : '$_days d',
                label: 'Timeframe',
                color: AppColors.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Media Breakdown
        if (typeBreakdown.isNotEmpty) ...[
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
                const Text(
                  'Media Breakdown',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...typeBreakdown.map((t) {
                  final name = t['name'] == 'MOVIE'
                      ? '🎬 Movies'
                      : t['name'] == 'TV_SHOW'
                          ? '📺 TV Shows'
                          : '📺 Episodes';
                  final count = (t['count'] as num?)?.toInt() ?? 0;
                  final percentage = totalCount > 0 ? (count / totalCount) : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            Text('$count (${(percentage * 100).toStringAsFixed(0)}%)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: percentage,
                            minHeight: 8,
                            backgroundColor: AppColors.surfaceHighest,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Viewing Rhythm (Time of day breakdown)
        if (viewingRhythm.isNotEmpty) ...[
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
                    Icon(Icons.schedule_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Viewing Rhythm',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.4,
                  children: viewingRhythm.map((r) {
                    final label = r['label'] as String? ?? 'Rhythm';
                    final count = (r['count'] as num?)?.toInt() ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border.withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMuted,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$count watches',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Daily Activity Bar Chart
        if (timeSeries.isNotEmpty) ...[
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
                    Icon(Icons.show_chart_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Daily Activity Trend',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: timeSeries.take(30).map((ts) {
                      final count = (ts['count'] as num?)?.toInt() ?? 0;
                      final maxCount = timeSeries
                          .map((e) => (e['count'] as num?)?.toInt() ?? 0)
                          .reduce((a, b) => a > b ? a : b);
                      final ratio = maxCount > 0 ? (count / maxCount) : 0.0;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (count > 0)
                                Text(
                                  '$count',
                                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                ),
                              Container(
                                height: (ratio * 70).clamp(4.0, 70.0),
                                decoration: BoxDecoration(
                                  color: count > 0 ? AppColors.primary : AppColors.surfaceHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color == AppColors.primary ? AppColors.primaryDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
