import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AuthResult {
  AuthResult({required this.token, required this.username, required this.displayName, this.id, this.role, this.parentId, this.elderId});
  final String token;
  final String username;
  final String displayName;
  final int? id;
  final String? role;
  final int? parentId;
  final String? elderId;
}

class AuthService {
  AuthService({String? baseUrl})
      : baseUrl = baseUrl ?? const String.fromEnvironment('BACKEND_BASE_URL', defaultValue: 'http://10.0.2.2:3001');

  final String baseUrl;
  String? _token;
  String? get token => _token;

  static const _offlineToken = 'offline-token';
  static const _offlineUserKey = 'offline_username';
  static const _offlinePassKey = 'offline_password';
  static const _offlineDisplayKey = 'offline_display';

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers() {
    final h = {HttpHeaders.contentTypeHeader: 'application/json'};
    if (_token != null) h[HttpHeaders.authorizationHeader] = 'Bearer $_token';
    return h;
  }

  Future<AuthResult> register(String username, String password, String displayName, [String role = 'elder', int? parentId]) async {
    try {
      final resp = await http
          .post(
            _u('/auth/register'),
            headers: _headers(),
            body: jsonEncode({'username': username, 'password': password, 'displayName': displayName, 'role': role, 'parentId': parentId}),
          )
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode != 201) {
        throw HttpException('register failed ${resp.statusCode}');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      _token = data['token'] as String?;
      await _persistToken();
      final user = data['user'] as Map<String, dynamic>? ?? {};
      if (kDebugMode) {
        print('Backend response: $data');
        print('User data: $user');
        print('Elder ID from backend: ${user['elderId']}');
      }
      return AuthResult(
        token: _token!,
        username: user['username'] as String? ?? username,
        displayName: user['displayName'] as String? ?? '',
        id: user['id'] as int?,
        role: user['role'] as String?,
        parentId: user['parentId'] as int?,
        elderId: user['elderId'] as String?,
      );
    } catch (_) {
      // 无后端时降级为本地注册
      return _registerOffline(username, password, displayName);
    }
  }

  Future<AuthResult> login(String username, String password) async {
    try {
      final resp = await http
          .post(
            _u('/auth/login'),
            headers: _headers(),
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) {
        throw HttpException('login failed ${resp.statusCode}');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      _token = data['token'] as String?;
      await _persistToken();
      final user = data['user'] as Map<String, dynamic>? ?? {};
      if (kDebugMode) {
        print('Backend response: $data');
        print('User data: $user');
        print('Elder ID from backend: ${user['elderId']}');
      }
      return AuthResult(
        token: _token!,
        username: user['username'] as String? ?? username,
        displayName: user['displayName'] as String? ?? '',
        id: user['id'] as int?,
        role: user['role'] as String?,
        parentId: user['parentId'] as int?,
        elderId: user['elderId'] as String?,
      );
    } catch (_) {
      return _loginOffline(username, password);
    }
  }

  Future<AuthResult?> me() async {
    if (_token == null) return null;
    if (_token == _offlineToken) {
      final offline = await _loadOfflineAccount();
      if (offline != null) {
        return AuthResult(token: _offlineToken, username: offline['username']!, displayName: offline['display']!, id: 1, role: 'elder', elderId: '123456');
      }
    }
    try {
      final resp = await http.get(_u('/auth/me'), headers: _headers()).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>? ?? {};
      return AuthResult(
        token: _token!,
        username: user['username'] as String? ?? '',
        displayName: user['displayName'] as String? ?? '',
        id: user['id'] as int?,
        role: user['role'] as String?,
        parentId: user['parentId'] as int?,
        elderId: user['elderId'] as String?,
      );
    } catch (_) {
      // 离线时返回本地用户
      final offline = await _loadOfflineAccount();
      if (offline != null) {
        return AuthResult(token: _token!, username: offline['username']!, displayName: offline['display']!, id: 1, role: 'elder', elderId: '123456');
      }
      return null;
    }
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_username');
    await prefs.remove('auth_display');
    await prefs.remove(_offlineUserKey);
    await prefs.remove(_offlinePassKey);
    await prefs.remove(_offlineDisplayKey);
  }

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> _persistToken() async {
    if (_token == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', _token!);
  }

  Future<Map<String, String>?> _loadOfflineAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final u = prefs.getString(_offlineUserKey);
    final p = prefs.getString(_offlinePassKey);
    final d = prefs.getString(_offlineDisplayKey);
    if (u == null || p == null || d == null) return null;
    return {'username': u, 'password': p, 'display': d};
  }

  Future<void> _persistOfflineAccount(String username, String password, String display) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_offlineUserKey, username);
    await prefs.setString(_offlinePassKey, password);
    await prefs.setString(_offlineDisplayKey, display);
  }

  Future<AuthResult> _loginOffline(String username, String password) async {
    final stored = await _loadOfflineAccount();
    final defaultUser = {'username': 'elder', 'password': '123456', 'display': '离线体验账号'};
    final candidate = stored ?? defaultUser;
    if (username == candidate['username'] && password == candidate['password']) {
      _token = _offlineToken;
      await _persistToken();
      await _persistOfflineAccount(candidate['username']!, candidate['password']!, candidate['display']!);
      return AuthResult(token: _offlineToken, username: candidate['username']!, displayName: candidate['display']!, id: 1, role: 'elder', elderId: '123456');
    }
    throw HttpException('offline login failed');
  }

  Future<AuthResult> _registerOffline(String username, String password, String displayName) async {
    final display = displayName.isEmpty ? username : displayName;
    _token = _offlineToken;
    await _persistOfflineAccount(username, password, display);
    await _persistToken();
    return AuthResult(token: _offlineToken, username: username, displayName: display, id: 1, role: 'elder', elderId: '123456');
  }
}
