import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/suggestion.dart';
import '../repositories/suggestions_repository.dart';
import 'suggestion_card.dart';

class SuggestionsTab extends ConsumerStatefulWidget {
  final Function(int tmdbId, String mediaType)? onTapMedia;

  const SuggestionsTab({super.key, this.onTapMedia});

  @override
  ConsumerState<SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends ConsumerState<SuggestionsTab> {
  List<GroupedSuggestion> _groups = [];
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
      final list = await repo.getMySuggestions();
      if (mounted) {
        setState(() {
          _groups = list;
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
    final filteredGroups = _groups.where((g) {
      if (_searchQuery.isEmpty) return true;
      final tmdbStr = g.tmdbId.toString();
      final suggestorNames = g.suggestors.map((s) => '${s.displayName} ${s.username}').join(' ').toLowerCase();
      return tmdbStr.contains(_searchQuery.toLowerCase()) || suggestorNames.contains(_searchQuery.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchSuggestions,
      color: AppColors.primary,
      child: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search recommendations by friend or ID…',
                hintStyle: const TextStyle(fontFamily: 'Inter', color: AppColors.textMuted, fontSize: 14),
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
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                            const SizedBox(height: 12),
                            Text('Failed to load suggestions: $_error', style: const TextStyle(color: AppColors.textMuted)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchSuggestions,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                              child: const Text('Retry', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            ),
                          ],
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
                                    child: const Icon(Icons.lightbulb_outline_rounded, size: 48, color: Colors.amber),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty ? 'No Hive Recommendations Yet' : 'No matches for "$_searchQuery"',
                                    style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'When your cinephile friends recommend movies or TV shows to you, they will show up here as rich poster cards!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontFamily: 'Inter', color: AppColors.textMuted, fontSize: 13, height: 1.4),
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
