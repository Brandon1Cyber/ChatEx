import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// ============================================================================
/// CHATTªX — PUSH NOTIFICATION SERVICE
/// ============================================================================
///
/// Handles:
///   • Firebase Cloud Messaging permissions
///   • FCM token registration
///   • FCM token refresh
///   • Android notification channel
///   • Foreground local notifications
///
/// Compatible with:
///   flutter_local_notifications: ^19.4.0
///
/// ============================================================================

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance =
      PushNotificationService._();

  factory PushNotificationService() => instance;

  // ==========================================================================
  // FIREBASE
  // ==========================================================================

  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ==========================================================================
  // LOCAL NOTIFICATIONS
  // ==========================================================================

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSubscription;

  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  bool _initialized = false;

  // ==========================================================================
  // ANDROID NOTIFICATION CHANNEL
  // ==========================================================================

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'chattax_messages',
    'ChattªX Messages',
    description:
        'Notifications for messages, calls and activity in ChattªX.',
    importance: Importance.high,
  );

  // ==========================================================================
  // INITIALIZE
  // ==========================================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      debugPrint(
        'CHATTªX PUSH: starting notification service...',
      );

      // ======================================================================
      // LOCAL NOTIFICATION INITIALIZATION
      // ======================================================================

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: androidSettings,
      );

      await _localNotifications.initialize(
  initializationSettings,
  onDidReceiveNotificationResponse: _onNotificationResponse,
);

      debugPrint(
        'CHATTªX PUSH: local notifications initialized',
      );

      // ======================================================================
      // ANDROID NOTIFICATION CHANNEL
      // ======================================================================

      final AndroidFlutterLocalNotificationsPlugin?
          androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          _channel,
        );

        debugPrint(
          'CHATTªX PUSH: Android notification channel created',
        );

        // ====================================================================
        // ANDROID 13+ NOTIFICATION PERMISSION
        // ====================================================================

        await androidPlugin.requestNotificationsPermission();

        debugPrint(
          'CHATTªX PUSH: Android notification permission requested',
        );
      }

      // ======================================================================
      // FIREBASE MESSAGING PERMISSION
      // ======================================================================

      final NotificationSettings settings =
          await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
        'CHATTªX PUSH: FCM authorization status = '
        '${settings.authorizationStatus}',
      );

      // ======================================================================
      // FOREGROUND NOTIFICATION PRESENTATION
      // ======================================================================

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // ======================================================================
      // SAVE CURRENT FCM TOKEN
      // ======================================================================

      await _saveCurrentToken();

      // ======================================================================
      // TOKEN REFRESH
      // ======================================================================

      _tokenRefreshSubscription ??=
          _messaging.onTokenRefresh.listen(
        (String newToken) async {
          debugPrint(
            'CHATTªX PUSH: FCM token refreshed',
          );

          await _saveToken(newToken);
        },
      );

      // ======================================================================
      // FOREGROUND MESSAGES
      // ======================================================================

      _foregroundMessageSubscription ??=
          FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );

      // ======================================================================
      // FINISHED
      // ======================================================================

      _initialized = true;

      debugPrint(
        'CHATTªX PUSH: notification service initialized successfully',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'CHATTªX PUSH: initialization error: $error',
      );

      debugPrint(
        '$stackTrace',
      );
    }
  }

  // ==========================================================================
  // NOTIFICATION TAP
  // ==========================================================================

  void _onNotificationResponse(
    NotificationResponse response,
  ) {
    debugPrint(
      'CHATTªX PUSH: notification tapped',
    );

    debugPrint(
      'CHATTªX PUSH: payload = ${response.payload}',
    );

    // Navigation can be added here later.
    //
    // Example:
    // if (response.payload != null) {
    //   // Open the relevant chat / call / notification.
    // }
  }

  // ==========================================================================
  // SAVE CURRENT FCM TOKEN
  // ==========================================================================

  Future<void> _saveCurrentToken() async {
    try {
      final String? token =
          await _messaging.getToken();

      if (token == null || token.isEmpty) {
        debugPrint(
          'CHATTªX PUSH: FCM token unavailable',
        );

        return;
      }

      debugPrint(
        'CHATTªX PUSH: FCM token received',
      );

      await _saveToken(token);
    } catch (error, stackTrace) {
      debugPrint(
        'CHATTªX PUSH: token error: $error',
      );

      debugPrint(
        '$stackTrace',
      );
    }
  }

  // ==========================================================================
  // SAVE FCM TOKEN TO FIRESTORE
  // ==========================================================================

  Future<void> _saveToken(
    String token,
  ) async {
    final User? user =
        _auth.currentUser;

    if (user == null) {
      debugPrint(
        'CHATTªX PUSH: no authenticated user; '
        'token will not be saved yet',
      );

      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'fcmToken': token,
        },
        SetOptions(
          merge: true,
        ),
      );

      debugPrint(
        'CHATTªX PUSH: FCM token saved to users/${user.uid}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'CHATTªX PUSH: failed to save token: $error',
      );

      debugPrint(
        '$stackTrace',
      );
    }
  }

  // ==========================================================================
  // FOREGROUND FCM MESSAGE
  // ==========================================================================

  Future<void> _handleForegroundMessage(
    RemoteMessage message,
  ) async {
    debugPrint(
      'CHATTªX PUSH: foreground message received '
      'id=${message.messageId}',
    );

    // ========================================================================
    // GET NOTIFICATION PAYLOAD
    // ========================================================================

    final RemoteNotification? notification =
        message.notification;

    if (notification == null) {
      debugPrint(
        'CHATTªX PUSH: message has no notification payload',
      );

      return;
    }

    final String title =
        notification.title?.trim().isNotEmpty == true
            ? notification.title!.trim()
            : 'ChattªX';

    final String body =
        notification.body?.trim() ?? '';

    // ========================================================================
    // CREATE ANDROID NOTIFICATION DETAILS
    // ========================================================================

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'chattax_messages',
      'ChattªX Messages',
      channelDescription:
          'Notifications for messages, calls and activity in ChattªX.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(
      android: androidDetails,
    );

    // ========================================================================
    // SHOW LOCAL NOTIFICATION
    // ========================================================================
    //
    // IMPORTANT:
    // flutter_local_notifications 19.x uses positional arguments here.
    //
    // DO NOT change this to:
    //
    // show(
    //   id: ...,
    //   title: ...,
    //   body: ...,
    //   notificationDetails: ...,
    // );
    //
    // That named-argument API is from 20.x+.
    // ========================================================================

    try {
      final int notificationId =
          message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(
                2147483647,
              );

      await _localNotifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: message.data.isNotEmpty
            ? message.data.toString()
            : null,
      );

      debugPrint(
        'CHATTªX PUSH: foreground notification displayed',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'CHATTªX PUSH: failed to display notification: $error',
      );

      debugPrint(
        '$stackTrace',
      );
    }
  }

  // ==========================================================================
  // GET CURRENT TOKEN
  // ==========================================================================

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (error) {
      debugPrint(
        'CHATTªX PUSH: getToken error: $error',
      );

      return null;
    }
  }

  // ==========================================================================
  // DELETE TOKEN
  // ==========================================================================

  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();

      debugPrint(
        'CHATTªX PUSH: FCM token deleted',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'CHATTªX PUSH: failed to delete token: $error',
      );

      debugPrint(
        '$stackTrace',
      );
    }
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();

    _tokenRefreshSubscription = null;

    await _foregroundMessageSubscription?.cancel();

    _foregroundMessageSubscription = null;

    _initialized = false;

    debugPrint(
      'CHATTªX PUSH: notification service disposed',
    );
  }
}