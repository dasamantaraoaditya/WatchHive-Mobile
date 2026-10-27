class UserPreferences {
  final List<String> languages;
  final List<String> genres;
  final List<int> genreIds;
  final List<String> streamingPlatforms;

  const UserPreferences({
    this.languages = const [],
    this.genres = const [],
    this.genreIds = const [],
    this.streamingPlatforms = const [],
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      genreIds: (json['genreIds'] as List<dynamic>?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .where((id) => id > 0)
              .toList() ??
          const [],
      streamingPlatforms: (json['streamingPlatforms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'languages': languages,
        'genres': genres,
        'genreIds': genreIds,
        'streamingPlatforms': streamingPlatforms,
      };

  bool get isEmpty =>
      languages.isEmpty && genres.isEmpty && streamingPlatforms.isEmpty;
  bool get isNotEmpty => !isEmpty;

  UserPreferences copyWith({
    List<String>? languages,
    List<String>? genres,
    List<int>? genreIds,
    List<String>? streamingPlatforms,
  }) {
    return UserPreferences(
      languages: languages ?? this.languages,
      genres: genres ?? this.genres,
      genreIds: genreIds ?? this.genreIds,
      streamingPlatforms: streamingPlatforms ?? this.streamingPlatforms,
    );
  }
}

class PreferenceOption<T> {
  final T id;
  final String label;
  final String emoji;

  const PreferenceOption({
    required this.id,
    required this.label,
    required this.emoji,
  });
}

class WatchHivePreferencesCatalog {
  static const List<PreferenceOption<String>> languages = [
    PreferenceOption(id: 'te', label: 'Telugu', emoji: '🎬'),
    PreferenceOption(id: 'hi', label: 'Hindi', emoji: '🇮🇳'),
    PreferenceOption(id: 'en', label: 'English', emoji: '🌐'),
    PreferenceOption(id: 'ta', label: 'Tamil', emoji: '🌟'),
    PreferenceOption(id: 'ml', label: 'Malayalam', emoji: '🌴'),
    PreferenceOption(id: 'kn', label: 'Kannada', emoji: '🌾'),
    PreferenceOption(id: 'ko', label: 'Korean', emoji: '🇰🇷'),
    PreferenceOption(id: 'ja', label: 'Japanese / Anime', emoji: '⛩️'),
    PreferenceOption(id: 'es', label: 'Spanish', emoji: '🇪🇸'),
    PreferenceOption(id: 'fr', label: 'French', emoji: '🇫🇷'),
  ];

  static const List<PreferenceOption<String>> genres = [
    PreferenceOption(id: 'Action', label: 'Action', emoji: '💥'),
    PreferenceOption(id: 'Sci-Fi', label: 'Sci-Fi', emoji: '🚀'),
    PreferenceOption(id: 'Thriller', label: 'Thriller', emoji: '⚡'),
    PreferenceOption(id: 'Drama', label: 'Drama', emoji: '🎭'),
    PreferenceOption(id: 'Comedy', label: 'Comedy', emoji: '😂'),
    PreferenceOption(id: 'Romance', label: 'Romance', emoji: '❤️'),
    PreferenceOption(id: 'Crime', label: 'Crime', emoji: '🕵️'),
    PreferenceOption(id: 'Horror', label: 'Horror', emoji: '👻'),
    PreferenceOption(id: 'Animation', label: 'Animation & Anime', emoji: '🎨'),
    PreferenceOption(id: 'Mystery', label: 'Mystery', emoji: '🔍'),
    PreferenceOption(id: 'Fantasy', label: 'Fantasy', emoji: '🧙'),
    PreferenceOption(id: 'Documentary', label: 'Documentary', emoji: '📽️'),
  ];

  static const Map<String, int> genreToId = {
    'Action': 28,
    'Sci-Fi': 878,
    'Thriller': 53,
    'Drama': 18,
    'Comedy': 35,
    'Romance': 10749,
    'Crime': 80,
    'Horror': 27,
    'Animation': 16,
    'Mystery': 9648,
    'Fantasy': 14,
    'Documentary': 99,
  };

  static const List<PreferenceOption<String>> streamingPlatforms = [
    PreferenceOption(id: 'Netflix', label: 'Netflix', emoji: '🔴'),
    PreferenceOption(id: 'Prime Video', label: 'Prime Video', emoji: '📦'),
    PreferenceOption(id: 'Disney+ Hotstar', label: 'Disney+ Hotstar', emoji: '⭐'),
    PreferenceOption(id: 'Apple TV+', label: 'Apple TV+', emoji: '🍎'),
    PreferenceOption(id: 'JioCinema', label: 'JioCinema', emoji: '📺'),
    PreferenceOption(id: 'Theatres', label: 'Theatres / Cinema', emoji: '🍿'),
    PreferenceOption(id: 'SonyLIV / ZEE5', label: 'SonyLIV / ZEE5', emoji: '📡'),
    PreferenceOption(id: 'Crunchyroll', label: 'Crunchyroll', emoji: '🍥'),
  ];
}
