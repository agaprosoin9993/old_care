import 'package:flutter/material.dart';

import '../../models/reminder.dart';

class ReminderPage extends StatelessWidget {
  const ReminderPage({
    super.key,
    required this.reminders,
    required this.onToggle,
    required this.onAdd,
    required this.onDelete,
  });

  final List<Reminder> reminders;
  final ValueChanged<Reminder> onToggle;
  final ValueChanged<Reminder> onAdd;
  final ValueChanged<Reminder> onDelete;

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
                onPressed: () => _openDialog(context),
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
              subtitle: const Text('按时间排序，完成的会排在后面'),
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
                        key: ValueKey('${item.title}_${item.time}'),
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
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
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
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: Icon(
                              item.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: item.completed ? Colors.green : Colors.grey,
                            ),
                            title: Text(item.title),
                            subtitle: Text('提醒时间：${item.formattedTime} · ${item.repeatLabel}'),
                            trailing: Switch(value: item.completed, onChanged: (_) => onToggle(item)),
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

  Future<void> _openDialog(BuildContext context) async {
    final result = await showDialog<Reminder>(
      context: context,
      builder: (_) => const ReminderDialog(),
    );
    if (result != null) {
      onAdd(result);
    }
  }
}

class ReminderDialog extends StatefulWidget {
  const ReminderDialog({super.key});

  @override
  State<ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<ReminderDialog> {
  final TextEditingController _title = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  bool _repeatDaily = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增提醒'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '内容', hintText: '如：早上8:00 吃降压药'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('时间：'),
              TextButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (picked != null) {
                    setState(() => _time = picked);
                  }
                },
                child: Text(_time.format(context)),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('每天重复'),
            value: _repeatDaily,
            onChanged: (v) => setState(() => _repeatDaily = v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            Navigator.of(context).pop(
              Reminder(title: _title.text.trim(), time: _time, repeating: _repeatDaily),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
