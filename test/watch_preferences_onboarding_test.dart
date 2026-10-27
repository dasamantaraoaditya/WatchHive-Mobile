import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/onboarding/models/user_preferences.dart';
import 'package:watchhive_mobile/features/onboarding/services/onboarding_service.dart';
import 'package:watchhive_mobile/shared/models/user.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/auth/auth_manager.dart';

void main() {
  group('UserPreferences Model Tests', () {
    test('correctly serializes and deserializes preferences JSON', () {
      final json = {
        'languages': ['te', 'hi', 'en'],
        'genres': ['Action', 'Sci-Fi'],
        'genreIds': [28, 878],
        'streamingPlatforms': ['Netflix', 'Prime Video'],
      };

      final prefs = UserPreferences.fromJson(json);

      expect(prefs.languages, equals(['te', 'hi', 'en']));
      expect(prefs.genres, equals(['Action', 'Sci-Fi']));
      expect(prefs.genreIds, equals([28, 878]));
      expect(prefs.streamingPlatforms, equals(['Netflix', 'Prime Video']));
      expect(prefs.isNotEmpty, isTrue);

      final exported = prefs.toJson();
      expect(exported['languages'], equals(['te', 'hi', 'en']));
      expect(exported['genres'], equals(['Action', 'Sci-Fi']));
    });

    test('catalog contains Telugu, Hindi, English, and major genres', () {
      final langIds = WatchHivePreferencesCatalog.languages.map((l) => l.id).toList();
      expect(langIds, contains('te'));
      expect(langIds, contains('hi'));
      expect(langIds, contains('en'));

      final genreIds = WatchHivePreferencesCatalog.genres.map((g) => g.id).toList();
      expect(genreIds, contains('Action'));
      expect(genreIds, contains('Sci-Fi'));
      expect(genreIds, contains('Thriller'));

      final platformIds = WatchHivePreferencesCatalog.streamingPlatforms.map((p) => p.id).toList();
      expect(platformIds, contains('Netflix'));
      expect(platformIds, contains('Prime Video'));
    });
  });

  group('OnboardingService shouldShowPreferences', () {
    late OnboardingService service;

    setUp(() {
      final authManager = AuthManager();
      final apiClient = ApiClient(authManager);
      service = OnboardingService(apiClient);
    });

    test('returns true for user who has not completed onboarding and has no preferences', () {
      final user = User(
        id: 'user-123',
        username: 'cinephile',
        createdAt: DateTime.now(),
        hasCompletedOnboarding: false,
        preferences: null,
      );

      expect(service.shouldShowPreferences(user), isTrue);
    });

    test('returns false once user has completed onboarding with preferences', () {
      final user = User(
        id: 'user-123',
        username: 'cinephile',
        createdAt: DateTime.now(),
        hasCompletedOnboarding: true,
        preferences: {
          'languages': ['te', 'en'],
          'genres': ['Sci-Fi'],
        },
      );

      expect(service.shouldShowPreferences(user), isFalse);
    });
  });
}
