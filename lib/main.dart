import 'package:flutter/material.dart';
import 'features/reminders/reminder_page.dart';
import 'features/safety/safety_page.dart';
import 'features/sos/sos_page.dart';
import 'features/auth/auth_page.dart';
import 'features/family/family_page.dart';
import 'features/child/child_home_page.dart';
import 'models/reminder.dart';
import 'models/contact.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'services/heart_rate_service.dart';

void main() {
  runApp(const GuardianApp());
}

class GuardianApp extends StatefulWidget {
  const GuardianApp({super.key});

  @override
  State<GuardianApp> createState() => _GuardianAppState();
}

class _GuardianAppState extends State<GuardianApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final ApiClient api = ApiClient();
  final AuthService authService = AuthService();
  final LocationService locationService = LocationService();
  final HeartRateService heartRateService = HeartRateService();
  final bool authRequired = const bool.fromEnvironment('REQUIRE_AUTH', defaultValue: false);// 是否需要认证
  int _tabIndex = 0;
  String emergencyContact = '儿子 138-0000-0000';
  String currentLocation = '未获取';
  DateTime? lastLocationUpdate;
  bool locationSharing = true;
  bool fallDetection = true;
  bool heartRateMonitoring = true;
  DateTime? lastHelpTime;
  bool isAuthed = false;// 是否已认证
  String? currentUser;
  int? currentUserId;
  String? currentUserRole;
  String? currentElderId;
  String? elderName;
  String? mapPreviewUrl;
  bool _locating = false;

  final List<Reminder> reminders = [
    Reminder(title: '早上8:00 吃降压药', time: const TimeOfDay(hour: 8, minute: 0), repeating: true),
    Reminder(title: '晚上20:00 测血压', time: const TimeOfDay(hour: 20, minute: 0), repeating: false),
  ];

  List<Contact> family = [];

  @override
  void initState() {
    super.initState();
    _bootstrapAuth();
    _loadRemindersFromBackend();
  }

  void _triggerSOS(BuildContext context) {
    final now = DateTime.now();
    setState(() => lastHelpTime = now);
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('正在为您呼叫紧急联系人，并发送位置... (${_formatTime(now)})'),
        duration: const Duration(seconds: 3),
      ),
    );
    api.logSOS(location: currentLocation, contact: emergencyContact).catchError((_) {});
  }

  void _toggleReminder(Reminder item) {
    setState(() => item.completed = !item.completed);
    api.updateReminder(item).catchError((_) => null);
  }

  void _addReminder(Reminder item) {
    setState(() => reminders.add(item));
    api.createReminder(item).then((saved) {
      if (saved != null && mounted) {
        setState(() {
          item.id = saved.id;
          item.completed = saved.completed;
          item.repeating = saved.repeating;
        });
      }
    }).catchError((_) {});
  }

  void _removeReminder(Reminder item) {
    setState(() => reminders.remove(item));
    if (item.id != null) {
      api.deleteReminder(item.id!).catchError((_) => false);
    }
  }

  Future<void> _refreshLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final res = await locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        currentLocation = res.display;
        mapPreviewUrl = res.mapPreviewUrl;
        lastLocationUpdate = DateTime.now();
      });
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('定位失败：$e')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _updateContact(String value) {
    setState(() => emergencyContact = value);
  }

  String _formatTime(DateTime time) {
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  Future<void> _bootstrapAuth() async {
    await authService.loadFromStorage();
    api.setToken(authService.token);
    final me = await authService.me();
    if (me != null && mounted) {
      _onAuthed(me.token, me.username, me.displayName, refreshData: false, userId: me.id, role: me.role, elderId: me.elderId);
      _loadRemindersFromBackend();
      _loadFamilyFromBackend();
    } else if (!authRequired) {
      setState(() => isAuthed = false);
    }
  }

  void _onAuthed(String token, String username, String displayName, {bool refreshData = true, int? userId, String? role, String? elderId, int? parentId}) {
    api.setToken(token);
    setState(() {
      isAuthed = true;
      currentUser = displayName.isNotEmpty ? displayName : username;
      currentUserId = userId;
      currentUserRole = role;
      currentElderId = elderId;
    });
    if (refreshData) {
      _loadRemindersFromBackend();
      _loadFamilyFromBackend();
    }
    // 如果是子女角色，获取对应老人的信息
    if (role == 'child' && parentId != null) {
      _loadElderInfo(parentId);
    }
  }

  Future<void> _loadElderInfo(int elderId) async {
    try {
      final elderInfo = await api.getUserInfo(elderId);
      if (elderInfo != null && mounted) {
        setState(() {
          elderName = elderInfo['displayName'] as String? ?? elderInfo['username'] as String? ?? '老人';
        });
      }
    } catch (_) {
      // 忽略错误
    }
  }

  Future<void> _logout() async {
    await authService.logout();
    api.setToken(null);
    setState(() {
      isAuthed = false;
      currentUser = null;
      currentUserId = null;
      currentUserRole = null;
      currentElderId = null;
      elderName = null;
    });
  }

  void _openAccountSheet() {//打开账户弹窗
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;

    showModalBottomSheet(
      context: ctx,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(isAuthed ? '切换账户' : '登录 / 注册'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => AuthPage(
                    onAuthed: (r) {
                      Navigator.of(ctx).pop();
                      _onAuthed(r.token, r.username, r.displayName, userId: r.id, role: r.role, elderId: r.elderId, parentId: r.parentId);
                    },
                    onCancel: authRequired ? null : () => Navigator.of(ctx).pop(),
                  ),
                ));
              },
            ),
            if (isAuthed && currentElderId != null && currentUserRole == 'elder')
              ListTile(
                leading: const Icon(Icons.perm_identity),
                title: const Text('查看账号ID'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDialog(
                    context: ctx,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('您的账号ID'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$currentElderId',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '请将此ID告诉子女，用于注册子女账号',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            if (isAuthed && currentUserRole == 'child')
              Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.family_restroom),
                    title: const Text('绑定老人ID'),
                    subtitle: elderName != null 
                        ? Text('已绑定: $elderName') 
                        : const Text('未绑定老人ID'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showBindElderDialog(ctx);
                    },
                  ),
                  if (elderName != null)
                    ListTile(
                      leading: const Icon(Icons.remove_circle),
                      title: const Text('解绑老人ID'),
                      subtitle: const Text('解除与当前老人的绑定'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _showUnbindConfirmDialog(ctx);
                      },
                    ),
                ],
              ),
            if (isAuthed)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('退出登录'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _logout();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadFamilyFromBackend() async {
    try {
      final fetched = await api.fetchContacts();
      if (mounted) {
        setState(() {
          family = fetched;
          if (family.isNotEmpty) {
            final first = family.first;
            emergencyContact = '${first.name} ${first.phone}';
          }
        });
      }
    } catch (_) {
      // ignore offline errors
    }
  }

  Future<void> _loadRemindersFromBackend() async {
    try {
      final fetched = await api.fetchReminders();
      if (fetched.isNotEmpty && mounted) {
        setState(() {
          reminders
            ..clear()
            ..addAll(fetched);
        });
      }
    } catch (_) {
      // 离线或后端未启动时忽略，保留本地示例数据
    }
  }

  void _showBindElderDialog(BuildContext context) {
    final TextEditingController _elderIdController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('绑定老人ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入老人的账号ID，用于查看老人状态'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _elderIdController,
              decoration: const InputDecoration(labelText: '老人账号ID'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return '请输入老人账号ID';
                if (v.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(v)) {
                  return '老人ID必须为六位数字';
                }
                return null;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final elderId = _elderIdController.text.trim();
              if (elderId.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(elderId)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('老人ID必须为六位数字')),
                );
                return;
              }
              try {
                // 调用后端API来绑定老人ID
                final result = await api.bindElder(int.parse(elderId));
                if (result != null) {
                  // 绑定成功，获取老人信息
                  final parentId = result['data']['parentId'] as int?;
                  if (parentId != null) {
                    await _loadElderInfo(parentId);
                  }
                  Navigator.of(dialogCtx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('绑定成功')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('绑定失败: $e')),
                );
              }
            },
            child: const Text('绑定'),
          ),
        ],
      ),
    );
  }

  void _showUnbindConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('确认解绑'),
        content: const Text('确定要解除与当前老人的绑定吗？解绑后将无法查看老人状态。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final result = await api.unbindElder();
                if (result != null) {
                  setState(() {
                    elderName = null;
                    currentElderId = null;
                  });
                  Navigator.of(dialogCtx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('解绑成功')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('解绑失败: $e')),
                );
              }
            },
            child: const Text('确认解绑'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,// 导航键，用于在全局访问导航器
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: '安心儿-老人呵护助手',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
        textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: 1.05),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text(isAuthed 
              ? currentUserRole == 'child' 
                ? '安心儿 · ${currentUser ?? '已登录'} (${elderName ?? '老人'}的监护人)' 
                : '安心儿 · ${currentUser ?? '已登录'}' 
              : '安心儿 · 安全守护'),
          actions: [
            IconButton(
              onPressed: _openAccountSheet,
              icon: const Icon(Icons.person),
              tooltip: isAuthed ? '切换/退出登录' : '登录/注册',//提示框
            )
          ],
        ),
        body: SafeArea(
          child: authRequired && !isAuthed
              ? AuthPage(
                  onAuthed: (r) => _onAuthed(r.token, r.username, r.displayName, userId: r.id, role: r.role, elderId: r.elderId, parentId: r.parentId),
                  onCancel: null,
                )
              : currentUserRole == 'child'
                  ? ChildHomePage(
                      api: api,
                      elderName: elderName,
                      onUnbind: () => _showUnbindConfirmDialog(_navigatorKey.currentContext!),
                    )
                  : IndexedStack(
                      index: _tabIndex,
                      children: [
                        SosPage(
                          lastHelpTime: lastHelpTime,
                          contact: emergencyContact,
                          onSOS: () => _triggerSOS(context),
                          onContactEdited: _updateContact,
                          locationSharing: locationSharing,
                          onLocationToggle: (v) => setState(() => locationSharing = v),
                          location: currentLocation,
                          mapPreviewUrl: mapPreviewUrl,
                          isLocating: _locating,
                          onLocationRefresh: _refreshLocation,
                          lastLocationUpdate: lastLocationUpdate,
                        ),
                        ReminderPage(
                          reminders: reminders,
                          onToggle: _toggleReminder,
                          onAdd: _addReminder,
                          onDelete: _removeReminder,
                        ),
                        SafetyPage(
                          fallDetection: fallDetection,
                          onFallToggle: (v) => setState(() => fallDetection = v),
                          heartRateMonitoring: heartRateMonitoring,
                          onHeartRateToggle: (v) => setState(() => heartRateMonitoring = v),
                          heartRateService: heartRateService,
                        ),
                        FamilyPage(api: api, isAuthed: isAuthed),
                      ],
                    ),
        ),
        bottomNavigationBar: currentUserRole == 'child' ? null : NavigationBar(
          selectedIndex: _tabIndex,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.sos), label: '求助'),
            NavigationDestination(icon: Icon(Icons.alarm), label: '用药提醒'),
            NavigationDestination(icon: Icon(Icons.shield), label: '守护设置'),
            NavigationDestination(icon: Icon(Icons.family_restroom), label: '家属'),
          ],
          onDestinationSelected: (i) => setState(() => _tabIndex = i),
        ),
      ),
    );
  }
}
