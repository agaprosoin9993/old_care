import 'package:flutter/material.dart';
import 'features/reminders/reminder_page.dart';
import 'features/safety/safety_page.dart';
import 'features/sos/sos_page.dart';
import 'features/auth/auth_page.dart';
import 'features/family/family_page.dart';
import 'models/reminder.dart';
import 'models/contact.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';

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
  final bool authRequired = const bool.fromEnvironment('REQUIRE_AUTH', defaultValue: false);// 是否需要认证
  int _tabIndex = 0;
  String emergencyContact = '儿子 138-0000-0000';
  String currentLocation = '未获取';
  DateTime? lastLocationUpdate;
  bool locationSharing = true;
  bool fallDetection = true;
  bool geoFenceEnabled = true;
  double geoFenceRadius = 500; // 米
  DateTime? lastHelpTime;
  bool isAuthed = false;// 是否已认证
  String? currentUser;
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
      _onAuthed(me.token, me.username, me.displayName, refreshData: false);
      _loadRemindersFromBackend();
      _loadFamilyFromBackend();
    } else if (!authRequired) {
      setState(() => isAuthed = false);
    }
  }

  void _onAuthed(String token, String username, String displayName, {bool refreshData = true}) {
    api.setToken(token);
    setState(() {
      isAuthed = true;
      currentUser = displayName.isNotEmpty ? displayName : username;
    });
    if (refreshData) {
      _loadRemindersFromBackend();
      _loadFamilyFromBackend();
    }
  }

  Future<void> _logout() async {
    await authService.logout();
    api.setToken(null);
    setState(() {
      isAuthed = false;
      currentUser = null;
    });
  }

  void _openAccountSheet() {
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
                      _onAuthed(r.token, r.username, r.displayName);
                    },
                    onCancel: authRequired ? null : () => Navigator.of(ctx).pop(),
                  ),
                ));
              },
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,// 导航键，用于在全局访问导航器
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: '老友伴 · 老人呵护助手',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
        textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: 1.05),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text(isAuthed ? '老友伴 · ${currentUser ?? '已登录'}' : '老友伴 · 安全守护'),
          actions: [
            IconButton(
              onPressed: _openAccountSheet,
              icon: const Icon(Icons.person),
              tooltip: isAuthed ? '切换/退出登录' : '登录/注册',
            )
          ],
        ),
        body: SafeArea(
          child: authRequired && !isAuthed
              ? AuthPage(//登录/注册页面
                  onAuthed: (r) => _onAuthed(r.token, r.username, r.displayName),
                  onCancel: null,
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
                      geoFenceEnabled: geoFenceEnabled,
                      onGeoFenceToggle: (v) => setState(() => geoFenceEnabled = v),
                      geoFenceRadius: geoFenceRadius,
                      onGeoFenceRadius: (v) => setState(() => geoFenceRadius = v),
                      location: currentLocation,
                    ),
                    FamilyPage(api: api, isAuthed: isAuthed),
                  ],
                ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.sos), label: '求助'),
            NavigationDestination(icon: Icon(Icons.alarm), label: '用药提醒'),
            NavigationDestination(icon: Icon(Icons.shield), label: '守护设置'),
            NavigationDestination(icon: Icon(Icons.family_restroom), label: '家属'),
          ],
          onDestinationSelected: (i) => setState(() => _tabIndex = i),// 切换导航栏项
        ),
      ),
    );
  }
}
