import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../models/reminder.dart';

class ReminderScheduler {
  static final ReminderScheduler _instance = ReminderScheduler._internal();
  factory ReminderScheduler() => _instance;
  ReminderScheduler._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

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

    await _notifications.initialize(initSettings);
    _initialized = true;
  }

  Future<void> scheduleReminder(Reminder reminder) async {
    if (!_initialized) await initialize();

    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.time.hour,
      reminder.time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    switch (reminder.repeatType) {
      case RepeatType.once:
        await _scheduleOnce(reminder, scheduledDate);
        break;
      case RepeatType.daily:
        await _scheduleDaily(reminder, scheduledDate);
        break;
      case RepeatType.weekly:
        await _scheduleWeekly(reminder);
        break;
    }
  }

  Future<void> _scheduleOnce(Reminder reminder, DateTime scheduledDate) async {
    await _notifications.zonedSchedule(
      reminder.id ?? reminder.hashCode,
      '用药提醒',
      reminder.title,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          '用药提醒',
          channelDescription: '用药提醒通知',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: const RawResourceAndroidNotificationSound('reminder'),
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'reminder.mp3',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _scheduleDaily(Reminder reminder, DateTime scheduledDate) async {
    await _notifications.zonedSchedule(
      reminder.id ?? reminder.hashCode,
      '用药提醒',
      reminder.title,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          '用药提醒',
          channelDescription: '用药提醒通知',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: const RawResourceAndroidNotificationSound('reminder'),
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'reminder.mp3',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleWeekly(Reminder reminder) async {
    for (final weekday in reminder.weekdays) {
      var scheduledDate = _nextWeekday(weekday, reminder.time);
      
      await _notifications.zonedSchedule(
        (reminder.id ?? reminder.hashCode) * 10 + weekday,
        '用药提醒',
        reminder.title,
        tz.TZDateTime.from(scheduledDate, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_channel',
            '用药提醒',
            channelDescription: '用药提醒通知',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            sound: const RawResourceAndroidNotificationSound('reminder'),
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'reminder.mp3',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  DateTime _nextWeekday(int weekday, TimeOfDay time) {
    final now = DateTime.now();
    var date = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    
    while (date.weekday != weekday || date.isBefore(now)) {
      date = date.add(const Duration(days: 1));
    }
    
    return date;
  }

  Future<void> cancelReminder(Reminder reminder) async {
    await _notifications.cancel(reminder.id ?? reminder.hashCode);
    
    if (reminder.repeatType == RepeatType.weekly) {
      for (final weekday in reminder.weekdays) {
        await _notifications.cancel((reminder.id ?? reminder.hashCode) * 10 + weekday);
      }
    }
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  Future<void> showImmediateReminder(Reminder reminder) async {
    if (!_initialized) await initialize();

    await _notifications.show(
      reminder.id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '用药提醒',
      '${reminder.title} - ${reminder.formattedTime}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          '用药提醒',
          channelDescription: '用药提醒通知',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: const RawResourceAndroidNotificationSound('reminder'),
          enableVibration: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'reminder.mp3',
          interruptionLevel: InterruptionLevel.critical,
        ),
      ),
    );
  }
}

class ReminderAlertService {
  static final ReminderAlertService _instance = ReminderAlertService._internal();
  factory ReminderAlertService() => _instance;
  ReminderAlertService._internal();

  Timer? _checkTimer;
  final List<Reminder> _reminders = [];
  final Set<int> _triggeredToday = {};

  void startMonitoring(List<Reminder> reminders) {
    _reminders.clear();
    _reminders.addAll(reminders);
    _triggeredToday.clear();

    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkReminders());
  }

  void updateReminders(List<Reminder> reminders) {
    _reminders.clear();
    _reminders.addAll(reminders);
  }

  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  void _checkReminders() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (_triggeredToday.isNotEmpty) {
      final lastReset = _triggeredToday.first;
      if (lastReset != today.day) {
        _triggeredToday.clear();
      }
    }

    for (final reminder in _reminders) {
      if (reminder.completed) continue;
      if (_triggeredToday.contains(reminder.id)) continue;

      final reminderTime = TimeOfDay(hour: now.hour, minute: now.minute);
      if (reminder.time.hour == reminderTime.hour &&
          reminder.time.minute == reminderTime.minute) {
        
        bool shouldTrigger = false;
        switch (reminder.repeatType) {
          case RepeatType.once:
          case RepeatType.daily:
            shouldTrigger = true;
            break;
          case RepeatType.weekly:
            final weekday = now.weekday;
            shouldTrigger = reminder.weekdays.contains(weekday);
            break;
        }

        if (shouldTrigger) {
          _triggeredToday.add(reminder.id ?? reminder.hashCode);
          ReminderScheduler().showImmediateReminder(reminder);
        }
      }
    }
  }

  void markCompleted(Reminder reminder) {
    reminder.completed = true;
    _triggeredToday.add(reminder.id ?? reminder.hashCode);
  }

  void resetDaily() {
    _triggeredToday.clear();
    for (final reminder in _reminders) {
      if (reminder.repeatType != RepeatType.once) {
        reminder.completed = false;
      }
    }
  }
}
