import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/models/suggestion.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../repositories/suggestions_repository.dart';
import 'suggest_movie_modal.dart';
import 'suggestion_card.dart';

class SuggestionsTab extends ConsumerStatefulWidget {
  final Function(int tmdbId, String mediaType, User? suggestor)? onTapMedia;

  const SuggestionsTab({super.key, this.onTapMedia});

  @override
  ConsumerState<SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends ConsumerState<SuggestionsTab> {
  int _selectedSubTab = 0; // 0: Received Suggestions, 1: Suggested Items
  List<GroupedSuggestion> _receivedGroups = [];
  List<GroupedSuggestion> _sentGroups = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(suggestionsRepositoryProvider);
      final results = await Future.wait([
        repo.getMySuggestions(),
        repo.getSentSuggestions(),
      ]);
      if (mounted) {
        setState(() {
          _receivedGroups = results[0];
          _sentGroups = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserFriendlyMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSubTabButton({
    required int index,
    required IconData icon,
    required String label,
    required int count,
  }) {
    final isSelected = _selectedSubTab == index;
    return GestureDetector(
      onTap: () {
        if (_selectedSubTab != index) {
          setState(() {
            _selectedSubTab = index;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.6) : AppColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primaryDark : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentList = _selectedSubTab == 0 ? _receivedGroups : _sentGroups;
    final filteredGroups = currentList.where((g) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final tmdbStr = g.tmdbId.toString();
      final names = _selectedSubTab == 0
          ? g.suggestors.map((s) => '${s.displayName} ${s.username}').join(' ').toLowerCase()
          : g.recipients.map((r) => '${r.displayName} ${r.username}').join(' ').toLowerCase();
      return tmdbStr.contains(q) || names.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchSuggestions,
      color: AppColors.primary,
      child: Column(
        children: [
          // Sub-tabs Toggle: Received Suggestions vs Suggested Items
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: _buildSubTabButton(
                    index: 0,
                    icon: Icons.inbox_rounded,
                    label: 'Received',
                    count: _receivedGroups.length,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSubTabButton(
                    index: 1,
                    icon: Icons.send_rounded,
                    label: 'Suggested Items',
                    count: _sentGroups.length,
                  ),
                ),
              ],
            ),
          ),

          // Header action strip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedSubTab == 0
                        ? 'Recommendations from your Hive'
                        : 'Titles you recommended to friends',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await SuggestMovieModal.show(context);
                    _fetchSuggestions();
                  },
                  icon: const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                  label: const Text(
                    'Suggest',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          // Search Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: _selectedSubTab == 0
                    ? 'Search received recommendations…'
                    : 'Search items you suggested…',
                hintStyle: const TextStyle(fontFamily: 'Inter', color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const WHSkeletonGrid()
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 14),
                              const Text(
                                'Could not load suggestions',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: _fetchSuggestions,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                label: const Text('Tap to Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filteredGroups.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                                    ),
                                    child: Icon(
                                      _selectedSubTab == 0 ? Icons.lightbulb_outline_rounded : Icons.send_rounded,
                                      size: 48,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No matches for "$_searchQuery"'
                                        : (_selectedSubTab == 0 ? 'No Received Suggestions' : 'No Suggested Items Yet'),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Try searching by a different name or ID'
                                        : (_selectedSubTab == 0
                                            ? 'When your cinephile friends recommend movies or TV shows to you, they will show up here!'
                                            : 'You haven\'t recommended any titles to friends yet. Spread your cinema taste!'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await SuggestMovieModal.show(context);
                                      _fetchSuggestions();
                                    },
                                    icon: const Icon(Icons.auto_awesome, size: 16),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    ),
                                    label: const Text('Suggest to Friends', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.63,
                            ),
                            itemCount: filteredGroups.length,
                            itemBuilder: (ctx, i) => SuggestionCard(
                              group: filteredGroups[i],
                              isSent: _selectedSubTab == 1,
                              onRefresh: _fetchSuggestions,
                              onTapMedia: widget.onTapMedia,
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
