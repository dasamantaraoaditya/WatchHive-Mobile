import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../models/app_version_info.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return AppUpdateService(apiClient);
});

class AppUpdateService {
  final ApiClient _apiClient;
  bool _hasPromptedThisSession = false;

  AppUpdateService(this._apiClient);

  bool get hasPromptedThisSession => _hasPromptedThisSession;

  void markPrompted() {
    _hasPromptedThisSession = true;
  }

  /// Compares two semver strings: returns >0 if v1 > v2, <0 if v1 < v2, 0 if equal.
  int compareSemver(String v1, String v2) {
    final clean1 = v1.replaceFirst(RegExp(r'^[vV]'), '').split('-').first;
    final clean2 = v2.replaceFirst(RegExp(r'^[vV]'), '').split('-').first;

    final parts1 = clean1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = clean2.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;

    for (var i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  /// Fetches version info from backend and compares against current installed package.
  Future<AppVersionInfo?> checkUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;

      String platform = 'ios';
      if (!kIsWeb && Platform.isAndroid) {
        platform = 'android';
      }

      final response = await _apiClient.get(
        ApiEndpoints.appVersion,
        queryParameters: {
          'platform': platform,
          'currentVersion': currentVersion,
          'buildNumber': buildNumber,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final info = AppVersionInfo.fromJson(data);

        // Double check client-side semver comparison for accuracy
        final isOutdated = compareSemver(info.latestVersion, currentVersion) > 0;
        final isForceRequired = compareSemver(currentVersion, info.minimumVersion) < 0;

        return AppVersionInfo(
          platform: info.platform,
          currentVersion: currentVersion,
          latestVersion: info.latestVersion,
          minimumVersion: info.minimumVersion,
          updateAvailable: isOutdated || info.updateAvailable,
          forceUpdate: isForceRequired || info.forceUpdate,
          releaseNotes: info.releaseNotes,
          storeUrl: info.storeUrl,
        );
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking app version: $e');
    }
    return null;
  }

  /// Opens the store URL (App Store on iOS or Google Play on Android).
  Future<bool> openStore(String storeUrl) async {
    if (kIsWeb) {
      if (storeUrl.isNotEmpty) {
        final uri = Uri.parse(storeUrl);
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    }

    if (Platform.isAndroid) {
      // First attempt native market:// intent
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final packageName = packageInfo.packageName.isNotEmpty
            ? packageInfo.packageName
            : 'com.watchhive.watchhive_mobile';
        final marketUri = Uri.parse('market://details?id=$packageName');
        if (await canLaunchUrl(marketUri)) {
          final launched = await launchUrl(marketUri, mode: LaunchMode.externalApplication);
          if (launched) return true;
        }
      } catch (_) {}

      // Fallback to https storeUrl or default play store link
      final fallbackUrl = storeUrl.isNotEmpty
          ? storeUrl
          : 'https://play.google.com/store/apps/details?id=com.watchhive.watchhive_mobile';
      final uri = Uri.parse(fallbackUrl);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (Platform.isIOS) {
      // If storeUrl points to apps.apple.com, try itms-apps:// for instant native store opening
      if (storeUrl.contains('apps.apple.com')) {
        try {
          final itmsUrl = storeUrl.replaceFirst('https://', 'itms-apps://');
          final itmsUri = Uri.parse(itmsUrl);
          if (await canLaunchUrl(itmsUri)) {
            final launched = await launchUrl(itmsUri, mode: LaunchMode.externalApplication);
            if (launched) return true;
          }
        } catch (_) {}
      }

      final fallbackUrl = storeUrl.isNotEmpty
          ? storeUrl
          : 'https://apps.apple.com/app/watchershive/id6740000000';
      final uri = Uri.parse(fallbackUrl);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (storeUrl.isNotEmpty) {
      final uri = Uri.parse(storeUrl);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
