import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkConnectivityState {
  final bool isOnline;
  final bool isChecking;
  final String connectionType;
  final DateTime? lastCheckedAt;

  const NetworkConnectivityState({
    this.isOnline = true,
    this.isChecking = false,
    this.connectionType = 'wifi',
    this.lastCheckedAt,
  });

  NetworkConnectivityState copyWith({
    bool? isOnline,
    bool? isChecking,
    String? connectionType,
    DateTime? lastCheckedAt,
  }) =>
      NetworkConnectivityState(
        isOnline: isOnline ?? this.isOnline,
        isChecking: isChecking ?? this.isChecking,
        connectionType: connectionType ?? this.connectionType,
        lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      );
}

final connectivityServiceProvider =
    StateNotifierProvider<ConnectivityNotifier, NetworkConnectivityState>((ref) {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends StateNotifier<NetworkConnectivityState> {
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  VoidCallback? onReconnected;

  ConnectivityNotifier([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity(),
        super(const NetworkConnectivityState()) {
    _init();
  }

  /// Whether device is currently reported as online.
  bool get isOnline => state.isOnline;

  void _init() {
    _check();
    try {
      _subscription = _connectivity.onConnectivityChanged.listen(_handleResults);
    } catch (e) {
      debugPrint('[ConnectivityNotifier] Could not subscribe to connectivity stream: $e');
    }
  }

  Future<void> _check() async {
    state = state.copyWith(isChecking: true);
    try {
      final results = await _connectivity.checkConnectivity();
      _handleResults(results);
    } catch (_) {
      state = state.copyWith(isChecking: false);
    }
  }

  void _handleResults(List<ConnectivityResult> results) {
    final wasOnline = state.isOnline;
    final isOnline = _isResultOnline(results);
    final type = _resolveType(results);

    state = state.copyWith(
      isOnline: isOnline,
      isChecking: false,
      connectionType: type,
      lastCheckedAt: DateTime.now(),
    );

    // If transitioned from offline to online, trigger reconnection callback
    if (!wasOnline && isOnline) {
      onReconnected?.call();
    }
  }

  bool _isResultOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    if (results.length == 1 && results.first == ConnectivityResult.none) {
      return false;
    }
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  String _resolveType(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) return 'WiFi';
    if (results.contains(ConnectivityResult.mobile)) return 'Cellular';
    if (results.contains(ConnectivityResult.ethernet)) return 'Ethernet';
    return 'None';
  }

  /// Manually force a re-check
  Future<bool> checkConnection() async {
    await _check();
    return state.isOnline;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
