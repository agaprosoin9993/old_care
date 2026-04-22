import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/reminder.dart';
import 'notification_service.dart';
import 'api_client.dart';
import 'local_cache_service.dart';

class ReminderSchedulerService extends ChangeNotifier {
  static ReminderSchedulerService? _instance;

  factory ReminderSchedulerService() {
    _instance ??= ReminderSchedulerService._internal();
    return _instance!;
  }

  ReminderSchedulerService._internal();

  final NotificationService _notificationService = NotificationService();
  final List<Reminder> _reminders = [];
  final Set<String> _triggeredToday = {};
  Timer? _checkTimer;
  ApiClient? _api;
  LocalCacheService? _cache;
  bool _notificationInitialized = false;

  List<Reminder> get reminders => List.unmodifiable(_reminders);

  void initialize(ApiClient api, LocalCacheService? cache) {
    _api = api;
    _cache = cache;
    _ensureNotificationInitialized();
    _startPeriodicCheck();
    debugPrint('提醒调度服务初始化完成');
  }

  Future<void> _ensureNotificationInitialized() async {
    if (!_notificationInitialized) {
      await _notificationService.initialize();
      _notificationInitialized = true;
      debugPrint('通知服务在调度器中初始化完成');
    }
  }

  void _startPeriodicCheck() {
    _checkTimer?.cancel();
    
    _checkReminders();
    
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkReminders();
    });
    debugPrint('定时检查已启动，每30秒检查一次');
  }

  Future<void> loadReminders(List<Reminder> reminders) async {
    _reminders.clear();
    _reminders.addAll(reminders.where((r) => r.enabled));
    
    debugPrint('加载了 ${_reminders.length} 个启用的提醒');
    for (final r in _reminders) {
      debugPrint('  提醒: ${r.title} at ${r.time.hour}:${r.time.minute}, ID: ${r.id}');
    }
    
    await _ensureNotificationInitialized();
    await _scheduleAllReminders();
    
    notifyListeners();
  }

  Future<void> addReminder(Reminder reminder) async {
    if (reminder.enabled) {
      _reminders.add(reminder);
      await _scheduleReminder(reminder);
      notifyListeners();
    }
  }

  Future<void> removeReminder(Reminder reminder) async {
    _reminders.removeWhere((r) => r.id == reminder.id);
    if (reminder.id != null) {
      await _notificationService.cancelAllReminders();
      await _scheduleAllReminders();
    }
    notifyListeners();
  }

  Future<void> updateReminder(Reminder reminder) async {
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index >= 0) {
      _reminders[index] = reminder;
      await _notificationService.cancelAllReminders();
      await _scheduleAllReminders();
      notifyListeners();
    }
  }

  Future<void> _scheduleAllReminders() async {
    for (final reminder in _reminders) {
      await _scheduleReminder(reminder);
    }
    debugPrint('已安排 ${_reminders.length} 个提醒');
  }

  Future<void> _scheduleReminder(Reminder reminder) async {
    if (reminder.id == null) return;

    String repeatType;
    switch (reminder.repeatType) {
      case RepeatType.once:
        repeatType = 'once';
        break;
      case RepeatType.daily:
        repeatType = 'daily';
        break;
      case RepeatType.weekly:
        repeatType = 'weekly';
        break;
    }

    await _notificationService.scheduleReminder(
      id: reminder.id!,
      title: reminder.title,
      hour: reminder.time.hour,
      minute: reminder.time.minute,
      repeatType: repeatType,
      weekdays: reminder.weekdays,
    );
  }

  void _checkReminders() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final today = '${now.year}-${now.month}-${now.day}';

    debugPrint('检查提醒: 当前时间 ${now.hour}:${now.minute} ($currentMinutes 分钟), 已加载 ${_reminders.length} 个提醒');

    if (_triggeredToday.isNotEmpty) {
      final lastTriggerDate = _triggeredToday.first.split('_').first;
      if (lastTriggerDate != today) {
        _triggeredToday.clear();
        debugPrint('新的一天，清除已触发记录');
      }
    }

    for (final reminder in _reminders) {
      final reminderMinutes = reminder.minutesOfDay;
      final triggerKey = '${today}_${reminder.id}';
      
      debugPrint('  检查提醒: ${reminder.title} - 设置时间 ${reminder.time.hour}:${reminder.time.minute} ($reminderMinutes 分钟)');
      
      if (reminderMinutes == currentMinutes && !_triggeredToday.contains(triggerKey)) {
        debugPrint('>>> 时间匹配! 触发提醒: ${reminder.title}');
        _triggeredToday.add(triggerKey);
        _triggerReminder(reminder);
      }
    }
  }

  void _triggerReminder(Reminder reminder) async {
    debugPrint('触发提醒: ${reminder.title}');
    
    await _ensureNotificationInitialized();
    
    await _notificationService.showReminderAlert(
      reminderTitle: reminder.title,
      reminderId: reminder.id ?? 0,
    );
    
    debugPrint('提醒通知已发送: ${reminder.title}');
  }

  void debugPrintStatus() {
    final now = DateTime.now();
    debugPrint('=== 提醒调度状态 ===');
    debugPrint('当前时间: ${now.hour}:${now.minute}');
    debugPrint('已加载提醒数: ${_reminders.length}');
    for (final r in _reminders) {
      debugPrint('  - ${r.title}: ${r.time.hour}:${r.time.minute} (ID: ${r.id})');
    }
    debugPrint('今日已触发: $_triggeredToday');
    debugPrint('==================');
  }

  Future<void> refreshFromServer() async {
    if (_api == null) return;

    try {
      final reminders = await _api!.fetchReminders();
      await loadReminders(reminders);
    } catch (e) {
      debugPrint('从服务器刷新提醒失败: $e');
      
      if (_cache != null) {
        final cachedReminders = _cache!.getReminders();
        if (cachedReminders != null) {
          final reminders = cachedReminders.map((e) => Reminder.fromJson(e)).toList();
          await loadReminders(reminders);
        }
      }
    }
  }

  Future<void> testReminder(Reminder reminder) async {
    await _notificationService.showReminderAlert(
      reminderTitle: reminder.title,
      reminderId: reminder.id ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}
