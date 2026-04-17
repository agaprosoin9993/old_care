import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder.dart';
import '../models/contact.dart';

class ApiClient {
  ApiClient({String? baseUrl})
      : baseUrl = baseUrl ?? const String.fromEnvironment('BACKEND_BASE_URL', defaultValue: kIsWeb ? 'http://localhost:3001' : 'http://10.0.2.2:3001');

  final String baseUrl;
  String? _token;
  bool get enabled => baseUrl.isNotEmpty;

  static const _offlineToken = 'offline-token';
  bool get _isOffline => _token == _offlineToken || !enabled;
  static const _offlineContactsKey = 'offline_contacts';

  void setToken(String? token) {
    _token = token;
  }

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers() {
    final h = {HttpHeaders.contentTypeHeader: 'application/json'};
    if (_token != null) h[HttpHeaders.authorizationHeader] = 'Bearer $_token';
    return h;
  }

  Future<List<Reminder>> fetchReminders() async {
    if (!enabled) return [];
    final resp = await http.get(_u('/reminders'), headers: _headers()).timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200) throw HttpException('load reminders failed ${resp.statusCode}');
    final data = jsonDecode(resp.body) as List<dynamic>;
    return data.map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Reminder?> createReminder(Reminder r) async {
    if (!enabled) return null;
    final resp = await http
        .post(_u('/reminders'), headers: _headers(), body: jsonEncode(r.toJson()))
        .timeout(const Duration(seconds: 5));
    if (resp.statusCode != 201) throw HttpException('create reminder failed ${resp.statusCode}');
    return Reminder.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<Reminder?> updateReminder(Reminder r) async {
    if (!enabled || r.id == null) return null;
    final resp = await http
        .put(_u('/reminders/${r.id}'), headers: _headers(), body: jsonEncode(r.toJson()))
        .timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200) throw HttpException('update reminder failed ${resp.statusCode}');
    return Reminder.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<bool> deleteReminder(int id) async {
    if (!enabled) return false;
    final resp = await http.delete(_u('/reminders/$id'), headers: _headers()).timeout(const Duration(seconds: 5));
    return resp.statusCode == 200;
  }

  Future<void> logSOS({String location = '', String contact = '', String note = ''}) async {
    if (!enabled) return;
    await http
        .post(_u('/sos'), headers: _headers(), body: jsonEncode({
          'location': location,
          'contact': contact,
          'note': note,
        }))
        .timeout(const Duration(seconds: 5));
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
      await _saveOfflineContacts(contacts);
      return contacts;
    } catch (_) {
      return _loadOfflineContacts();
    }
  }

  Future<Contact?> createContact(Contact c) async {
    if (_isOffline) {
      final saved = await _addOfflineContact(c);
      return saved;
    }
    final resp = await http
        .post(_u('/contacts'), headers: _headers(), body: jsonEncode(c.toJson()))
        .timeout(const Duration(seconds: 5));
    if (resp.statusCode != 201) throw HttpException('create contact failed ${resp.statusCode}');
    final created = Contact.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    await _appendOfflineContact(created);
    return created;
  }

  Future<Contact?> updateContact(Contact c) async {
    if (_isOffline || c.id == null) {
      final updated = await _updateOfflineContact(c);
      return updated;
    }
    final resp = await http
        .put(_u('/contacts/${c.id}'), headers: _headers(), body: jsonEncode(c.toJson()))
        .timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200) throw HttpException('update contact failed ${resp.statusCode}');
    final updated = Contact.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    await _updateOfflineContact(updated);
    return updated;
  }

  Future<bool> deleteContact(int id) async {
    if (_isOffline) {
      final contacts = await _loadOfflineContacts();
      final removed = contacts.where((c) => c.id != id).toList();
      await _saveOfflineContacts(removed);
      return true;
    }
    final resp = await http.delete(_u('/contacts/$id'), headers: _headers()).timeout(const Duration(seconds: 5));
    final ok = resp.statusCode == 200;
    if (ok) {
      final contacts = await _loadOfflineContacts();
      await _saveOfflineContacts(contacts.where((c) => c.id != id).toList());
    }
    return ok;
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

  Future<Map<String, dynamic>?> bindElder(int elderId) async {
    if (!enabled) return null;
    try {
      final resp = await http.put(_u('/auth/bind-elder?elderId=$elderId'), headers: _headers()).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw HttpException('bind elder failed ${resp.statusCode}');
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
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      print('getElderLocation error: $e');
      return null;
    }
  }

  Future<List<dynamic>?> getElderSosLogs() async {
    if (!enabled) return null;
    try {
      final resp = await http.get(_u('/child/elder/sos-logs'), headers: _headers()).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw HttpException('get elder sos logs failed ${resp.statusCode}');
      return jsonDecode(resp.body) as List<dynamic>;
    } catch (e) {
      print('getElderSosLogs error: $e');
      return null;
    }
  }

  Future<List<dynamic>?> getElderReminders() async {
    if (!enabled) return null;
    try {
      final resp = await http.get(_u('/child/elder/reminders'), headers: _headers()).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw HttpException('get elder reminders failed ${resp.statusCode}');
      return jsonDecode(resp.body) as List<dynamic>;
    } catch (e) {
      print('getElderReminders error: $e');
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
