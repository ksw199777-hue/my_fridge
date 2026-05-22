import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // FCM 토큰 가져와서 서버에 저장
    String? token = await _messaging.getToken();
    if (token != null) {
      await ApiService.updateFcmToken(token);
    }

    // 토큰 갱신시 서버에 업데이트
    _messaging.onTokenRefresh.listen((newToken) {
      ApiService.updateFcmToken(newToken);
    });

    // 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(
        message.notification?.title ?? '나만의 냉장고',
        message.notification?.body ?? '',
      );
    });
  }

  static Future<void> _showLocalNotification(String title, String body) async {
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
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}