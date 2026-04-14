import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  Future<void> showSosAlert({
    required String elderName,
    String? location,
  }) async {
    if (kIsWeb) {
      debugPrint('SOS Alert: $elderName at $location');
      return;
    }

    await _notifications.show(
      1,
      '🚨 SOS紧急求助',
      '$elderName 触发了SOS求救！${location != null ? '位置: $location' : ''}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'sos_alerts',
          'SOS告警',
          channelDescription: '老人SOS紧急求助通知',
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.critical,
        ),
      ),
      payload: 'sos_alert',
    );
  }

  Future<void> showReminderAlert({
    required String elderName,
    required String reminderTitle,
  }) async {
    if (kIsWeb) {
      debugPrint('Reminder Alert: $elderName - $reminderTitle');
      return;
    }

    await _notifications.show(
      2,
      '⏰ 用药提醒',
      '$elderName 的提醒: $reminderTitle',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_alerts',
          '用药提醒',
          channelDescription: '老人用药提醒通知',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'reminder_alert',
    );
  }

  Future<void> showLocationUpdate({
    required String elderName,
    required String location,
  }) async {
    if (kIsWeb) return;

    await _notifications.show(
      3,
      '📍 位置更新',
      '$elderName 的位置已更新: $location',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'location_updates',
          '位置更新',
          channelDescription: '老人位置更新通知',
          importance: Importance.low,
          priority: Priority.low,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      payload: 'location_update',
    );
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }
}
