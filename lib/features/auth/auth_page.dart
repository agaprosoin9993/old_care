import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.onAuthed, this.onCancel});

  final void Function(AuthResult result) onAuthed;
  final VoidCallback? onCancel;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final AuthService _auth = AuthService();
  final _loginForm = GlobalKey<FormState>();
  final _registerForm = GlobalKey<FormState>();
  String _loginUser = '';
  String _loginPass = '';
  String _regUser = '';
  String _regPass = '';
  String _regName = '';
  bool _loading = false;

  Future<void> _doLogin() async {
    if (!(_loginForm.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final res = await _auth.login(_loginUser, _loginPass);
      widget.onAuthed(res);
    } catch (e) {
      _showError('登录失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doRegister() async {
    if (!(_registerForm.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final res = await _auth.register(_regUser, _regPass, _regName);
      widget.onAuthed(res);
    } catch (e) {
      _showError('注册失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账户登录 / 注册'),
        actions: [
          if (widget.onCancel != null)
            TextButton(
              onPressed: _loading ? null : widget.onCancel,
              child: const Text('跳过', style: TextStyle(color: Colors.white)),
            )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(tabs: [Tab(text: '登录'), Tab(text: '注册')]),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildLoginForm(),
                                _buildRegisterForm(),
                              ],
                            ),
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

  Widget _buildLoginForm() {
    return Form(
      key: _loginForm,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Card(
            color: Colors.grey.shade100,
            elevation: 0,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('无后端模式可直接使用内置账号：\n用户名 elder 密码 123456'),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(labelText: '用户名'),
            onChanged: (v) => _loginUser = v.trim(),
            validator: (v) => (v == null || v.isEmpty) ? '请输入用户名' : null,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: '密码'),
            obscureText: true,
            onChanged: (v) => _loginPass = v,
            validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _doLogin,
            icon: const Icon(Icons.login),
            label: const Text('登录'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerForm,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          TextFormField(
            decoration: const InputDecoration(labelText: '用户名'),
            onChanged: (v) => _regUser = v.trim(),
            validator: (v) => (v == null || v.isEmpty) ? '请输入用户名' : null,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: '密码'),
            obscureText: true,
            onChanged: (v) => _regPass = v,
            validator: (v) => (v == null || v.length < 4) ? '至少4位密码' : null,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: '昵称/称呼'),
            onChanged: (v) => _regName = v,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _doRegister,
            icon: const Icon(Icons.app_registration),
            label: const Text('注册并登录'),
          ),
        ],
      ),
    );
  }
}
