import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // 로컬 알림 초기화
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);

    // FCM 권한 요청
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // FCM 토큰 가져오기
    String? token = await _messaging.getToken();
    print('FCM Token: $token');

    // 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(
        message.notification?.title ?? '나만의 냉장고',
        message.notification?.body ?? '',
      );
    });
  }

  static Future<void> showExpiryNotification(
      String name, int dDay) async {
    String title = dDay == 0 ? '⚠️ 오늘 소비기한!' : '⚠️ 소비기한 임박!';
    String body = dDay == 0
        ? '$name 오늘까지예요! 빨리 드세요 🏃'
        : '$name 소비기한이 $dDay일 남았어요!';

    await _showLocalNotification(title, body);
  }

  static Future<void> _showLocalNotification(
      String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'expiry_channel',
      '소비기한 알림',
      channelDescription: '식재료 소비기한 임박 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp();
}