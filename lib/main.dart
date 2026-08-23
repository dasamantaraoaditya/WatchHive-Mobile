import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (optional with fallback defaults)
  try {
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (e) {
    debugPrint('Dotenv load skipped or unconfigured: $e');
  }

  // Initialize Firebase (safely catch if config not yet provided)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init skipped or unconfigured: $e');
  }

  runApp(
    const ProviderScope(
      child: WatchHiveApp(),
    ),
  );
}
