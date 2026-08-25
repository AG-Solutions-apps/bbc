// NotificationService.dart
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background message handler — MUST be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised in main(), so nothing extra needed here.
  print('📩 [FCM Background] Message received: ${message.messageId}');
}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'bbc_high_importance_channel',
    'BBC Notifications',
    description: 'This channel is used for Business Boosters Club notifications.',
    importance: Importance.high,
  );

  /// Call once at app startup (after Firebase.initializeApp).
  static Future<void> initialize() async {
    // 1. Request permission (iOS + Android 13+)
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Create the Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 3. Initialise flutter_local_notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(initSettings);

    // 4. Foreground message handler → show a local notification
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Fetch & save FCM token
    await _fetchAndSaveToken();

    // 6. Listen for token refreshes
    messaging.onTokenRefresh.listen((newToken) async {
      print('🔄 FCM Token refreshed: $newToken');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', newToken);
    });
  }

  /// Returns the saved FCM token from SharedPreferences.
  static Future<String> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token') ?? '';
  }

  // ─── Private helpers ────────────────────────────────────────────────────────

  static Future<void> _fetchAndSaveToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
        print('✅ FCM token saved to SharedPreferences');
      }
    } catch (e) {
      print('❌ Failed to fetch FCM token: $e');
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
