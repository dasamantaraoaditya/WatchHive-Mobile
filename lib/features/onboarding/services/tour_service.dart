import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tourServiceProvider = Provider<TourService>((ref) {
  return TourService();
});

/// Manages whether a user has seen/completed the WatchHive Quick Guide Tour.
class TourService {
  final FlutterSecureStorage _storage;

  TourService([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions:
                  IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  static String _keyForUser(String userId) {
    final cleanId = userId.trim();
    return cleanId.isNotEmpty
        ? 'wh_tour_completed_$cleanId'
        : 'wh_tour_completed_guest';
  }

  /// Checks if the tour should be displayed for the given user.
  /// Returns `true` if this user has never completed or dismissed the tour.
  Future<bool> shouldShowTour(String userId) async {
    if (userId.trim().isEmpty) return false;
    try {
      final value = await _storage.read(key: _keyForUser(userId));
      return value != 'true';
    } catch (_) {
      // In case of any storage read error, avoid blocking the user
      return false;
    }
  }

  /// Checks if the tour was completed for the given user.
  Future<bool> isTourCompleted(String userId) async {
    if (userId.trim().isEmpty) return true;
    try {
      final value = await _storage.read(key: _keyForUser(userId));
      return value == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Marks the quick guide tour as completed for this user.
  Future<void> markTourCompleted(String userId) async {
    try {
      await _storage.write(key: _keyForUser(userId), value: 'true');
    } catch (_) {}
  }

  /// Resets the tour status (used for re-onboarding, testing, or reset).
  Future<void> resetTour(String userId) async {
    try {
      await _storage.delete(key: _keyForUser(userId));
    } catch (_) {}
  }
}
