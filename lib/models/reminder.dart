import 'package:flutter/material.dart';

class Reminder {
  Reminder({
    this.id,
    required this.title,
    required this.time,
    this.repeating = true,
    this.completed = false,
  });

  int? id;
  final String title;
  final TimeOfDay time;
  bool repeating;
  bool completed;

  String get formattedTime => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String get repeatLabel => repeating ? '每天重复' : '单次提醒';

  int get minutesOfDay => time.hour * 60 + time.minute;

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final timeStr = (json['time'] ?? '00:00') as String;
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return Reminder(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      time: TimeOfDay(hour: hour, minute: minute),
      repeating: (json['repeating'] ?? 1) == 1,
      completed: (json['completed'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'time': formattedTime,
        'repeating': repeating ? 1 : 0,
        'completed': completed ? 1 : 0,
      };
}
