import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:watchhive_mobile/features/onboarding/models/user_preferences.dart';
import 'package:watchhive_mobile/features/onboarding/services/onboarding_service.dart';
import 'package:watchhive_mobile/shared/models/user.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/auth/auth_manager.dart';
import 'package:watchhive_mobile/core/services/offline_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });
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
      OnboardingService.resetTrackingForTesting();
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

    test('resolveUserWithPreferences preserves existing preferences or merges local cached preferences', () async {
      final userWithPrefs = User(
        id: 'user-456',
        username: 'movielover',
        createdAt: DateTime.now(),
        hasCompletedOnboarding: true,
        preferences: {'languages': ['en'], 'genres': ['Action']},
      );

      final resolved = await service.resolveUserWithPreferences(userWithPrefs);
      expect(resolved.preferences?['languages'], equals(['en']));
      expect(resolved.hasCompletedOnboarding, isTrue);
    });

    test('stores preferences in OfflineStorageService DB cache and retrieves them cleanly', () async {
      final offlineStorage = OfflineStorageService();
      final prefs = {
        'languages': ['te', 'hi'],
        'genres': ['Action', 'Thriller'],
        'genreIds': [28, 53],
        'streamingPlatforms': ['Netflix'],
      };

      await offlineStorage.saveUserPreferences('user-sql-999', prefs);
      final retrieved = await offlineStorage.getUserPreferences('user-sql-999');

      expect(retrieved, isNotNull);
      expect(retrieved!['languages'], equals(['te', 'hi']));
      expect(retrieved['genres'], equals(['Action', 'Thriller']));
      expect(retrieved['streamingPlatforms'], equals(['Netflix']));
    });

    test('User.hasSubstantivePreferences detects non-empty preferences correctly', () {
      final userEmpty = User(
        id: 'u1',
        username: 'test',
        createdAt: DateTime.now(),
        preferences: {},
      );
      expect(userEmpty.hasSubstantivePreferences, isFalse);

      final userListsEmpty = User(
        id: 'u2',
        username: 'test',
        createdAt: DateTime.now(),
        preferences: {'languages': [], 'genres': []},
      );
      expect(userListsEmpty.hasSubstantivePreferences, isFalse);

      final userValid = User(
        id: 'u3',
        username: 'test',
        createdAt: DateTime.now(),
        preferences: {
          'languages': ['te'],
          'genres': ['Sci-Fi'],
          'streamingPlatforms': ['Netflix'],
        },
      );
      expect(userValid.hasSubstantivePreferences, isTrue);
      expect(userValid.savedLanguages, equals(['te']));
      expect(userValid.savedGenres, equals(['Sci-Fi']));
      expect(userValid.savedStreamingPlatforms, equals(['Netflix']));
    });

    test('resolveUserWithPreferences restores local cache when server returns empty map or empty lists', () async {
      final offlineStorage = OfflineStorageService();
      final localPrefs = {
        'languages': ['te', 'en'],
        'genres': ['Sci-Fi', 'Thriller'],
        'genreIds': [878, 53],
        'streamingPlatforms': ['Prime Video'],
      };
      await offlineStorage.saveUserPreferences('user-cache-111', localPrefs);

      final serviceWithDb = OnboardingService(
        ApiClient(AuthManager()),
        null,
        offlineStorage,
      );

      // Server returns empty preferences {}
      final serverUser = User(
        id: 'user-cache-111',
        username: 'cinephile',
        createdAt: DateTime.now(),
        hasCompletedOnboarding: false,
        preferences: {},
      );

      final resolved = await serviceWithDb.resolveUserWithPreferences(serverUser);
      expect(resolved.hasSubstantivePreferences, isTrue);
      expect(resolved.savedLanguages, equals(['te', 'en']));
      expect(resolved.savedGenres, equals(['Sci-Fi', 'Thriller']));
      expect(resolved.hasCompletedOnboarding, isTrue);
    });

    test('shouldPromptUser returns false if user has substantive preferences', () async {
      final user = User(
        id: 'u-pref',
        username: 'cinephile',
        createdAt: DateTime.now(),
        hasCompletedOnboarding: false,
        preferences: {'languages': ['te']},
      );
      final shouldPrompt = await service.shouldPromptUser(user);
      expect(shouldPrompt, isFalse);
    });

    test('shouldPromptUser returns false if user hasCompletedOnboarding', () async {
      final user = User(
        id: 'u-completed',
        username: 'cinephile',
        createdAt: DateTime.now(),
        hasCompletedOnboarding: true,
      );
      final shouldPrompt = await service.shouldPromptUser(user);
      expect(shouldPrompt, isFalse);
    });

    test('shouldPromptUser returns false if already prompted in current app launch', () async {
      final user = User(
        id: 'u-prompted',
        username: 'cinephile',
        createdAt: DateTime.now(),
        hasCompletedOnboarding: false,
        preferences: null,
      );
      service.markPrompted('u-prompted');
      final shouldPrompt = await service.shouldPromptUser(user);
      expect(shouldPrompt, isFalse);
    });

    test('shouldPromptUser returns false if preferences exist in offline DB storage', () async {
      final offlineStorage = OfflineStorageService();
      await offlineStorage.saveUserPreferences('u-offline', {'genres': ['Sci-Fi']});

      final serviceWithDb = OnboardingService(
        ApiClient(AuthManager()),
        null,
        offlineStorage,
      );

      final user = User(
        id: 'u-offline',
        username: 'cinephile',
        createdAt: DateTime.now(),
        hasCompletedOnboarding: false,
        preferences: null,
      );

      final shouldPrompt = await serviceWithDb.shouldPromptUser(user);
      expect(shouldPrompt, isFalse);
    });

    test('shouldPromptUser returns true only when user has no preferences and has not completed onboarding', () async {
      final user = User(
        id: 'u-new',
        username: 'brand_new_user',
        createdAt: DateTime.now(),
        hasCompletedOnboarding: false,
        preferences: null,
      );

      final shouldPrompt = await service.shouldPromptUser(user);
      expect(shouldPrompt, isTrue);
    });
  });
}
