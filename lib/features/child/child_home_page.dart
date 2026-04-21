import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../../models/reminder.dart';
import '../../widgets/location_map_widget.dart';

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

class _ChildHomePageState extends State<ChildHomePage> with WidgetsBindingObserver {
  int _tabIndex = 0;

  String _elderLocation = '未获取';
  double? _elderLatitude;
  double? _elderLongitude;
  DateTime? _lastLocationUpdate;
  bool _isLoadingLocation = false;

  double? _myLatitude;
  double? _myLongitude;
  bool _isLoadingMyLocation = false;

  List<Map<String, dynamic>> _sosLogs = [];
  bool _isLoadingSos = false;
  String? _lastSosId;
  int _unreadCount = 0;

  List<Reminder> _elderReminders = [];
  bool _isLoadingReminders = false;

  Timer? _pollingTimer;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNotifications();
    _loadElderData();
    _loadMyLocation();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadElderData();
      _loadMyLocation();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollingTimer?.cancel();
    }
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _pollElderData();
    });
  }

  Future<void> _pollElderData() async {
    await _checkSosAlerts();
    await _checkLocationUpdate();
  }

  Future<void> _loadElderData() async {
    await Future.wait([
      _loadElderLocation(),
      _loadSosLogs(),
      _loadElderReminders(),
    ]);
    await _loadUnreadCount();
  }

  Future<void> _loadMyLocation() async {
    setState(() => _isLoadingMyLocation = true);
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position? position;
      
      if (serviceEnabled && 
          permission != LocationPermission.denied && 
          permission != LocationPermission.deniedForever) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15),
            ),
          );
        } catch (e) {
          debugPrint('高精度定位失败: $e');
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 10),
              ),
            );
          } catch (e2) {
            debugPrint('低精度定位失败: $e2');
            position = await Geolocator.getLastKnownPosition();
          }
        }
      }
      
      if (position == null) {
        position = Position(
          latitude: 39.9042,
          longitude: 116.4074,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }

      if (mounted) {
        setState(() {
          _myLatitude = position!.latitude;
          _myLongitude = position.longitude;
        });
      }
    } catch (e) {
      debugPrint('获取自己位置失败: $e');
      if (mounted) {
        setState(() {
          _myLatitude = 39.9042;
          _myLongitude = 116.4074;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMyLocation = false);
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    final count = await widget.api.getElderSosUnreadCount();
    if (mounted) {
      setState(() {
        _unreadCount = count;
      });
    }
  }

  Future<void> _checkSosAlerts() async {
    try {
      final result = await widget.api.getElderSosLogs();
      if (result != null && result.isNotEmpty && mounted) {
        final latestSos = result.first as Map<String, dynamic>;
        final latestSosId = latestSos['id'].toString();

        if (_lastSosId != null && _lastSosId != latestSosId) {
          final location = latestSos['location'] as String?;
          await _notificationService.showSosAlert(
            elderName: widget.elderName ?? '老人',
            location: location,
          );
        }

        _lastSosId = latestSosId;

        setState(() {
          _sosLogs = result.cast<Map<String, dynamic>>();
        });
        await _loadUnreadCount();
      }
    } catch (e) {
      debugPrint('检查SOS告警失败: $e');
    }
  }

  Future<void> _checkLocationUpdate() async {
    try {
      final result = await widget.api.getElderLocation();
      if (result != null && mounted) {
        final newLocation = result['location'] as String? ?? '未知位置';
        final newUpdateTime = result['updatedAt'] != null
            ? DateTime.parse(result['updatedAt'] as String)
            : null;

        if (_lastLocationUpdate != null &&
            newUpdateTime != null &&
            newUpdateTime.isAfter(_lastLocationUpdate!) &&
            _elderLocation != newLocation) {
          await _notificationService.showLocationUpdate(
            elderName: widget.elderName ?? '老人',
            location: newLocation,
          );
        }

        setState(() {
          _elderLocation = newLocation;
          _lastLocationUpdate = newUpdateTime;
        });
      }
    } catch (e) {
      debugPrint('检查位置更新失败: $e');
    }
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
          if (result['latitude'] != null && result['longitude'] != null) {
            _elderLatitude = (result['latitude'] as num).toDouble();
            _elderLongitude = (result['longitude'] as num).toDouble();
          }
        });
      }
    } catch (e) {
      debugPrint('加载老人位置失败: $e');
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
          if (_sosLogs.isNotEmpty) {
            _lastSosId = _sosLogs.first['id'].toString();
          }
        });
      }
    } catch (e) {
      debugPrint('加载SOS日志失败: $e');
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
          _elderReminders = result
              .map((e) => Reminder.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('加载老人提醒失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingReminders = false);
      }
    }
  }

  Future<void> _markSosAsRead(int sosId) async {
    await widget.api.markSosAsRead(sosId);
    setState(() {
      final index = _sosLogs.indexWhere((log) => log['id'] == sosId);
      if (index != -1) {
        _sosLogs[index]['isRead'] = true;
      }
    });
    await _loadUnreadCount();
  }

  Future<void> _markAllAsRead() async {
    await widget.api.markAllSosAsRead();
    setState(() {
      for (var log in _sosLogs) {
        log['isRead'] = true;
      }
      _unreadCount = 0;
    });
  }

  Future<void> _deleteSosLog(int sosId) async {
    final success = await widget.api.deleteSosLog(sosId);
    if (success) {
      setState(() {
        _sosLogs.removeWhere((log) => log['id'] == sosId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除SOS记录')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除失败，请重试')),
        );
      }
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '未知';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return '未知';

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else {
      return '${diff.inDays}天前';
    }
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
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.location_on_outlined),
            selectedIcon: const Icon(Icons.location_on),
            label: '位置',
          ),
          NavigationDestination(
            icon: _unreadCount > 0
                ? Badge(
                    label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
                    child: const Icon(Icons.warning_amber_outlined),
                  )
                : const Icon(Icons.warning_amber_outlined),
            selectedIcon: _unreadCount > 0
                ? Badge(
                    label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
                    child: const Icon(Icons.warning),
                  )
                : const Icon(Icons.warning),
            label: 'SOS告警',
          ),
          NavigationDestination(
            icon: const Icon(Icons.alarm_outlined),
            selectedIcon: const Icon(Icons.alarm),
            label: '提醒事项',
          ),
        ],
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
      ),
    );
  }

  Widget _buildLocationTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadElderLocation();
        await _loadMyLocation();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMapCard(),
            const SizedBox(height: 16),
            _buildLocationInfoCard(),
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

  Widget _buildMapCard() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.map, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '位置地图',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_isLoadingLocation || _isLoadingMyLocation)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          LocationMapWidget(
            zoom: 14,
            height: 280,
            center: _elderLatitude != null && _elderLongitude != null
                ? LatLng(_elderLatitude!, _elderLongitude!)
                : (_myLatitude != null && _myLongitude != null
                    ? LatLng(_myLatitude!, _myLongitude!)
                    : null),
            markers: [
              if (_elderLatitude != null && _elderLongitude != null)
                MapMarker(
                  position: LatLng(_elderLatitude!, _elderLongitude!),
                  label: '${widget.elderName ?? '老人'}的位置',
                  color: Colors.red,
                ),
              if (_myLatitude != null && _myLongitude != null)
                MapMarker(
                  position: LatLng(_myLatitude!, _myLongitude!),
                  label: '我的位置',
                  color: Colors.blue,
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(Colors.red, '老人位置', Icons.elderly),
                _buildLegendItem(Colors.blue, '我的位置', Icons.person_pin_circle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildLocationInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLocationRow(
              Icons.elderly,
              Colors.red,
              '${widget.elderName ?? '老人'}的位置',
              _elderLocation,
              _elderLatitude,
              _elderLongitude,
              _lastLocationUpdate,
            ),
            const Divider(height: 24),
            _buildLocationRow(
              Icons.person,
              Colors.blue,
              '我的位置',
              _myLatitude != null ? '已获取' : '未获取',
              _myLatitude,
              _myLongitude,
              null,
              isMyLocation: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(
    IconData icon,
    Color color,
    String title,
    String location,
    double? latitude,
    double? longitude,
    DateTime? updateTime, {
    bool isMyLocation = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (updateTime != null)
              Text(
                _formatRelativeTime(updateTime),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.place, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(child: Text(location, style: const TextStyle(fontSize: 14))),
          ],
        ),
        if (latitude != null && longitude != null) ...[
          const SizedBox(height: 4),
          Text(
            '经度: ${longitude.toStringAsFixed(6)}  纬度: ${latitude.toStringAsFixed(6)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
        if (isMyLocation) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isLoadingMyLocation ? null : _loadMyLocation,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新我的位置'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSosTab() {
    final recentSos = _sosLogs.where((log) {
      final createdAt = DateTime.parse(log['createdAt'] as String);
      return DateTime.now().difference(createdAt).inDays < 7;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await _loadSosLogs();
        await _loadUnreadCount();
      },
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _unreadCount > 0 ? Colors.red.shade50 : Colors.green.shade50,
            child: Row(
              children: [
                Icon(
                  _unreadCount > 0 ? Icons.warning : Icons.check_circle,
                  color: _unreadCount > 0 ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _unreadCount > 0
                        ? '有 $_unreadCount 条未读SOS告警'
                        : '${widget.elderName ?? '老人'}近期无SOS告警',
                    style: TextStyle(
                      color: _unreadCount > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                ),
                if (_unreadCount > 0)
                  TextButton(
                    onPressed: _markAllAsRead,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('全部已读'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingSos
                ? const Center(child: CircularProgressIndicator())
                : recentSos.isEmpty
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
                            const SizedBox(height: 8),
                            const Text(
                              '老人触发SOS时您将收到实时通知',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: recentSos.length,
                        itemBuilder: (context, index) {
                          final log = recentSos[index];
                          final createdAt = DateTime.parse(log['createdAt'] as String);
                          final isRead = log['isRead'] == true;

                          return Dismissible(
                            key: Key('sos_${log['id']}'),
                            direction: isRead
                                ? DismissDirection.endToStart
                                : DismissDirection.none,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('确认删除'),
                                  content: const Text('确定要删除这条SOS告警记录吗？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('删除'),
                                    ),
                                  ],
                                ),
                              ) ?? false;
                            },
                            onDismissed: (direction) async {
                              await _deleteSosLog(log['id'] as int);
                            },
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: !isRead ? Colors.red.shade50 : null,
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: !isRead
                                        ? Colors.red.shade100
                                        : Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.warning,
                                    color: !isRead ? Colors.red : Colors.grey,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'SOS求救 - ${_formatDateTime(createdAt)}',
                                        style: TextStyle(
                                          color: !isRead ? Colors.red : null,
                                          fontWeight: !isRead ? FontWeight.bold : null,
                                        ),
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          '未读',
                                          style: TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                    if (isRead)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          '左滑删除',
                                          style: TextStyle(color: Colors.grey, fontSize: 11),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('位置: ${log['location'] ?? '未知'}'),
                                    Text('联系人: ${log['contact'] ?? '未知'}'),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: !isRead
                                    ? TextButton(
                                        onPressed: () => _markSosAsRead(log['id'] as int),
                                        child: const Text('标记已读'),
                                      )
                                    : const Icon(Icons.check_circle, color: Colors.green),
                                onTap: () => _showSosDetailDialog(log),
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

  void _showSosDetailDialog(Map<String, dynamic> log) {
    final createdAt = DateTime.parse(log['createdAt'] as String);
    final isRead = log['isRead'] == true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            const Text('SOS告警详情'),
            if (!isRead)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '未读',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.access_time, '时间', _formatDateTime(createdAt)),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.location_on, '位置', log['location'] ?? '未知'),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.person, '联系人', log['contact'] ?? '未知'),
            if (log['note'] != null && log['note'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDetailRow(Icons.note, '备注', log['note']),
            ],
          ],
        ),
        actions: [
          if (!isRead)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _markSosAsRead(log['id'] as int);
              },
              child: const Text('标记已读'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRemindersTab() {
    final completedReminders = _elderReminders.where((r) => r.completed).toList();
    final pendingReminders = _elderReminders.where((r) => !r.completed).toList();

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
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (pendingReminders.isNotEmpty) ...[
                      _buildSectionHeader('待完成', pendingReminders.length),
                      ...pendingReminders.map((r) => _buildReminderCard(r)),
                      const SizedBox(height: 16),
                    ],
                    if (completedReminders.isNotEmpty) ...[
                      _buildSectionHeader('已完成', completedReminders.length),
                      ...completedReminders.map((r) => _buildReminderCard(r)),
                    ],
                  ],
                ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: reminder.completed ? Colors.green.shade50 : Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            reminder.completed ? Icons.check : Icons.alarm,
            color: reminder.completed ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          reminder.title,
          style: TextStyle(
            decoration: reminder.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '${reminder.formattedTime} ${reminder.repeatType == RepeatType.daily ? '(每日重复)' : reminder.repeatLabel}',
        ),
        trailing: reminder.completed
            ? const Text('已完成', style: TextStyle(color: Colors.green))
            : const Text('待完成', style: TextStyle(color: Colors.orange)),
      ),
    );
  }
}
