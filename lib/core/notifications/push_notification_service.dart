import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';

/// Top-level background message handler required by FirebaseMessaging.
/// Must be annotated with @pragma('vm:entry-point') to prevent tree-shaking in release builds.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('[PushNotificationService] Background Firebase init skipped: $e');
  }
  debugPrint('[PushNotificationService] Background message received: ${message.messageId} | data: ${message.data}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'watchhive_high_importance_channel',
    'WatchHive Activity & Buzz',
    description: 'Notifications for likes, comments, follows, and movie suggestions.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  String? _currentToken;
  bool _isInitialized = false;
  final _tokenController = StreamController<String>.broadcast();

  String? get currentToken => _currentToken;
  bool get isInitialized => _isInitialized;
  Stream<String> get onTokenRefresh => _tokenController.stream;

  /// Retrieves the current cached FCM token or actively fetches it from Firebase Messaging
  Future<String?> getOrFetchToken() async {
    if (_currentToken != null && _currentToken!.isNotEmpty) {
      return _currentToken;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _currentToken = await _fcm.getToken();
      if (_currentToken != null && _currentToken!.isNotEmpty) {
        _tokenController.add(_currentToken!);
      }
      return _currentToken;
    } catch (e) {
      debugPrint('[PushNotificationService] Error fetching FCM token: $e');
      return null;
    }
  }

  /// Initialize Firebase Messaging, Local Notifications, channels, and event listeners
  Future<void> initialize({Future<void> Function(String token)? onTokenRefresh}) async {
    if (_isInitialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Firebase not configured yet: $e');
      return;
    }

    try {
      // 1. Request notification permissions early (Android 13+ & iOS)
      await requestPermission();

      // 2. Initialize local notifications plugin for foreground banners
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            _handlePayloadNavigation(response.payload!);
          }
        },
      );

      // 3. Create the Android notification channel
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.createNotificationChannel(_channel);

      // 4. Foreground presentation options (iOS / Android heads-up)
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Foreground Message Listener -> Display as local notification banner
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[PushNotificationService] Foreground message received: ${message.messageId}');
        _showForegroundNotification(message);
      });

      // 6. Notification tapped when app is running in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[PushNotificationService] Notification opened from background: ${message.messageId}');
        _handleRemoteMessageNavigation(message);
      });

      // 7. Notification tapped when app was terminated
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[PushNotificationService] App launched from terminated state via notification: ${initialMessage.messageId}');
        _handleRemoteMessageNavigation(initialMessage);
      }

      // 8. Get device FCM Token and register refresh callback
      try {
        _currentToken = await _fcm.getToken();
        if (_currentToken != null && _currentToken!.isNotEmpty) {
          debugPrint('[PushNotificationService] FCM Device Token obtained: ${_currentToken!.substring(0, 10)}...');
          _tokenController.add(_currentToken!);
          if (onTokenRefresh != null) {
            await onTokenRefresh(_currentToken!);
          }
        }
      } catch (e) {
        debugPrint('[PushNotificationService] Could not retrieve FCM token: $e');
      }

      _fcm.onTokenRefresh.listen((String newToken) async {
        debugPrint('[PushNotificationService] FCM Device Token refreshed');
        _currentToken = newToken;
        _tokenController.add(newToken);
        if (onTokenRefresh != null) {
          await onTokenRefresh(newToken);
        }
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('[PushNotificationService] Error initializing push notification service: $e');
    }
  }

  /// Request user notification permission (runtime dialog on Android 13+ and iOS)
  Future<bool> requestPermission() async {
    bool isGranted = false;

    // 1. Try FCM requestPermission (standard for Firebase Messaging)
    try {
      if (Firebase.apps.isNotEmpty) {
        final settings = await _fcm.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        isGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Error requesting notification permission via FCM: $e');
    }

    // 2. Android 13+ fallback via flutter_local_notifications if not yet granted
    if (!isGranted) {
      try {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final androidGranted = await androidPlugin?.requestNotificationsPermission();
        if (androidGranted == true) {
          isGranted = true;
        }
      } catch (e) {
        debugPrint('[PushNotificationService] Error requesting notification permission via Android plugin: $e');
      }
    }

    return isGranted;
  }

  /// Check current notification permission status across FCM and native OS
  Future<bool> isPermissionGranted() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        final settings = await _fcm.getNotificationSettings();
        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          return true;
        }
      }
    } catch (_) {}

    // Check Android native permission status
    try {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await androidPlugin?.areNotificationsEnabled();
      if (enabled != null) return enabled;
    } catch (_) {}

    return false;
  }

  /// Display a heads-up local notification when a push arrives while app is in foreground
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'WatchHive';
    final body = notification?.body ?? message.data['body'] ?? 'You have a new update in the Hive';

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFFFB700),
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payloadString = jsonEncode(message.data);
    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      platformDetails,
      payload: payloadString,
    );
  }

  /// Show an immediate local test notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFFFB700),
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payloadString = data != null ? jsonEncode(data) : null;
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformDetails,
      payload: payloadString,
    );
  }

  /// Handle deep-linking navigation when user taps a notification
  void _handleRemoteMessageNavigation(RemoteMessage message) {
    if (message.data.isNotEmpty) {
      _navigateFromData(message.data);
    } else {
      rootNavigatorKey.currentContext?.go('/notifications');
    }
  }

  void _handlePayloadNavigation(String rawPayload) {
    try {
      final data = jsonDecode(rawPayload);
      if (data is Map<String, dynamic>) {
        _navigateFromData(data);
      } else {
        rootNavigatorKey.currentContext?.go('/notifications');
      }
    } catch (_) {
      rootNavigatorKey.currentContext?.go('/notifications');
    }
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final type = (data['type'] ?? '').toString().toUpperCase();
    final url = data['url']?.toString();

    // If explicit URL / route is passed
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('/watch-hive')) {
        final mobileRoute = url.replaceFirst('/watch-hive', '');
        context.go(mobileRoute.isEmpty ? '/feed' : mobileRoute);
        return;
      } else if (url.startsWith('/')) {
        context.go(url);
        return;
      }
    }

    switch (type) {
      case 'LIKE':
      case 'COMMENT':
      case 'REPLY':
        context.go('/feed');
        break;

      case 'SUGGESTION':
        final tmdbId = data['tmdbId'];
        final mediaType = data['mediaType'] ?? 'movie';
        if (tmdbId != null) {
          context.push('/details/$mediaType/$tmdbId');
        } else {
          context.go('/entries');
        }
        break;

      case 'FOLLOW':
      case 'FOLLOW_REQUEST':
      case 'FOLLOW_ACCEPT':
      case 'FOLLOW_REJECT':
        final actorId = data['actorId'];
        if (actorId != null && actorId.toString().isNotEmpty) {
          context.push('/profile/$actorId');
        } else {
          context.go('/notifications');
        }
        break;

      default:
        context.go('/notifications');
        break;
    }
  }
}
