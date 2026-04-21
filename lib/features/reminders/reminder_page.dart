import 'package:flutter/material.dart';
import '../../models/reminder.dart';
import '../../services/notification_service.dart';
import '../../services/reminder_scheduler_service.dart';

class ReminderPage extends StatelessWidget {
  const ReminderPage({
    super.key,
    required this.reminders,
    required this.onToggle,
    required this.onAdd,
    required this.onDelete,
    this.onEdit,
  });

  final List<Reminder> reminders;
  final ValueChanged<Reminder> onToggle;
  final ValueChanged<Reminder> onAdd;
  final ValueChanged<Reminder> onDelete;
  final ValueChanged<Reminder>? onEdit;

  @override
  Widget build(BuildContext context) {
    final sorted = [...reminders]..sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
    final activeCount = sorted.where((r) => !r.completed).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '用药提醒',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openAddDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('添加提醒'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: const Icon(Icons.event_available, color: Colors.green),
              title: Text('今日剩余 $activeCount 条提醒'),
              subtitle: Text('当前时间: ${TimeOfDay.now().format(context)} · 点击测试提醒'),
              trailing: IconButton(
                icon: const Icon(Icons.play_circle, color: Colors.blue),
                onPressed: () {
                  ReminderSchedulerService().debugPrintStatus();
                  if (sorted.isNotEmpty) {
                    NotificationService().showReminderAlert(
                      reminderTitle: sorted.first.title,
                      reminderId: sorted.first.id ?? 0,
                    );
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: sorted.isEmpty
                ? const Center(child: Text('暂无提醒，点击右上角添加'))
                : ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = sorted[index];
                      return Dismissible(
                        key: ValueKey('reminder_${item.id ?? item.title}_${item.time}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.delete, color: Colors.red),
                        ),
                        confirmDismiss: (_) async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('删除提醒'),
                              content: Text('确定删除「${item.title}」吗？'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                                FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text('删除')),
                              ],
                            ),
                          );
                          return confirm ?? false;
                        },
                        onDismissed: (_) => onDelete(item),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: item.completed ? Colors.green.shade200 : Colors.grey.shade200,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: item.completed ? Colors.green.shade50 : Colors.orange.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.completed ? Icons.check : Icons.alarm,
                                color: item.completed ? Colors.green : Colors.orange,
                              ),
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                decoration: item.completed ? TextDecoration.lineThrough : null,
                                color: item.completed ? Colors.grey : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.formattedTime} · ${item.repeatLabel}'),
                                if (item.repeatType == RepeatType.weekly && item.weekdays.isNotEmpty)
                                  Text(
                                    _getWeekdaysText(item.weekdays),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                            isThreeLine: item.repeatType == RepeatType.weekly,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.notifications_active, color: Colors.orange),
                                  tooltip: '测试提醒',
                                  onPressed: () async {
                                    await NotificationService().showReminderAlert(
                                      reminderTitle: item.title,
                                      reminderId: item.id ?? 0,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('已触发提醒: ${item.title}')),
                                      );
                                    }
                                  },
                                ),
                                if (onEdit != null)
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                    onPressed: () => _openEditDialog(context, item),
                                  ),
                                Switch(
                                  value: item.completed,
                                  onChanged: (_) => onToggle(item),
                                  activeColor: Colors.green,
                                ),
                              ],
                            ),
                            onTap: () => onToggle(item),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getWeekdaysText(List<int> weekdays) {
    const weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
    return '每${weekdays.map((d) => '周${weekdayNames[d - 1]}').join('、')}';
  }

  Future<void> _openAddDialog(BuildContext context) async {
    final result = await showDialog<Reminder>(
      context: context,
      builder: (_) => const ReminderDialog(),
    );
    if (result != null) {
      onAdd(result);
    }
  }

  Future<void> _openEditDialog(BuildContext context, Reminder reminder) async {
    final result = await showDialog<Reminder>(
      context: context,
      builder: (_) => ReminderDialog(reminder: reminder),
    );
    if (result != null && onEdit != null) {
      onEdit!(result);
    }
  }
}

class ReminderDialog extends StatefulWidget {
  const ReminderDialog({super.key, this.reminder});

  final Reminder? reminder;

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  late final TextEditingController _title;
  late TimeOfDay _time;
  late RepeatType _repeatType;
  late List<int> _selectedWeekdays;

  bool get isEditing => widget.reminder != null;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    _title = TextEditingController(text: r?.title ?? '');
    _time = r?.time ?? const TimeOfDay(hour: 8, minute: 0);
    _repeatType = r?.repeatType ?? RepeatType.daily;
    _selectedWeekdays = r?.weekdays.toList() ?? [];
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? '编辑提醒' : '新增提醒'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: '提醒内容',
                hintText: '如：吃降压药',
                prefixIcon: Icon(Icons.medication),
              ),
            ),
            const SizedBox(height: 16),
            const Text('提醒时间', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.blue),
                    const SizedBox(width: 12),
                    Text(
                      _time.format(context),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('重复方式', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  RadioListTile<RepeatType>(
                    title: const Text('单次提醒'),
                    subtitle: const Text('仅提醒一次'),
                    value: RepeatType.once,
                    groupValue: _repeatType,
                    onChanged: (v) => setState(() => _repeatType = v!),
                  ),
                  RadioListTile<RepeatType>(
                    title: const Text('每天重复'),
                    subtitle: const Text('每天固定时间提醒'),
                    value: RepeatType.daily,
                    groupValue: _repeatType,
                    onChanged: (v) => setState(() => _repeatType = v!),
                  ),
                  RadioListTile<RepeatType>(
                    title: const Text('每周重复'),
                    subtitle: const Text('选择每周几提醒'),
                    value: RepeatType.weekly,
                    groupValue: _repeatType,
                    onChanged: (v) => setState(() => _repeatType = v!),
                  ),
                ],
              ),
            ),
            if (_repeatType == RepeatType.weekly) ...[
              const SizedBox(height: 12),
              const Text('选择星期', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(7, (index) {
                  final weekday = index + 1;
                  final selected = _selectedWeekdays.contains(weekday);
                  const weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
                  return FilterChip(
                    label: Text('周${weekdayNames[index]}'),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedWeekdays.add(weekday);
                          _selectedWeekdays.sort();
                        } else {
                          _selectedWeekdays.remove(weekday);
                        }
                      });
                    },
                    selectedColor: Colors.blue.shade100,
                    checkmarkColor: Colors.blue,
                  );
                }),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEditing ? '保存' : '添加'),
        ),
      ],
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入提醒内容')),
      );
      return;
    }

    if (_repeatType == RepeatType.weekly && _selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择至少一个星期')),
      );
      return;
    }

    Navigator.of(context).pop(
      Reminder(
        id: widget.reminder?.id,
        title: _title.text.trim(),
        time: _time,
        repeatType: _repeatType,
        weekdays: _repeatType == RepeatType.weekly ? _selectedWeekdays : [],
        completed: widget.reminder?.completed ?? false,
      ),
    );
  }
}
