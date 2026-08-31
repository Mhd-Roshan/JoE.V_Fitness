import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../screens/notification_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/booking_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background FCM messages automatically handled by system notification
}

class AppNotificationService {
  AppNotificationService._();
  static final AppNotificationService instance = AppNotificationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'jove_fitness_channel';
  static const String _channelName = 'JoE.V Fitness Notifications';
  static const String _channelDesc =
      'Real-time alerts, session updates, chat messages, and fitness goals';

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

  StreamSubscription<QuerySnapshot>? _firestoreNotificationsSub;
  StreamSubscription<User?>? _authSubscription;
  bool _isInitialLoad = true;
  final Set<String> _processedNotificationIds = <String>{};

  Future<void> initialize() async {
    // 1. Android & iOS Local Notifications Initialization
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    // Create Notification Channel for Android
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_androidChannel);
      // DO NOT await permission request here to prevent blocking main()
      androidPlugin.requestNotificationsPermission();
    }

    // 2. Firebase Cloud Messaging Setup
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      // DO NOT await this to prevent blocking main() before runApp
      messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      ).then((settings) {
        debugPrint(
          'User notification permission status: ${settings.authorizationStatus}',
        );
      });

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Handle Foreground FCM
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          showLocalNotification(
            id: message.hashCode,
            title: notification.title ?? 'JoE.V Fitness',
            body: notification.body ?? '',
            payload: message.data['type'] ?? 'system',
          );
          showInAppBanner(
            title: notification.title ?? 'JoE.V Fitness',
            body: notification.body ?? '',
            type: message.data['type'] ?? 'system',
          );
        }
      });

      // Handle App opened via notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _routeToScreen(message.data['type'] ?? 'system');
      });

      // Check if opened from terminated state
      RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _routeToScreen(initialMessage.data['type'] ?? 'system');
      }

      // 3. Listen to Auth State to update FCM Token and Firestore listener
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        User? user,
      ) {
        if (user != null) {
          _updateFCMToken(user.uid);
          _startFirestoreNotificationListener(user.uid);
        } else {
          _stopFirestoreNotificationListener();
        }
      });
    } catch (e) {
      debugPrint('Notification setup error: $e');
    }
  }

  Future<void> _updateFCMToken(String uid) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': newToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  void _startFirestoreNotificationListener(String uid) {
    _firestoreNotificationsSub?.cancel();
    _isInitialLoad = true;

    _firestoreNotificationsSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen(
          (snapshot) {
            if (_isInitialLoad) {
              for (var doc in snapshot.docs) {
                _processedNotificationIds.add(doc.id);
              }
              _isInitialLoad = false;
              return;
            }

            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final doc = change.doc;
                if (!_processedNotificationIds.contains(doc.id)) {
                  _processedNotificationIds.add(doc.id);
                  final data = doc.data() as Map<String, dynamic>;
                  final String title = data['title'] ?? 'JoE.V Fitness';
                  final String message = data['message'] ?? '';
                  final String type = data['type'] ?? 'system';

                  // Show real outside status bar notification
                  showLocalNotification(
                    id: doc.id.hashCode,
                    title: title,
                    body: message,
                    payload: type,
                  );

                  // Show in-app banner alert if user is inside the app
                  showInAppBanner(title: title, body: message, type: type);
                }
              }
            }
          },
          onError: (e) {
            debugPrint('Firestore notification listener error: $e');
          },
        );
  }

  void _stopFirestoreNotificationListener() {
    _firestoreNotificationsSub?.cancel();
    _firestoreNotificationsSub = null;
    _processedNotificationIds.clear();
  }

  // --- Real System Notification (Outside App / Status Bar / Lockscreen) ---
  Future<void> showLocalNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          playSound: true,
          enableVibration: true,
          ticker: 'ticker',
          icon: '@mipmap/ic_launcher',
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // --- In-App Dynamic Floating Banner ---
  void showInAppBanner({
    required String title,
    required String body,
    String type = 'system',
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    IconData iconData = Icons.notifications_active_rounded;
    Color iconColor = const Color(0xFF003AA3);
    Color borderColor = const Color(0xFF2563EB);

    if (type == 'booking' || type == 'session') {
      iconData = Icons.event_available_rounded;
      iconColor = const Color(0xFF16A34A);
      borderColor = const Color(0xFF22C55E);
    } else if (type == 'chat' || type == 'message') {
      iconData = Icons.chat_bubble_rounded;
      iconColor = const Color(0xFF0284C7);
      borderColor = const Color(0xFF38BDF8);
    } else if (type == 'goal' || type == 'fitness') {
      iconData = Icons.emoji_events_rounded;
      iconColor = const Color(0xFFEA580C);
      borderColor = const Color(0xFFFB923C);
    } else if (type == 'reschedule') {
      iconData = Icons.update_rounded;
      iconColor = const Color(0xFF9333EA);
      borderColor = const Color(0xFFA855F7);
    }

    HapticFeedback.mediumImpact();

    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).size.height - 180,
        ),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: iconColor.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFF5F5F5),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: const TextStyle(
                        color: Color(0xFFA8A8A8),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
                  _routeToScreen(type);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'View',
                    style: TextStyle(
                      color: Color(0xFF60A5FA),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Dispatch Notification Helper for App Events ---
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'system',
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            'title': title,
            'message': message,
            'type': type,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });

      // If sent to current logged-in user, immediately show system notification
      if (FirebaseAuth.instance.currentUser?.uid == userId) {
        await showLocalNotification(title: title, body: message, payload: type);
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  void _handleNotificationTap(NotificationResponse response) {
    _routeToScreen(response.payload ?? 'system');
  }

  void _routeToScreen(String type) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    if (type == 'chat' || type == 'message') {
      nav.push(MaterialPageRoute(builder: (_) => const ChatScreen()));
    } else if (type == 'booking' || type == 'reschedule') {
      nav.push(MaterialPageRoute(builder: (_) => const BookingScreen()));
    } else {
      nav.push(MaterialPageRoute(builder: (_) => const NotificationScreen()));
    }
  }

  void dispose() {
    _firestoreNotificationsSub?.cancel();
    _authSubscription?.cancel();
  }
}
