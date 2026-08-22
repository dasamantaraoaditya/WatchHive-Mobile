import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../repositories/mindlens_repository.dart';

class MindLensScreen extends ConsumerStatefulWidget {
  const MindLensScreen({super.key});

  @override
  ConsumerState<MindLensScreen> createState() => _MindLensScreenState();
}

class _MindLensScreenState extends ConsumerState<MindLensScreen> {
  Map<String, dynamic>? _insights;
  bool _isLoading = true;
  String? _error;

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
          _error = e.toString();
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
            Icon(Icons.psychology, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('MindLens AI'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text('Failed to load MindLens: $_error', style: const TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchMindLensData,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchMindLensData,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mood Prediction Banner
                        _buildMoodBanner(),
                        const SizedBox(height: 16),

                        // Soul Persona Card
                        _buildSoulPersonaCard(),
                        const SizedBox(height: 16),

                        // Recommenders Leaderboard
                        _buildRecommendersLeaderboard(),
                        const SizedBox(height: 16),

                        // Behavioral Analytics Grid
                        _buildBehavioralTrails(),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildMoodBanner() {
    final moodRaw = _insights?['moodPrediction'];
    String prediction = 'Explorative & Cinematic';
    if (moodRaw is Map<String, dynamic>) {
      prediction = moodRaw['mood'] as String? ?? prediction;
    } else if (moodRaw is String) {
      prediction = moodRaw;
    } else if (_insights?['prediction'] is String) {
      prediction = _insights!['prediction'] as String;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              SizedBox(width: 6),
              Text(
                'NEXT MOOD FORECAST',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            prediction,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoulPersonaCard() {
    Map<String, dynamic>? persona;
    if (_insights?['persona'] is Map<String, dynamic>) {
      persona = _insights!['persona'] as Map<String, dynamic>;
    } else if (_insights?['soulPersona'] is Map<String, dynamic>) {
      persona = _insights!['soulPersona'] as Map<String, dynamic>;
    }
    final name = persona?['name'] as String? ?? 'Cinematic Voyager';
    final desc = persona?['description'] as String? ?? 'Passionate cinema enthusiast exploring deep narratives and visual storytelling.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.stars_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'SOUL PERSONA',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendersLeaderboard() {
    Map<String, dynamic>? suggestionAnalytics;
    if (_insights?['suggestionAnalytics'] is Map<String, dynamic>) {
      suggestionAnalytics = _insights!['suggestionAnalytics'] as Map<String, dynamic>;
    }
    final leaderboard = (suggestionAnalytics?['recommenders'] as List<dynamic>?) ?? [];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.military_tech_rounded, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text(
                'TOP RECOMMENDER INFLUENCE',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (leaderboard.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No recommendation influence data yet.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leaderboard.length > 5 ? 5 : leaderboard.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 16),
              itemBuilder: (ctx, i) {
                final item = leaderboard[i] as Map<String, dynamic>;
                final username = item['username'] as String? ?? (item['user'] as Map<String, dynamic>?)?['username'] as String? ?? 'Friend';
                final count = (item['watchedCount'] as num?)?.toInt() ?? (item['totalSuggested'] as num?)?.toInt() ?? (item['count'] as num?)?.toInt() ?? 0;

                return Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: i == 0 ? Colors.amber : Colors.white10,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '#${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: i == 0 ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '@$username',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count Recs Accepted',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBehavioralTrails() {
    final rawTrails = _insights?['behavioralTrails'];
    String watchVelocity = '1.2 / wk';
    String rewatchRatio = '15%';
    String versatility = '84 / 100';

    if (rawTrails is List<dynamic>) {
      for (final item in rawTrails) {
        if (item is Map<String, dynamic>) {
          final title = (item['title'] as String? ?? '').toUpperCase();
          final val = item['value']?.toString() ?? '';
          if (title.contains('VELOCITY') || title.contains('PACE') || title.contains('FREQUENCY')) watchVelocity = val;
          if (title.contains('REWATCH')) rewatchRatio = val;
          if (title.contains('VERSATILITY') || title.contains('DIVERSITY')) versatility = val;
        }
      }
    } else if (rawTrails is Map<String, dynamic>) {
      watchVelocity = rawTrails['watchVelocity']?.toString() ?? watchVelocity;
      rewatchRatio = rawTrails['rewatchRatio']?.toString() ?? rewatchRatio;
      versatility = rawTrails['genreVersatility']?.toString() ?? versatility;
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildStatTile('WATCH VELOCITY', watchVelocity, Icons.speed_rounded, Colors.cyanAccent),
        _buildStatTile('REWATCH RATIO', rewatchRatio, Icons.repeat_rounded, Colors.purpleAccent),
        _buildStatTile('GENRE VERSATILITY', versatility, Icons.pie_chart_rounded, Colors.greenAccent),
        _buildStatTile('COMMUNITY IMPACT', 'High', Icons.hub_rounded, Colors.orangeAccent),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.0,
                  color: AppColors.textMuted,
                ),
              ),
              Icon(icon, color: iconColor, size: 18),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
