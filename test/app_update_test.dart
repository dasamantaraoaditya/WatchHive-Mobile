import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/models/app_version_info.dart';
import 'package:watchhive_mobile/core/services/app_update_service.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/auth/auth_manager.dart';

void main() {
  group('AppUpdateService Semver Comparison', () {
    late AppUpdateService service;

    setUp(() {
      final authManager = AuthManager();
      final apiClient = ApiClient(authManager);
      service = AppUpdateService(apiClient);
    });

    test('returns 0 for equal versions', () {
      expect(service.compareSemver('1.0.44', '1.0.44'), equals(0));
      expect(service.compareSemver('v1.0.44', '1.0.44'), equals(0));
      expect(service.compareSemver('1.0.0', '1.0.0'), equals(0));
    });

    test('returns > 0 when v1 is newer than v2', () {
      expect(service.compareSemver('1.0.45', '1.0.44'), greaterThan(0));
      expect(service.compareSemver('1.1.0', '1.0.44'), greaterThan(0));
      expect(service.compareSemver('2.0.0', '1.99.99'), greaterThan(0));
    });

    test('returns < 0 when v1 is older than v2', () {
      expect(service.compareSemver('1.0.44', '1.0.45'), lessThan(0));
      expect(service.compareSemver('1.0.0', '1.1.0'), lessThan(0));
      expect(service.compareSemver('0.9.9', '1.0.0'), lessThan(0));
    });
  });

  group('AppVersionInfo JSON parsing', () {
    test('correctly parses backend payload', () {
      final json = {
        'platform': 'ios',
        'currentVersion': '1.0.44',
        'latestVersion': '1.0.45',
        'minimumVersion': '1.0.0',
        'updateAvailable': true,
        'forceUpdate': false,
        'releaseNotes': 'New badges and streak features',
        'storeUrl': 'https://apps.apple.com/app/watchershive/id6740000000',
      };

      final info = AppVersionInfo.fromJson(json);

      expect(info.platform, equals('ios'));
      expect(info.currentVersion, equals('1.0.44'));
      expect(info.latestVersion, equals('1.0.45'));
      expect(info.minimumVersion, equals('1.0.0'));
      expect(info.updateAvailable, isTrue);
      expect(info.forceUpdate, isFalse);
      expect(info.releaseNotes, contains('New badges'));
      expect(info.storeUrl, contains('apps.apple.com'));
    });
  });
}
