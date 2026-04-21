import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_cache_service.dart';
import 'api_client.dart';
import 'auth_service.dart';

enum SyncStatus {
  idle,
  syncing,
  offline,
  error,
}

class SyncService extends ChangeNotifier {
  static SyncService? _instance;

  factory SyncService() {
    _instance ??= SyncService._internal();
    return _instance!;
  }

  SyncService._internal();

  final Connectivity _connectivity = Connectivity();
  LocalCacheService? _cache;
  
  ApiClient? _api;
  AuthService? _auth;
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;
  
  bool _isOnline = true;
  SyncStatus _status = SyncStatus.idle;
  String _lastError = '';
  DateTime? _lastSyncTime;

  bool get isOnline => _isOnline;
  SyncStatus get status => _status;
  String get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;

  void initialize(ApiClient api, AuthService auth, LocalCacheService cache) {
    _api = api;
    _auth = auth;
    _cache = cache;
    _initConnectivity();
    _startPeriodicSync();
  }

  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
      
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    } catch (e) {
      debugPrint('初始化网络检测失败: $e');
      _isOnline = true;
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasOffline = !_isOnline;
    
    if (results.contains(ConnectivityResult.none)) {
      _isOnline = false;
      _status = SyncStatus.offline;
      debugPrint('网络状态: 离线');
    } else {
      _isOnline = true;
      _status = SyncStatus.idle;
      debugPrint('网络状态: 在线 (${results.join(', ')})');
      
      if (wasOffline) {
        debugPrint('网络恢复，开始同步...');
        syncAll();
      }
    }
    
    notifyListeners();
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline) {
        syncAll();
      }
    });
  }

  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return !results.contains(ConnectivityResult.none);
    } catch (e) {
      return true;
    }
  }

  Future<bool> checkServerReachable() async {
    if (_api == null || !_api!.enabled) return false;
    
    try {
      final result = await InternetAddress.lookup('www.baidu.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> syncAll() async {
    if (_status == SyncStatus.syncing) return;
    if (!_isOnline) {
      debugPrint('离线状态，跳过同步');
      return;
    }

    _status = SyncStatus.syncing;
    _lastError = '';
    notifyListeners();

    try {
      await Future.wait([
        _syncReminders(),
        _syncContacts(),
        _syncPendingActions(),
      ]);

      _lastSyncTime = DateTime.now();
      if (_cache != null) {
        await _cache!.saveLastSyncTime(_lastSyncTime!);
      }
      
      _status = SyncStatus.idle;
      debugPrint('数据同步完成: $_lastSyncTime');
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
      debugPrint('数据同步失败: $e');
    }

    notifyListeners();
  }

  Future<void> _syncReminders() async {
    if (_api == null || _cache == null) return;

    try {
      final reminders = await _api!.fetchReminders();
      final reminderMaps = reminders.map((r) => r.toJson()).toList();
      await _cache!.saveReminders(reminderMaps);
      debugPrint('同步提醒数据: ${reminders.length} 条');
    } catch (e) {
      debugPrint('同步提醒失败: $e');
    }
  }

  Future<void> _syncContacts() async {
    if (_api == null || _cache == null) return;

    try {
      final contacts = await _api!.fetchContacts();
      final contactMaps = contacts.map((c) => c.toJson()).toList();
      await _cache!.saveContacts(contactMaps);
      debugPrint('同步联系人数据: ${contacts.length} 条');
    } catch (e) {
      debugPrint('同步联系人失败: $e');
    }
  }

  Future<void> _syncPendingActions() async {
    if (_api == null || _cache == null) return;

    final actions = _cache!.getPendingActions();
    if (actions == null || actions.isEmpty) return;

    final successIndices = <int>[];
    
    for (var i = 0; i < actions.length; i++) {
      final action = actions[i];
      try {
        await _executePendingAction(action);
        successIndices.add(i);
        debugPrint('执行离线操作成功: ${action['type']}');
      } catch (e) {
        debugPrint('执行离线操作失败: ${action['type']}, $e');
      }
    }

    for (var i = successIndices.length - 1; i >= 0; i--) {
      await _cache!.removePendingAction(successIndices[i]);
    }
  }

  Future<void> _executePendingAction(Map<String, dynamic> action) async {
    final type = action['type'] as String;
    final data = action['data'] as Map<String, dynamic>;

    switch (type) {
      case 'update_reminder':
        if (data['id'] != null) {
          await _api!.updateReminder(_reminderFromJson(data));
        }
        break;
      case 'create_reminder':
        await _api!.createReminder(_reminderFromJson(data));
        break;
      case 'delete_reminder':
        await _api!.deleteReminder(data['id'] as int);
        break;
      case 'update_location':
        await _api!.updateLocation(
          data['location'] as String,
          latitude: data['latitude'] as double?,
          longitude: data['longitude'] as double?,
        );
        break;
      case 'log_sos':
        await _api!.logSOS(
          location: data['location'] as String? ?? '',
          contact: data['contact'] as String? ?? '',
          note: data['note'] as String? ?? '',
        );
        break;
    }
  }

  dynamic _reminderFromJson(Map<String, dynamic> json) {
    return json;
  }

  Future<void> addPendingAction(String type, Map<String, dynamic> data) async {
    if (_cache == null) return;
    await _cache!.addPendingAction({'type': type, 'data': data});
    debugPrint('添加离线操作: $type');
  }

  Future<void> syncReminders() => _syncReminders();
  Future<void> syncContacts() => _syncContacts();

  Future<void> saveLocationToCache(Map<String, dynamic> locationData) async {
    if (_cache == null) return;
    await _cache!.saveLocation(locationData);
  }

  Future<void> saveElderLocationToCache(Map<String, dynamic> locationData) async {
    if (_cache == null) return;
    await _cache!.saveElderLocation(locationData);
  }

  Map<String, dynamic>? getCachedElderLocation() {
    return _cache?.getElderLocation();
  }

  List<Map<String, dynamic>>? getCachedReminders() {
    return _cache?.getReminders();
  }

  List<Map<String, dynamic>>? getCachedContacts() {
    return _cache?.getContacts();
  }

  List<Map<String, dynamic>>? getCachedSosLogs() {
    return _cache?.getSosLogs();
  }

  Future<void> saveSosLogsToCache(List<Map<String, dynamic>> logs) async {
    if (_cache == null) return;
    await _cache!.saveSosLogs(logs);
  }

  Future<void> saveElderRemindersToCache(List<Map<String, dynamic>> reminders) async {
    if (_cache == null) return;
    await _cache!.saveElderReminders(reminders);
  }

  List<Map<String, dynamic>>? getCachedElderReminders() {
    return _cache?.getElderReminders();
  }

  Future<void> clearCache() async {
    if (_cache == null) return;
    await _cache!.clearSyncData();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }
}
