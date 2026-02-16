import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gov_agent/app.dart';

/// Whether Firebase was successfully initialized.
bool firebaseInitialized = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    firebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    debugPrint('Running in UI-only mode. Gemini features will not work.');
  }

  runApp(
    const ProviderScope(
      child: GovAgentApp(),
    ),
  );
}
