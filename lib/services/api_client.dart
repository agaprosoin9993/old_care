import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder.dart';
import '../models/contact.dart';
import 'local_cache_service.dart';
import 'sync_service.dart';

class ApiClient {
  ApiClient({String? baseUrl})
      : baseUrl = baseUrl ?? const String.fromEnvironment('BACKEND_BASE_URL', defaultValue: kIsWeb ? 'http://localhost:3001' : 'http://172.20.10.2:3001');

  final String baseUrl;
  String? _token;
  bool get enabled => baseUrl.isNotEmpty;

  static const _offlineToken = 'offline-token';
  bool get _isOffline => _token == _offlineToken || !enabled;
  static const _offlineContactsKey = 'offline_contacts';

  LocalCacheService? _cache;
  SyncService? _sync;

  void setToken(String? token) {
    _token = token;
  }

  void setCache(LocalCacheService cache) {
    _cache = cache;
  }

  void setSync(SyncService sync) {
    _sync = sync;
  }

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers() {
    final h = {HttpHeaders.contentTypeHeader: 'application/json'};
    if (_token != null) h[HttpHeaders.authorizationHeader] = 'Bearer $_token';
    return h;
  }

  Future<List<Reminder>> fetchReminders() async {
    if (!enabled) return [];
    
    try {
      final resp = await http.get(_u('/reminders'), headers: _headers()).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw HttpException('load reminders failed ${resp.statusCode}');
      final data = jsonDecode(resp.body) as List<dynamic>;
      final reminders = data.map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
      
      if (_cache != null) {
        final reminderMaps = reminders.map((r) => r.toJson()).toList();
        await _cache!.saveReminders(reminderMaps);
      }
      
      return reminders;
    } catch (e) {
      debugPrint('获取提醒失败，尝试使用缓存: $e');
      if (_cache != null) {
        final cached = _cache!.getReminders();
        if (cached != null) {
          return cached.map((e) => Reminder.fromJson(e)).toList();
        }
      }
      return [];
    }
  }

  Future<Reminder?> createReminder(Reminder r) async {
    if (!enabled) return null;
    
    try {
      final resp = await http
          .post(_u('/reminders'), headers: _headers(), body: jsonEncode(r.toJson()))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode != 201) throw HttpException('create reminder failed ${resp.statusCode}');
      final created = Reminder.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      
      if (_sync != null && _sync!.isOnline) {
        await _sync!.syncReminders();
      }
      
      return created;
    } catch (e) {
      debugPrint('创建提醒失败: $e');
      if (_sync != null && !_sync!.isOnline) {
        await _sync!.addPendingAction('create_reminder', r.toJson());
      }
      return null;
    }
  }

  Future<Reminder?> updateReminder(Reminder r) async {
    if (!enabled || r.id == null) return null;
    
    try {
      final resp = await http
          .put(_u('/reminders/${r.id}'), headers: _headers(), body: jsonEncode(r.toJson()))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw HttpException('update reminder failed ${resp.statusCode}');
      final updated = Reminder.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      
      if (_sync != null && _sync!.isOnline) {
        await _sync!.syncReminders();
      }
      
      return updated;
    } catch (e) {
      debugPrint('更新提醒失败: $e');
      if (_sync != null && !_sync!.isOnline) {
        await _sync!.addPendingAction('update_reminder', r.toJson());
      }
      return null;
    }
  }

  Future<bool> deleteReminder(int id) async {
    if (!enabled) return false;
    
    try {
      final resp = await http.delete(_u('/reminders/$id'), headers: _headers()).timeout(const Duration(seconds: 5));
      final success = resp.statusCode == 200;
      
      if (success && _sync != null && _sync!.isOnline) {
        await _sync!.syncReminders();
      }
      
      return success;
    } catch (e) {
      debugPrint('删除提醒失败: $e');
      if (_sync != null && !_sync!.isOnline) {
        await _sync!.addPendingAction('delete_reminder', {'id': id});
      }
      return false;
    }
  }

  Future<void> logSOS({String location = '', String contact = '', String note = ''}) async {
    if (!enabled) return;
    
    try {
      await http
          .post(_u('/sos'), headers: _headers(), body: jsonEncode({
            'location': location,
            'contact': contact,
            'note': note,
          }))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('记录SOS失败: $e');
      if (_sync != null && !_sync!.isOnline) {
        await _sync!.addPendingAction('log_sos', {
          'location': location,
          'contact': contact,
          'note': note,
        });
      }
    }
  }

  Future<List<Contact>> fetchContacts() async {
    if (_isOffline) {
      return _loadOfflineContacts();
    }
    try {
      final resp = await http.get(_u('/contacts'), headers: _headers()).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw HttpException('load contacts failed ${resp.statusCode}');
      final data = jsonDecode(resp.body) as List<dynamic>;
      final contacts = data.map((e) => Contact.fromJson(e as Map<String, dynamic>)).toList();
      
      if (_cache != null) {
        final contactMaps = contacts.map((c) => c.toJson()).toList();
        await _cache!.saveContacts(contactMaps);
      }
      
      await _saveOfflineContacts(contacts);
      return contacts;
    } catch (_) {
      if (_cache != null) {
        final cached = _cache!.getContacts();
        if (cached != null) {
          return cached.map((e) => Contact.fromJson(e)).toList();
        }
      }
      return _loadOfflineContacts();
    }
  }

  Future<Contact?> createContact(Contact c) async {
    if (_isOffline) {
      final saved = await _addOfflineContact(c);
      return saved;
    }
    
    try {
      final resp = await http
          .post(_u('/contacts'), headers: _headers(), body: jsonEncode(c.toJson()))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode != 201) throw HttpException('create contact failed ${resp.statusCode}');
      final created = Contact.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      
      if (_sync != null && _sync!.isOnline) {
        await _sync!.syncContacts();
      }
      
      await _appendOfflineContact(created);
      return created;
    } catch (e) {
      debugPrint('创建联系人失败: $e');
      return await _addOfflineContact(c);
    }
  }

  Future<Contact?> updateContact(Contact c) async {
    if (_isOffline || c.id == null) {
      final updated = await _updateOfflineContact(c);
      return updated;
    }
    
    try {
      final resp = await http
          .put(_u('/contacts/${c.id}'), headers: _headers(), body: jsonEncode(c.toJson()))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw HttpException('update contact failed ${resp.statusCode}');
      final updated = Contact.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      await _updateOfflineContact(updated);
      return updated;
    } catch (e) {
      debugPrint('更新联系人失败: $e');
      return await _updateOfflineContact(c);
    }
  }

  Future<bool> deleteContact(int id) async {
    if (_isOffline) {
      final contacts = await _loadOfflineContacts();
      final removed = contacts.where((c) => c.id != id).toList();
      await _saveOfflineContacts(removed);
      return true;
    }
    
    try {
      final resp = await http.delete(_u('/contacts/$id'), headers: _headers()).timeout(const Duration(seconds: 5));
      final ok = resp.statusCode == 200;
      if (ok) {
        final contacts = await _loadOfflineContacts();
        await _saveOfflineContacts(contacts.where((c) => c.id != id).toList());
      }
      return ok;
    } catch (e) {
      debugPrint('删除联系人失败: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserInfo(int userId) async {
    if (!enabled) return null;
    try {
      final resp = await http.get(_u('/auth/users/$userId'), headers: _headers()).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw HttpException('load user info failed ${resp.statusCode}');
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> bindElder(String elderId) async {
    if (!enabled) return null;
    try {
      final resp = await http.put(_u('/auth/bind-elder?elderId=$elderId'), headers: _headers()).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        throw Exception(body['message'] ?? '绑定失败 ${resp.statusCode}');
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      print('bindElder error: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>?> unbindElder() async {
    if (!enabled) return null;
    try {
      final resp = await http.put(_u('/auth/unbind-elder'), headers: _headers()).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw HttpException('unbind elder failed ${resp.statusCode}');
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      print('unbindElder error: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>?> getElderLocation() async {
    if (!enabled) return null;
    try {
      final resp = await http.get(_u('/child/elder/location'), headers: _headers()).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw HttpException('get elder location failed ${resp.statusCode}');
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      
      if (_cache != null) {
        await _cache!.saveElderLocation(data);
      }
      
      return data;
    } catch (e) {
      print('getElderLocation error: $e');
      if (_cache != null) {
        return _cache!.getElderLocation();
      }
      return null;
    }
  }

  Future<List<dynamic>?> getElderSosLogs() async {
    if (!enabled) return null;
    try {
      final resp = await http.get(_u('/child/elder/sos-logs'), headers: _headers()).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw HttpException('get elder sos logs failed ${resp.statusCode}');
      final data = jsonDecode(resp.body) as List<dynamic>;
      
      if (_cache != null) {
        await _cache!.saveSosLogs(data.cast<Map<String, dynamic>>());
      }
      
      return data;
    } catch (e) {
      print('getElderSosLogs error: $e');
      if (_cache != null) {
        final cached = _cache!.getSosLogs();
        return cached;
      }
      return null;
    }
  }

  Future<List<dynamic>?> getElderReminders() async {
    if (!enabled) return null;
    try {
      final resp = await http.get(_u('/child/elder/reminders'), headers: _headers()).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw HttpException('get elder reminders failed ${resp.statusCode}');
      final data = jsonDecode(resp.body) as List<dynamic>;
      
      if (_cache != null) {
        await _cache!.saveElderReminders(data.cast<Map<String, dynamic>>());
      }
      
      return data;
    } catch (e) {
      print('getElderReminders error: $e');
      if (_cache != null) {
        final cached = _cache!.getElderReminders();
        return cached;
      }
      return null;
    }
  }

  Future<bool> updateLocation(String location, {double? latitude, double? longitude}) async {
    if (!enabled) return false;
    try {
      final body = <String, dynamic>{'location': location};
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      final resp = await http.put(_u('/auth/update-location'), headers: _headers(), body: jsonEncode(body)).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (e) {
      print('updateLocation error: $e');
      if (_sync != null && !_sync!.isOnline) {
        await _sync!.addPendingAction('update_location', {
          'location': location,
          'latitude': latitude,
          'longitude': longitude,
        });
      }
      return false;
    }
  }

  Future<int> getElderSosUnreadCount() async {
    if (!enabled) return 0;
    try {
      final resp = await http.get(_u('/child/elder/sos-unread-count'), headers: _headers()).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw HttpException('get sos unread count failed ${resp.statusCode}');
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['count'] as int? ?? 0;
    } catch (e) {
      print('getElderSosUnreadCount error: $e');
      return 0;
    }
  }

  Future<bool> markSosAsRead(int sosId) async {
    if (!enabled) return false;
    try {
      final resp = await http.put(_u('/child/elder/sos-logs/$sosId/read'), headers: _headers()).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (e) {
      print('markSosAsRead error: $e');
      return false;
    }
  }

  Future<bool> markAllSosAsRead() async {
    if (!enabled) return false;
    try {
      final resp = await http.put(_u('/child/elder/sos-logs/read-all'), headers: _headers()).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (e) {
      print('markAllSosAsRead error: $e');
      return false;
    }
  }

  Future<bool> deleteSosLog(int sosId) async {
    if (!enabled) return false;
    try {
      final resp = await http.delete(_u('/child/elder/sos-logs/$sosId'), headers: _headers()).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (e) {
      print('deleteSosLog error: $e');
      return false;
    }
  }

  Future<bool> remindElderAboutReminder(int reminderId) async {
    if (!enabled) return false;
    try {
      final resp = await http.post(
        _u('/child/elder/reminders/$reminderId/remind'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('提醒老人失败: $e');
      return false;
    }
  }

  Future<List<Contact>> _loadOfflineContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_offlineContactsKey) ?? [];
    return raw
        .map((e) => Contact.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
  }

  Future<void> _saveOfflineContacts(List<Contact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = contacts.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_offlineContactsKey, serialized);
  }

  Future<Contact> _addOfflineContact(Contact c) async {
    final contacts = await _loadOfflineContacts();
    final newId = (contacts.map((e) => e.id ?? 0).fold<int>(0, (p, n) => n > p ? n : p)) + 1;
    final created = Contact(
      id: newId,
      name: c.name,
      phone: c.phone,
      relation: c.relation,
    );
    contacts.add(created);
    await _saveOfflineContacts(contacts);
    return created;
  }

  Future<void> _appendOfflineContact(Contact c) async {
    final contacts = await _loadOfflineContacts();
    contacts.removeWhere((x) => x.id == c.id);
    contacts.add(c);
    await _saveOfflineContacts(contacts);
  }

  Future<Contact?> _updateOfflineContact(Contact c) async {
    if (c.id == null) return null;
    final contacts = await _loadOfflineContacts();
    final idx = contacts.indexWhere((x) => x.id == c.id);
    if (idx < 0) return null;
    contacts[idx] = c;
    await _saveOfflineContacts(contacts);
    return c;
  }
}
