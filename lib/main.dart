import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';
import 'services/push_notification_service.dart';
import 'screens/welcome_screen.dart';
import 'screens/main_navigation_screen.dart';

/// ============================================================================
/// CHATTªX
/// MAIN ENTRY POINT
/// ============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================================
  // FIREBASE
  // ==========================================================================

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    debugPrint(
      'CHATTªX FIREBASE: initialization failed: $error',
    );

    debugPrint(
      '$stackTrace',
    );

    rethrow;
  }

  // ==========================================================================
  // FIRESTORE OFFLINE CACHE
  // ==========================================================================

  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (error) {
    debugPrint(
      'CHATTªX FIRESTORE: settings error: $error',
    );
  }

  // ==========================================================================
  // HIVE
  // ==========================================================================

  try {
    await Hive.initFlutter();

    await Hive.openBox('chat_cache');
    await Hive.openBox('chat_message_cache');
    await Hive.openBox('users_cache');
  } catch (error, stackTrace) {
    debugPrint(
      'CHATTªX HIVE: initialization error: $error',
    );

    debugPrint(
      '$stackTrace',
    );
  }

  // ==========================================================================
  // PUSH NOTIFICATIONS
  // ==========================================================================

  try {
    await PushNotificationService().initialize();

    debugPrint(
      'CHATTªX PUSH: initialized successfully',
    );
  } catch (error, stackTrace) {
    debugPrint(
      'CHATTªX PUSH: initialization error: $error',
    );

    debugPrint(
      '$stackTrace',
    );

    // Push notifications failing should NOT prevent the app from opening.
  }

  // ==========================================================================
  // START APP
  // ==========================================================================

  runApp(
    const ChatExApp(),
  );
}

/// ============================================================================
/// CHATTªX APP
/// ============================================================================

class ChatExApp extends StatelessWidget {
  const ChatExApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'ChattªX',

      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor:
            const Color(0xFF050816),

        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7B2FF7),
          secondary: Color(0xFF00D9FF),
        ),

        useMaterial3: true,
      ),

      home: const AuthGate(),
    );
  }
}

/// ============================================================================
/// AUTH GATE
/// ============================================================================
///
/// This widget decides whether the user should see:
///
///     WelcomeScreen
///          OR
///     MainNavigationScreen
///
/// IMPORTANT:
///
/// The incoming call listener is NOT started here.
///
/// MainNavigationScreen is responsible for:
///
///     incomingCalls.listen(...)
///              ↓
///     listenForIncomingCalls()
///              ↓
///     IncomingVoiceCallScreen
///
/// This prevents duplicate call listeners.
/// ============================================================================

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),

      builder: (
        BuildContext context,
        AsyncSnapshot<User?> snapshot,
      ) {
        // ====================================================================
        // AUTHENTICATION STILL LOADING
        // ====================================================================

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor:
                Color(0xFF050816),

            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF7B2FF7),
              ),
            ),
          );
        }

        // ====================================================================
        // AUTH STREAM ERROR
        // ====================================================================

        if (snapshot.hasError) {
          debugPrint(
            'CHATTªX AUTH: authStateChanges error: '
            '${snapshot.error}',
          );

          return const Scaffold(
            backgroundColor:
                Color(0xFF050816),

            body: Center(
              child: Text(
                'Unable to load your account.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }

        // ====================================================================
        // USER LOGGED IN
        // ====================================================================

        final User? user = snapshot.data;

        if (user != null) {
          debugPrint(
            'CHATTªX AUTH: authenticated user '
            '${user.uid}',
          );

          return const MainNavigationScreen();
        }

        // ====================================================================
        // USER LOGGED OUT
        // ====================================================================

        debugPrint(
          'CHATTªX AUTH: no authenticated user',
        );

        return const WelcomeScreen();
      },
    );
  }
}