class AppVersionInfo {
  final String platform;
  final String currentVersion;
  final String latestVersion;
  final String minimumVersion;
  final bool updateAvailable;
  final bool forceUpdate;
  final String releaseNotes;
  final String storeUrl;

  const AppVersionInfo({
    required this.platform,
    required this.currentVersion,
    required this.latestVersion,
    required this.minimumVersion,
    required this.updateAvailable,
    required this.forceUpdate,
    required this.releaseNotes,
    required this.storeUrl,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      platform: json['platform'] as String? ?? 'ios',
      currentVersion: json['currentVersion'] as String? ?? '1.0.0',
      latestVersion: json['latestVersion'] as String? ?? '1.0.0',
      minimumVersion: json['minimumVersion'] as String? ?? '1.0.0',
      updateAvailable: json['updateAvailable'] as bool? ?? false,
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      releaseNotes: json['releaseNotes'] as String? ?? '',
      storeUrl: json['storeUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'currentVersion': currentVersion,
      'latestVersion': latestVersion,
      'minimumVersion': minimumVersion,
      'updateAvailable': updateAvailable,
      'forceUpdate': forceUpdate,
      'releaseNotes': releaseNotes,
      'storeUrl': storeUrl,
    };
  }
}
