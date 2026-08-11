import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

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
