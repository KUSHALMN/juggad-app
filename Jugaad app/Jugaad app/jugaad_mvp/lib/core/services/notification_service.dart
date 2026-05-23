import 'dart:convert';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('[FCM] Handling a background message: ${message.messageId}');
  // Note: Firebase is already initialized by the time this runs if initialized in main()
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _isInitialized = false;
  
  GlobalKey<NavigatorState>? navigatorKey;

  Future<void> init(GlobalKey<NavigatorState> navKey) async {
    navigatorKey = navKey;
    if (_isInitialized) return;
    _isInitialized = true;
    
    // Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('[FCM] User granted permission: ${settings.authorizationStatus}');

    // Setup Local Notifications for foreground
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: darwinInit);
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          final data = jsonDecode(details.payload!);
          _handleNavigation(data);
        }
      },
    );

    // Setup Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Terminated state
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNavigation(initialMessage.data);
      });
    }

    // Foreground state
    _foregroundSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[FCM] Notification received foreground: type=${message.data['type']}, jobId=${message.data['job_id']}');
      
      final type = message.data['type'];
      
      // Some types might just show a toast instead of a full local notification
      if (type == 'worker_arrived') {
        _showToast("Your worker is almost here");
        return;
      }
      if (type == 'payment_received') {
        final amount = message.data['amount'] ?? '0';
        _showToast("₹$amount added to your earnings");
        return;
      }
      if (type == 'scheduled_confirmed') {
        final service = message.data['service'] ?? 'service';
        final time = message.data['time'] ?? '';
        _showToast("Your $service job is confirmed for $time");
        return;
      }

      // Otherwise show local notification
      _showLocalNotification(message);
    });

    // Background state (App in background, user taps notification)
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[FCM] Notification tapped from background: type=${message.data['type']}');
      _handleNavigation(message.data);
    });
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    _isInitialized = false;
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'jugaad_high_importance',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleNavigation(Map<String, dynamic> data) {
    if (navigatorKey?.currentContext == null) return;
    final context = navigatorKey!.currentContext!;
    
    final type = data['type'];
    final jobId = data['job_id'];

    print('[FCM] Navigating to type: $type, jobId: $jobId');

    switch (type) {
      case 'job_incoming':
      case 'job_manual_assign':
        if (jobId != null) context.go('/worker/incoming?job_id=$jobId');
        break;
      case 'job_assigned':
        if (jobId != null) context.go('/user/matching?job_id=$jobId');
        break;
      case 'worker_arrived':
        _showToast('Your worker is almost here');
        break;
      case 'job_completed':
        if (jobId != null) {
          final amount = data['payment_amount'] ?? data['amount'] ?? 350;
          context.go('/user/payment?job_id=$jobId&amount=$amount');
        }
        break;
      case 'payment_received':
        _showToast("Payment received: ${data['amount'] ?? data['payment_amount'] ?? ''}");
        context.go('/worker/home');
        break;
      case 'scheduled_confirmed':
        _showToast('Scheduled job confirmed');
        break;
    }
  }

  void _showToast(String message) {
    if (navigatorKey?.currentContext == null) return;
    ScaffoldMessenger.of(navigatorKey!.currentContext!).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
