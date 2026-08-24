import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Request Notification Permissions
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('User notification permission status: ${settings.authorizationStatus}');
      }

      // 2. Fetch and save FCM Token
      await saveDeviceToken();

      // 3. Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        await _saveTokenToFirestore(newToken);
      });

      // 4. Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Received foreground notification: ${message.notification?.title}');
        }
      });

      // 5. Handle Background / Opened Notifications
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Notification opened app: ${message.data}');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService initialization error: $e');
      }
    }
  }

  /// Saves the current FCM token to Firestore under users and trainers docs
  Future<void> saveDeviceToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching device token: $e');
      }
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final data = {
      'fcmToken': token,
      'deviceToken': token,
      'lastActive': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'role': 'trainer',
    };

    try {
      // Write to user doc
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));

      // Write to trainer doc
      await FirebaseFirestore.instance
          .collection('trainers')
          .doc(uid)
          .set(data, SetOptions(merge: true));

      // Also subscribe to broad trainer topics
      try {
        await FirebaseMessaging.instance.subscribeToTopic('trainers');
        await FirebaseMessaging.instance.subscribeToTopic('all');
      } catch (_) {}
    } catch (e) {
      if (kDebugMode) {
        print('Error saving FCM token to Firestore: $e');
      }
    }
  }
}
