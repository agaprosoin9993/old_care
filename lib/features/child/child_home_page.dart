import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../models/reminder.dart';

class ChildHomePage extends StatefulWidget {
  final ApiClient api;
  final String? elderName;
  final VoidCallback onUnbind;

  const ChildHomePage({
    super.key,
    required this.api,
    this.elderName,
    required this.onUnbind,
  });

  @override
  State<ChildHomePage> createState() => _ChildHomePageState();
}

class _ChildHomePageState extends State<ChildHomePage> {
  int _tabIndex = 0;
  
  String _elderLocation = '未获取';
  DateTime? _lastLocationUpdate;
  bool _isLoadingLocation = false;
  
  List<Map<String, dynamic>> _sosLogs = [];
  bool _isLoadingSos = false;
  
  List<Reminder> _elderReminders = [];
  bool _isLoadingReminders = false;

  @override
  void initState() {
    super.initState();
    _loadElderData();
  }

  Future<void> _loadElderData() async {
    _loadElderLocation();
    _loadSosLogs();
    _loadElderReminders();
  }

  Future<void> _loadElderLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      final result = await widget.api.getElderLocation();
      if (result != null && mounted) {
        setState(() {
          _elderLocation = result['location'] as String? ?? '未知位置';
          if (result['updatedAt'] != null) {
            _lastLocationUpdate = DateTime.parse(result['updatedAt'] as String);
          }
        });
      }
    } catch (e) {
      print('加载老人位置失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _loadSosLogs() async {
    setState(() => _isLoadingSos = true);
    
    try {
      final result = await widget.api.getElderSosLogs();
      if (result != null && mounted) {
        setState(() {
          _sosLogs = result.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('加载SOS日志失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingSos = false);
      }
    }
  }

  Future<void> _loadElderReminders() async {
    setState(() => _isLoadingReminders = true);
    
    try {
      final result = await widget.api.getElderReminders();
      if (result != null && mounted) {
        setState(() {
          _elderReminders = result.map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
        });
      }
    } catch (e) {
      print('加载老人提醒失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingReminders = false);
      }
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '未知';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildLocationTab(),
          _buildSosTab(),
          _buildRemindersTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.location_on), label: '老人位置'),
          NavigationDestination(icon: Icon(Icons.warning), label: 'SOS告警'),
          NavigationDestination(icon: Icon(Icons.alarm), label: '提醒事项'),
        ],
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
      ),
    );
  }

  Widget _buildLocationTab() {
    return RefreshIndicator(
      onRefresh: _loadElderLocation,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.redAccent, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.elderName ?? '老人'}的位置',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isLoadingLocation)
                      const Center(child: CircularProgressIndicator())
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.place, size: 20, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _elderLocation,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 20, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                '更新时间: ${_formatDateTime(_lastLocationUpdate)}',
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.elderName == null)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('您还未绑定老人，请先绑定老人账号'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSosTab() {
    return RefreshIndicator(
      onRefresh: _loadSosLogs,
      child: _isLoadingSos
          ? const Center(child: CircularProgressIndicator())
          : _sosLogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, size: 64, color: Colors.green),
                      const SizedBox(height: 16),
                      Text(
                        '${widget.elderName ?? '老人'}近期无SOS告警',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sosLogs.length,
                  itemBuilder: (context, index) {
                    final log = _sosLogs[index];
                    final createdAt = DateTime.parse(log['createdAt'] as String);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.warning, color: Colors.red),
                        title: Text('SOS求救 - ${_formatDateTime(createdAt)}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('位置: ${log['location'] ?? '未知'}'),
                            Text('联系人: ${log['contact'] ?? '未知'}'),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildRemindersTab() {
    return RefreshIndicator(
      onRefresh: _loadElderReminders,
      child: _isLoadingReminders
          ? const Center(child: CircularProgressIndicator())
          : _elderReminders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.alarm_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        '${widget.elderName ?? '老人'}暂无提醒事项',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _elderReminders.length,
                  itemBuilder: (context, index) {
                    final reminder = _elderReminders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          reminder.completed ? Icons.check_circle : Icons.alarm,
                          color: reminder.completed ? Colors.green : Colors.orange,
                        ),
                        title: Text(
                          reminder.title,
                          style: TextStyle(
                            decoration: reminder.completed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          '${reminder.formattedTime} ${reminder.repeating ? '(每日重复)' : ''}',
                        ),
                        trailing: reminder.completed
                            ? const Text('已完成', style: TextStyle(color: Colors.green))
                            : const Text('未完成', style: TextStyle(color: Colors.orange)),
                      ),
                    );
                  },
                ),
    );
  }
}
