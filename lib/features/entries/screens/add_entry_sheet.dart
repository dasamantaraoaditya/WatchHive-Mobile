import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/models/models.dart';
import '../repositories/entries_repository.dart';
import 'entries_screen.dart';
import '../../search/repositories/search_repository.dart';

class AddEntrySheet extends ConsumerStatefulWidget {
  final Entry? editEntry;

  const AddEntrySheet({super.key, this.editEntry});

  @override
  ConsumerState<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<AddEntrySheet> {
  final _titleController = TextEditingController();
  final _reviewController = TextEditingController();
  final _searchController = TextEditingController();

  String _type = 'MOVIE';
  double _rating = 0;
  bool _isRewatch = false;
  bool _isWatching = false;
  bool _isLoading = false;
  List<MediaResult> _searchResults = [];
  bool _isSearching = false;
  MediaResult? _selectedMedia;

  bool get isEditing => widget.editEntry != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final e = widget.editEntry!;
      _titleController.text = e.title;
      _reviewController.text = e.review ?? '';
      _type = e.type;
      _rating = e.rating ?? 0;
      _isRewatch = e.isRewatch;
      _isWatching = e.isWatching;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _reviewController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchMedia(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await ref.read(searchRepositoryProvider).searchMedia(query);
      setState(() => _searchResults = results.take(5).toList());
    } catch (_) {
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _save() async {
    final title = _selectedMedia?.title ?? _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or select a title'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        'tmdbId': _selectedMedia?.id ?? widget.editEntry?.tmdbId ?? 0,
        'title': title,
        'type': _type,
        'rating': _rating > 0 ? _rating : null,
        'review': _reviewController.text.trim().isNotEmpty ? _reviewController.text.trim() : null,
        'isRewatch': _isRewatch,
        'isWatching': _isWatching,
        'watchedAt': DateTime.now().toIso8601String(),
      };

      if (isEditing) {
        final updated = await ref.read(entriesRepositoryProvider).updateEntry(widget.editEntry!.id, data);
        ref.read(entriesProvider.notifier).updateEntry(updated);
      } else {
        final entry = await ref.read(entriesRepositoryProvider).createEntry(data);
        ref.read(entriesProvider.notifier).addEntry(entry);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Text(
                  isEditing ? 'Edit Entry' : 'Log Entry',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // TMDB Search
                  if (!isEditing) ...[
                    const _SectionLabel('Search (Optional)'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppColors.textPrimary),
                      onChanged: _searchMedia,
                      decoration: InputDecoration(
                        hintText: 'Search movie or TV show...',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                              )
                            : null,
                      ),
                    ),
                    if (_selectedMedia != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedMedia!.title,
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _selectedMedia = null;
                                _searchController.clear();
                                _searchResults.clear();
                              }),
                              child: const Icon(Icons.close_rounded, color: AppColors.primary, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: _searchResults.map((media) => _SearchResultTile(
                            media: media,
                            onTap: () {
                              setState(() {
                                _selectedMedia = media;
                                _titleController.text = media.title;
                                _type = media.mediaType == 'movie' ? 'MOVIE' : 'TV_SHOW';
                                _searchResults.clear();
                                _searchController.text = media.title;
                              });
                            },
                          )).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],

                  // Title
                  const _SectionLabel('Title'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppColors.textPrimary),
                    decoration: const InputDecoration(hintText: 'Movie or show title'),
                  ),
                  const SizedBox(height: 20),

                  // Type
                  const _SectionLabel('Type'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _TypeChip(label: '🎬 Movie', value: 'MOVIE', selected: _type == 'MOVIE', onTap: () => setState(() => _type = 'MOVIE')),
                      const SizedBox(width: 8),
                      _TypeChip(label: '📺 TV Show', value: 'TV_SHOW', selected: _type == 'TV_SHOW', onTap: () => setState(() => _type = 'TV_SHOW')),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Rating
                  const _SectionLabel('Rating (Optional)'),
                  const SizedBox(height: 8),
                  RatingBar.builder(
                    initialRating: _rating / 2,
                    minRating: 0,
                    maxRating: 5,
                    allowHalfRating: true,
                    itemSize: 32,
                    unratedColor: AppColors.surfaceHighest,
                    itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: AppColors.primary),
                    onRatingUpdate: (rating) => setState(() => _rating = rating * 2),
                  ),
                  if (_rating > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${_rating.toStringAsFixed(1)} / 10',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Review
                  const _SectionLabel('Review (Optional)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reviewController,
                    maxLines: 4,
                    maxLength: 5000,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'What did you think?',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Toggles
                  _Toggle(
                    label: '🔁 Mark as Rewatch',
                    value: _isRewatch,
                    onChanged: (v) => setState(() => _isRewatch = v),
                  ),
                  const SizedBox(height: 8),
                  _Toggle(
                    label: '▶ Currently Watching',
                    value: _isWatching,
                    onChanged: (v) => setState(() => _isWatching = v),
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : Text(isEditing ? 'Save Changes' : 'Log Entry'),
                    ),
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.15) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final MediaResult media;
  final VoidCallback onTap;

  const _SearchResultTile({required this.media, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              media.mediaType == 'movie' ? Icons.movie_creation_outlined : Icons.tv_outlined,
              color: AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.title,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  ),
                  if (media.year.isNotEmpty)
                    Text(media.year, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
