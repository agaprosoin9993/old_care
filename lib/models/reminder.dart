import 'package:flutter/material.dart';

enum RepeatType { once, daily, weekly }

class Reminder {
  Reminder({
    this.id,
    required this.title,
    required this.time,
    this.repeatType = RepeatType.daily,
    this.weekdays = const [],
    this.completed = false,
    this.enabled = true,
  });

  int? id;
  final String title;
  final TimeOfDay time;
  final RepeatType repeatType;
  final List<int> weekdays;
  bool completed;
  bool enabled;

  String get formattedTime =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String get repeatLabel {
    switch (repeatType) {
      case RepeatType.once:
        return '单次提醒';
      case RepeatType.daily:
        return '每天重复';
      case RepeatType.weekly:
        if (weekdays.isEmpty) return '每周重复';
        const weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
        final names = weekdays.map((d) => weekdayNames[d - 1]).join('、');
        return '每周$names';
    }
  }

  int get minutesOfDay => time.hour * 60 + time.minute;

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final timeStr = (json['time'] ?? '00:00') as String;
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    RepeatType repeatType = RepeatType.daily;
    final repeating = json['repeating'];
    if (repeating is int) {
      if (repeating == 0) {
        repeatType = RepeatType.once;
      } else if (repeating == 1) {
        repeatType = RepeatType.daily;
      } else if (repeating == 2) {
        repeatType = RepeatType.weekly;
      }
    }

    List<int> weekdays = [];
    if (json['weekdays'] != null) {
      final weekdaysStr = json['weekdays'].toString();
      weekdays = weekdaysStr.split(',').map(int.tryParse).whereType<int>().toList();
    }

    return Reminder(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      time: TimeOfDay(hour: hour, minute: minute),
      repeatType: repeatType,
      weekdays: weekdays,
      completed: (json['completed'] ?? 0) == 1 || json['completed'] == true,
      enabled: json['enabled'] == null ? true : (json['enabled'] == 1 || json['enabled'] == true),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'time': formattedTime,
        'repeating': repeatType == RepeatType.once
            ? 0
            : repeatType == RepeatType.daily
                ? 1
                : 2,
        'weekdays': weekdays.join(','),
        'completed': completed ? 1 : 0,
        'enabled': enabled ? 1 : 0,
      };

  Reminder copyWith({
    int? id,
    String? title,
    TimeOfDay? time,
    RepeatType? repeatType,
    List<int>? weekdays,
    bool? completed,
    bool? enabled,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      repeatType: repeatType ?? this.repeatType,
      weekdays: weekdays ?? this.weekdays,
      completed: completed ?? this.completed,
      enabled: enabled ?? this.enabled,
    );
  }
}
