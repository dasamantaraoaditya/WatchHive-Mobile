import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/notifications/push_notification_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (optional with fallback defaults)
  try {
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (e) {
    debugPrint('Dotenv load skipped or unconfigured: $e');
  }

  // Initialize Firebase & Push Notifications (safely catch if config not yet provided)
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushNotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Firebase init skipped or unconfigured: $e');
  }

  runApp(
    const ProviderScope(
      child: WatchHiveApp(),
    ),
  );
}
