import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';

class UserRankingsTab extends ConsumerStatefulWidget {
  final String userId;

  const UserRankingsTab({super.key, required this.userId});

  @override
  ConsumerState<UserRankingsTab> createState() => _UserRankingsTabState();
}

class _UserRankingsTabState extends ConsumerState<UserRankingsTab> {
  List<dynamic> _stacks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRankings();
  }

  Future<void> _fetchRankings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/lists/user/${widget.userId}/rankings');
      if (mounted) {
        final data = response.data;
        List<dynamic> parsedStacks = [];
        if (data is List) {
          parsedStacks = data;
        } else if (data is Map && data['items'] is List) {
          parsedStacks = data['items'] as List;
        }

        setState(() {
          _stacks = parsedStacks;
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 8),
            Text('Failed to load stacks: $_error', style: const TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }
    if (_stacks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.format_list_numbered, size: 40, color: AppColors.textMuted),
            SizedBox(height: 8),
            Text('No public ranking stacks created yet.', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _stacks.length,
      itemBuilder: (ctx, i) {
        final stack = _stacks[i] as Map<String, dynamic>;
        final name = stack['name'] as String? ?? 'Stack';
        final description = stack['description'] as String?;
        final items = (stack['items'] as List<dynamic>?) ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${items.length} Items',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
              const SizedBox(height: 12),
              ...items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value as Map<String, dynamic>;
                final title = item['title'] as String? ?? 'Movie #${item['tmdbId']}';
                final mediaType = item['mediaType'] == 'tv' ? 'tv' : 'movie';
                final tmdbId = item['tmdbId'];

                return GestureDetector(
                  onTap: () {
                    if (tmdbId != null) {
                      context.push('/details/$mediaType/$tmdbId');
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: idx == 0
                              ? Colors.amber
                              : idx == 1
                                  ? Colors.grey
                                  : idx == 2
                                      ? Colors.amber.shade900
                                      : Colors.white12,
                          child: Text(
                            '#${idx + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: idx <= 2 ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
