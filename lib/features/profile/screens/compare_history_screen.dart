import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

class CompareHistoryScreen extends ConsumerStatefulWidget {
  final String userId;

  const CompareHistoryScreen({super.key, required this.userId});

  @override
  ConsumerState<CompareHistoryScreen> createState() => _CompareHistoryScreenState();
}

class _CompareHistoryScreenState extends ConsumerState<CompareHistoryScreen> {
  Map<String, dynamic>? _compareData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCompareData();
  }

  Future<void> _fetchCompareData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/entries/compare/${widget.userId}');
      if (mounted) {
        setState(() {
          _compareData = response.data as Map<String, dynamic>;
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
    final user2 = _compareData?['user2'] as Map<String, dynamic>?;
    final username = user2?['username'] as String? ?? 'Friend';
    final stats = _compareData?['stats'] as Map<String, dynamic>?;
    final overlapScore = (stats?['overlapScore'] as num?)?.toInt() ?? 0;
    final sharedCount = (stats?['sharedCount'] as num?)?.toInt() ?? 0;
    final sharedEntries = (_compareData?['sharedEntries'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Taste Overlap with @$username'),
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
                      Text('Failed to compare: $_error', style: const TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchCompareData,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overlap Score Hero Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'CINEMATIC TASTE OVERLAP',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 1.2,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '$overlapScore%',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w900,
                                fontSize: 44,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$sharedCount Shared Movies & Shows Watched',
                              style: const TextStyle(fontSize: 13, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Shared Watch History',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (sharedEntries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No shared movies or shows recorded yet.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sharedEntries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final item = sharedEntries[i] as Map<String, dynamic>;
                            final title = item['title'] as String? ?? 'Shared Title';
                            final rating1 = (item['user1Rating'] as num?)?.toDouble();
                            final rating2 = (item['user2Rating'] as num?)?.toDouble();

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.movie, color: AppColors.primary, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            if (rating1 != null)
                                              Text('You: ⭐ ${rating1.toStringAsFixed(1)}   ', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                            if (rating2 != null)
                                              Text('@$username: ⭐ ${rating2.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }
}
