import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  static LocalCacheService? _instance;
  static SharedPreferences? _prefs;

  LocalCacheService._();

  static Future<LocalCacheService> getInstance() async {
    if (_instance == null) {
      _prefs = await SharedPreferences.getInstance();
      _instance = LocalCacheService._();
    }
    return _instance!;
  }

  static const String _keyUserToken = 'cache_user_token';
  static const String _keyUserData = 'cache_user_data';
  static const String _keyReminders = 'cache_reminders';
  static const String _keyContacts = 'cache_contacts';
  static const String _keyLocation = 'cache_location';
  static const String _keySosLogs = 'cache_sos_logs';
  static const String _keyLastSyncTime = 'cache_last_sync_time';
  static const String _keyElderLocation = 'cache_elder_location';
  static const String _keyElderReminders = 'cache_elder_reminders';
  static const String _keyPendingActions = 'cache_pending_actions';

  Future<void> saveUserToken(String token) async {
    await _prefs!.setString(_keyUserToken, token);
  }

  String? getUserToken() {
    return _prefs!.getString(_keyUserToken);
  }

  Future<void> clearUserToken() async {
    await _prefs!.remove(_keyUserToken);
  }

  Future<void> saveUserData(Map<String, dynamic> userData) async {
    userData['cachedAt'] = DateTime.now().toIso8601String();
    await _prefs!.setString(_keyUserData, jsonEncode(userData));
  }

  Map<String, dynamic>? getUserData() {
    final data = _prefs!.getString(_keyUserData);
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  Future<void> clearUserData() async {
    await _prefs!.remove(_keyUserData);
  }

  Future<void> saveReminders(List<Map<String, dynamic>> reminders) async {
    final data = {
      'items': reminders,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await _prefs!.setString(_keyReminders, jsonEncode(data));
  }

  List<Map<String, dynamic>>? getReminders() {
    final data = _prefs!.getString(_keyReminders);
    if (data == null) return null;
    final decoded = jsonDecode(data) as Map<String, dynamic>;
    return (decoded['items'] as List).cast<Map<String, dynamic>>();
  }

  DateTime? getRemindersCachedAt() {
    final data = _prefs!.getString(_keyReminders);
    if (data == null) return null;
    final decoded = jsonDecode(data) as Map<String, dynamic>;
    if (decoded['cachedAt'] != null) {
      return DateTime.parse(decoded['cachedAt'] as String);
    }
    return null;
  }

  Future<void> saveContacts(List<Map<String, dynamic>> contacts) async {
    final data = {
      'items': contacts,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await _prefs!.setString(_keyContacts, jsonEncode(data));
  }

  List<Map<String, dynamic>>? getContacts() {
    final data = _prefs!.getString(_keyContacts);
    if (data == null) return null;
    final decoded = jsonDecode(data) as Map<String, dynamic>;
    return (decoded['items'] as List).cast<Map<String, dynamic>>();
  }

  DateTime? getContactsCachedAt() {
    final data = _prefs!.getString(_keyContacts);
    if (data == null) return null;
    final decoded = jsonDecode(data) as Map<String, dynamic>;
    if (decoded['cachedAt'] != null) {
      return DateTime.parse(decoded['cachedAt'] as String);
    }
    return null;
  }

  Future<void> saveLocation(Map<String, dynamic> locationData) async {
    locationData['cachedAt'] = DateTime.now().toIso8601String();
    await _prefs!.setString(_keyLocation, jsonEncode(locationData));
  }

  Map<String, dynamic>? getLocation() {
    final data = _prefs!.getString(_keyLocation);
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  Future<void> saveElderLocation(Map<String, dynamic> locationData) async {
    locationData['cachedAt'] = DateTime.now().toIso8601String();
    await _prefs!.setString(_keyElderLocation, jsonEncode(locationData));
  }

  Map<String, dynamic>? getElderLocation() {
    final data = _prefs!.getString(_keyElderLocation);
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  Future<void> saveElderReminders(List<Map<String, dynamic>> reminders) async {
    final data = {
      'items': reminders,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await _prefs!.setString(_keyElderReminders, jsonEncode(data));
  }

  List<Map<String, dynamic>>? getElderReminders() {
    final data = _prefs!.getString(_keyElderReminders);
    if (data == null) return null;
    final decoded = jsonDecode(data) as Map<String, dynamic>;
    return (decoded['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveSosLogs(List<Map<String, dynamic>> logs) async {
    final data = {
      'items': logs,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await _prefs!.setString(_keySosLogs, jsonEncode(data));
  }

  List<Map<String, dynamic>>? getSosLogs() {
    final data = _prefs!.getString(_keySosLogs);
    if (data == null) return null;
    final decoded = jsonDecode(data) as Map<String, dynamic>;
    return (decoded['items'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> saveLastSyncTime(DateTime time) async {
    await _prefs!.setString(_keyLastSyncTime, time.toIso8601String());
  }

  DateTime? getLastSyncTime() {
    final data = _prefs!.getString(_keyLastSyncTime);
    if (data == null) return null;
    return DateTime.parse(data);
  }

  Future<void> addPendingAction(Map<String, dynamic> action) async {
    final actions = getPendingActions() ?? [];
    action['createdAt'] = DateTime.now().toIso8601String();
    actions.add(action);
    await _prefs!.setString(_keyPendingActions, jsonEncode(actions));
  }

  List<Map<String, dynamic>>? getPendingActions() {
    final data = _prefs!.getString(_keyPendingActions);
    if (data == null) return null;
    return (jsonDecode(data) as List).cast<Map<String, dynamic>>();
  }

  Future<void> removePendingAction(int index) async {
    final actions = getPendingActions() ?? [];
    if (index >= 0 && index < actions.length) {
      actions.removeAt(index);
      await _prefs!.setString(_keyPendingActions, jsonEncode(actions));
    }
  }

  Future<void> clearPendingActions() async {
    await _prefs!.remove(_keyPendingActions);
  }

  Future<void> clearAll() async {
    await _prefs!.remove(_keyUserToken);
    await _prefs!.remove(_keyUserData);
    await _prefs!.remove(_keyReminders);
    await _prefs!.remove(_keyContacts);
    await _prefs!.remove(_keyLocation);
    await _prefs!.remove(_keySosLogs);
    await _prefs!.remove(_keyElderLocation);
    await _prefs!.remove(_keyElderReminders);
    await _prefs!.remove(_keyPendingActions);
  }

  Future<void> clearSyncData() async {
    await _prefs!.remove(_keyReminders);
    await _prefs!.remove(_keyContacts);
    await _prefs!.remove(_keyLocation);
    await _prefs!.remove(_keySosLogs);
    await _prefs!.remove(_keyElderLocation);
    await _prefs!.remove(_keyElderReminders);
    await _prefs!.remove(_keyLastSyncTime);
  }
}
