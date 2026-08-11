import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../search/repositories/search_repository.dart';
import '../../entries/screens/add_entry_sheet.dart';

class MovieDetailsScreen extends ConsumerStatefulWidget {
  final String mediaType;
  final int tmdbId;

  const MovieDetailsScreen({
    super.key,
    required this.mediaType,
    required this.tmdbId,
  });

  @override
  ConsumerState<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends ConsumerState<MovieDetailsScreen> {
  Map<String, dynamic>? _details;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final repo = ref.read(searchRepositoryProvider);
      final details = widget.mediaType == 'movie'
          ? await repo.getMovieDetails(widget.tmdbId)
          : await repo.getTvDetails(widget.tmdbId);
      setState(() {
        _details = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _logEntry() {
    final details = _details;
    if (details == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: AddEntrySheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_error != null || _details == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(_error ?? 'Not found', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _loadDetails, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final details = _details!;
    final title = (details['title'] ?? details['name']) as String? ?? '';
    final overview = details['overview'] as String? ?? '';
    final posterPath = details['poster_path'] as String?;
    final backdropPath = details['backdrop_path'] as String?;
    final releaseDate = (details['release_date'] ?? details['first_air_date']) as String? ?? '';
    final voteAverage = (details['vote_average'] as num?)?.toDouble();
    final genres = (details['genres'] as List<dynamic>?)
            ?.map((g) => (g as Map<String, dynamic>)['name'] as String)
            .toList() ??
        [];
    final runtime = details['runtime'] as int?;
    final seasons = details['number_of_seasons'] as int?;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Hero backdrop header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (backdropPath != null)
                    CachedNetworkImage(
                      imageUrl: 'https://image.tmdb.org/t/p/w780$backdropPath',
                      fit: BoxFit.cover,
                    )
                  else
                    Container(color: AppColors.surface),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.background],
                        stops: [0.4, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Details content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Title + Rating row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Poster thumbnail
                    TMDBPosterImage(posterPath: posterPath, width: 80, height: 120),
                    const SizedBox(width: 16),
                    // Meta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (voteAverage != null && voteAverage > 0) ...[
                            WHRatingStars(rating: voteAverage),
                            const SizedBox(height: 6),
                          ],
                          if (releaseDate.isNotEmpty)
                            Text(
                              releaseDate.length >= 4 ? releaseDate.substring(0, 4) : releaseDate,
                              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          if (runtime != null)
                            Text(
                              '${runtime}min',
                              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          if (seasons != null)
                            Text(
                              '$seasons Season${seasons > 1 ? "s" : ""}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Genres
                if (genres.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: genres
                        .map((g) => WHChip(label: g))
                        .toList(),
                  ),
                const SizedBox(height: 20),

                // Log Entry Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logEntry,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Log This'),
                  ),
                ),
                const SizedBox(height: 24),

                // Overview
                if (overview.isNotEmpty) ...[
                  const Text(
                    'Overview',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    overview,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textSecondary, height: 1.6),
                  ),
                  const SizedBox(height: 80),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
