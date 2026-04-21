import 'dart:typed_data';

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
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

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

    await _requestPermissions();
    await _createNotificationChannels();

    _initialized = true;
    debugPrint('通知服务初始化完成，时区: Asia/Shanghai');
  }

  Future<void> _createNotificationChannels() async {
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'reminder_alerts',
          '用药提醒',
          description: '老人用药提醒通知',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'sos_alerts',
          'SOS告警',
          description: '老人SOS紧急求助通知',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      
      debugPrint('通知渠道创建完成');
    }
  }

  Future<void> _requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
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
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
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
    required String reminderTitle,
    String? note,
    int reminderId = 0,
  }) async {
    if (kIsWeb) {
      debugPrint('Reminder Alert: $reminderTitle');
      return;
    }

    final notificationId = reminderId > 0 ? reminderId : DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    await _notifications.show(
      notificationId,
      '⏰ 用药提醒',
      '$reminderTitle${note != null && note.isNotEmpty ? ' - $note' : ''}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_alerts',
          '用药提醒',
          channelDescription: '老人用药提醒通知',
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 300, 100, 300]),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: 'reminder_alert:$reminderId',
    );
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required int hour,
    required int minute,
    String repeatType = 'daily',
    List<int> weekdays = const [],
  }) async {
    if (kIsWeb) return;

    await _cancelReminder(id);

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    final androidDetails = AndroidNotificationDetails(
      'reminder_alerts',
      '用药提醒',
      channelDescription: '老人用药提醒通知',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 100, 300]),
    );

    final iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    if (repeatType == 'daily') {
      await _notifications.zonedSchedule(
        id,
        '⏰ 用药提醒',
        title,
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'reminder_alert:$id',
      );
      debugPrint('已设置每日提醒: $title at $hour:$minute (ID: $id)');
    } else if (repeatType == 'weekly' && weekdays.isNotEmpty) {
      for (final weekday in weekdays) {
        final weekdayId = id * 10 + weekday;
        var weekDate = scheduledDate;
        
        while (weekDate.weekday != weekday) {
          weekDate = weekDate.add(const Duration(days: 1));
        }
        
        final tzWeekDate = tz.TZDateTime.from(weekDate, tz.local);
        
        await _notifications.zonedSchedule(
          weekdayId,
          '⏰ 用药提醒',
          title,
          tzWeekDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'reminder_alert:$id',
        );
        debugPrint('已设置每周${weekday}提醒: $title at $hour:$minute (ID: $weekdayId)');
      }
    } else {
      await _notifications.zonedSchedule(
        id,
        '⏰ 用药提醒',
        title,
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'reminder_alert:$id',
      );
      debugPrint('已设置单次提醒: $title at $hour:$minute (ID: $id)');
    }
  }

  Future<void> _cancelReminder(int id) async {
    await _notifications.cancel(id);
    
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _notifications.cancel(id * 10 + weekday);
    }
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
    debugPrint('已取消所有提醒');
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
