import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
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
import 'services/notification_service.dart';
import 'services/fall_detection_service.dart';
import 'services/local_cache_service.dart';
import 'services/sync_service.dart';
import 'services/reminder_scheduler_service.dart';
import 'services/background_service.dart';

void main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
    };

    LocalCacheService? cache;
    try {
      cache = await LocalCacheService.getInstance();
    } catch (e) {
      debugPrint('LocalCacheService初始化失败: $e');
    }
    
    final sync = SyncService();
    
    runApp(GuardianApp(cache: cache, sync: sync));
  }, (Object error, StackTrace stack) {
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stack');
  });
}

class GuardianApp extends StatefulWidget {
  final LocalCacheService? cache;
  final SyncService sync;

  const GuardianApp({super.key, this.cache, required this.sync});

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
  final FallDetectionService fallDetectionService = FallDetectionService();
  final NotificationService notificationService = NotificationService();
  final ReminderSchedulerService reminderScheduler = ReminderSchedulerService();
  final BackgroundServiceManager backgroundService = BackgroundServiceManager();
  final bool authRequired = const bool.fromEnvironment('REQUIRE_AUTH', defaultValue: true);
  int _tabIndex = 0;
  int? _emergencyContactId1;
  int? _emergencyContactId2;
  String emergencyContact1 = '未设置紧急联系人1';
  String emergencyContact2 = '未设置紧急联系人2';
  String currentLocation = '未获取';
  double? _currentLatitude;
  double? _currentLongitude;
  DateTime? lastLocationUpdate;
  bool locationSharing = true;
  bool fallDetection = true;
  bool heartRateMonitoring = true;
  DateTime? lastHelpTime;
  bool isAuthed = false;
  String? currentUser;
  int? currentUserId;
  String? currentUserRole;
  String? currentElderId;
  String? elderName;
  bool _locating = false;

  final List<Reminder> reminders = [
    Reminder(title: '早上8:00 吃降压药', time: const TimeOfDay(hour: 8, minute: 0), repeatType: RepeatType.daily),
    Reminder(title: '晚上20:00 测血压', time: const TimeOfDay(hour: 20, minute: 0), repeatType: RepeatType.once),
  ];

  List<Contact> family = [];

  Contact? get _emergencyContact1 {
    if (_emergencyContactId1 == null) return null;
    try {
      return family.firstWhere((c) => c.id == _emergencyContactId1);
    } catch (_) {
      return null;
    }
  }

  Contact? get _emergencyContact2 {
    if (_emergencyContactId2 == null) return null;
    try {
      return family.firstWhere((c) => c.id == _emergencyContactId2);
    } catch (_) {
      return null;
    }
  }

  String? get _emergencyContactPhone1 {
    return _emergencyContact1?.phone;
  }

  String? get _emergencyContactPhone2 {
    return _emergencyContact2?.phone;
  }

  void _setEmergencyContact1(Contact contact) {
    setState(() {
      if (_emergencyContactId2 == contact.id) {
        _emergencyContactId2 = null;
        emergencyContact2 = '未设置紧急联系人2';
      }
      _emergencyContactId1 = contact.id;
      emergencyContact1 = '${contact.name} ${contact.phone}';
    });
  }

  void _setEmergencyContact2(Contact contact) {
    setState(() {
      if (_emergencyContactId1 == contact.id) {
        _emergencyContactId1 = null;
        emergencyContact1 = '未设置紧急联系人1';
      }
      _emergencyContactId2 = contact.id;
      emergencyContact2 = '${contact.name} ${contact.phone}';
    });
  }

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    await _initializeServices();
    await _bootstrapAuth();
    await _loadRemindersFromBackend();
  }

  Future<void> _initializeServices() async {
    try {
      await notificationService.initialize();
    } catch (e) {
      debugPrint('通知服务初始化失败: $e');
    }
    
    try {
      await backgroundService.initializeService();
    } catch (e) {
      debugPrint('后台服务初始化失败: $e');
    }
    
    final cache = widget.cache;
    if (cache != null) {
      api.setCache(cache);
      api.setSync(widget.sync);
      widget.sync.initialize(api, authService, cache);
      reminderScheduler.initialize(api, cache);
    }
    
    try {
      await reminderScheduler.loadReminders(reminders);
      debugPrint('已加载 ${reminders.length} 个本地提醒到调度器');
    } catch (e) {
      debugPrint('加载提醒失败: $e');
    }
  }
  
  Future<void> _startBackgroundServiceIfNeeded() async {
    if (fallDetection && currentUserRole == 'elder') {
      try {
        await backgroundService.startService(fallDetection: true);
        debugPrint('后台跌倒检测服务已启动');
      } catch (e) {
        debugPrint('启动后台服务失败: $e');
      }
    }
  }

  void _triggerSOS(BuildContext context) async {
    final now = DateTime.now();
    setState(() => lastHelpTime = now);

    if (currentLocation == '未获取') {
      await _refreshLocation();
    }

    if (currentLocation != '未获取') {
      await api.updateLocation(currentLocation, latitude: _currentLatitude, longitude: _currentLongitude);
    }

    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('正在为您呼叫紧急联系人1，并发送位置... (${_formatTime(now)})'),
        duration: const Duration(seconds: 3),
      ),
    );
    api.logSOS(location: currentLocation, contact: emergencyContact1).catchError((_) {});
  }

  void _callEmergencyContact(BuildContext context) {
    if (_emergencyContactPhone1 != null && _emergencyContactPhone1!.isNotEmpty) {
      _makePhoneCall(context, _emergencyContactPhone1!);
    } else {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('请先设置紧急联系人1电话'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _callEmergencyContact2(BuildContext context) {
    if (_emergencyContactPhone2 != null && _emergencyContactPhone2!.isNotEmpty) {
      _makePhoneCall(context, _emergencyContactPhone2!);
    } else {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('请先设置紧急联系人2电话'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      final launched = await launchUrl(
        phoneUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('无法打开拨号界面，请手动拨打: $phoneNumber'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('拨号失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _toggleReminder(Reminder item) {
    setState(() => item.completed = !item.completed);
    api.updateReminder(item).catchError((_) => null);
  }

  void _addReminder(Reminder item) {
    setState(() => reminders.add(item));
    reminderScheduler.addReminder(item);
    api.createReminder(item).then((saved) {
      if (saved != null && mounted) {
        setState(() {
          item.id = saved.id;
          item.completed = saved.completed;
        });
      }
    }).catchError((_) {});
  }

  void _removeReminder(Reminder item) {
    setState(() => reminders.remove(item));
    reminderScheduler.removeReminder(item);
    if (item.id != null) {
      api.deleteReminder(item.id!).catchError((_) => false);
    }
  }

  void _editReminder(Reminder item) {
    final index = reminders.indexWhere((r) => r.id == item.id);
    if (index != -1) {
      setState(() {
        reminders[index] = item;
      });
      reminderScheduler.updateReminder(item);
      api.updateReminder(item).catchError((_) => null);
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
        _currentLatitude = res.latitude;
        _currentLongitude = res.longitude;
        lastLocationUpdate = DateTime.now();
      });
      await api.updateLocation(res.display, latitude: res.latitude, longitude: res.longitude);
    } catch (e) {
      _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('定位失败：$e')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String _formatTime(DateTime time) {
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  Future<void> _bootstrapAuth() async {
    await authService.loadFromStorage();
    api.setToken(authService.token);
    
    final cache = widget.cache;
    if (cache != null) {
      final cachedToken = cache.getUserToken();
      if (cachedToken != null && authService.token == null) {
        api.setToken(cachedToken);
      }
    }
    
    final me = await authService.me();
    if (me != null && mounted) {
      if (cache != null) {
        await cache.saveUserToken(me.token);
        await cache.saveUserData({
          'id': me.id,
          'username': me.username,
          'displayName': me.displayName,
          'role': me.role,
          'elderId': me.elderId,
        });
      }
      
      _onAuthed(me.token, me.username, me.displayName, refreshData: false, userId: me.id, role: me.role, elderId: me.elderId);
      _loadRemindersFromBackend();
      _loadFamilyFromBackend();
      if (me.role == 'elder') {
        _refreshLocation();
      }
      
      if (widget.sync.isOnline) {
        widget.sync.syncAll();
      }
    } else if (!authRequired) {
      setState(() => isAuthed = false);
    } else {
      if (cache != null) {
        final cachedUser = cache.getUserData();
        if (cachedUser != null) {
          debugPrint('使用缓存的用户数据');
        }
      }
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
    if (role == 'child' && parentId != null) {
      _loadElderInfo(parentId);
    }
    if (role == 'elder') {
      _refreshLocation();
      _startBackgroundServiceIfNeeded();
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
    }
  }

  Future<void> _logout() async {
    await authService.logout();
    api.setToken(null);
    if (widget.cache != null) {
      await widget.cache!.clearAll();
    }
    setState(() {
      isAuthed = false;
      currentUser = null;
      currentUserId = null;
      currentUserRole = null;
      currentElderId = null;
      elderName = null;
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
                  if (elderName == null)
                    ListTile(
                      leading: const Icon(Icons.family_restroom),
                      title: const Text('绑定老人ID'),
                      subtitle: const Text('未绑定老人ID'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _showBindElderDialog(ctx);
                      },
                    ),
                  if (elderName != null) ...[
                    ListTile(
                      leading: const Icon(Icons.family_restroom),
                      title: const Text('已绑定老人'),
                      subtitle: Text('老人: $elderName'),
                    ),
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
          if (family.isNotEmpty && _emergencyContactId1 == null) {
            final first = family.first;
            _emergencyContactId1 = first.id;
            emergencyContact1 = '${first.name} ${first.phone}';
          }
        });
      }
    } catch (_) {
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
        await reminderScheduler.loadReminders(fetched);
        debugPrint('从后端加载了 ${fetched.length} 个提醒');
      }
    } catch (e) {
      debugPrint('从后端加载提醒失败: $e');
      await reminderScheduler.loadReminders(reminders);
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
                final result = await api.bindElder(elderId);
                if (result != null) {
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
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: '安心儿-老人呵护助手',
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
        textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: 1.05),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text(isAuthed 
              ? currentUserRole == 'child' 
                ? '安心儿 · ${elderName ?? '老人'}的监护人' 
                : '安心儿 · ${currentUser ?? '已登录'}' 
              : '安心儿 · 安全守护'),
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
                          contact1: emergencyContact1,
                          contact2: emergencyContact2,
                          contactPhone1: _emergencyContactPhone1,
                          contactPhone2: _emergencyContactPhone2,
                          onSOS: () => _triggerSOS(context),
                          locationSharing: locationSharing,
                          onLocationToggle: (v) => setState(() => locationSharing = v),
                          location: currentLocation,
                          latitude: _currentLatitude,
                          longitude: _currentLongitude,
                          isLocating: _locating,
                          onLocationRefresh: _refreshLocation,
                          lastLocationUpdate: lastLocationUpdate,
                          onCallEmergency1: () => _callEmergencyContact(context),
                          onCallEmergency2: () => _callEmergencyContact2(context),
                        ),
                        ReminderPage(
                          reminders: reminders,
                          onToggle: _toggleReminder,
                          onAdd: _addReminder,
                          onDelete: _removeReminder,
                          onEdit: _editReminder,
                        ),
                        SafetyPage(
                          fallDetection: fallDetection,
                          onFallToggle: (v) async {
                            setState(() => fallDetection = v);
                            if (v) {
                              await backgroundService.startService(fallDetection: true);
                            } else {
                              await backgroundService.stopService();
                            }
                          },
                          heartRateMonitoring: heartRateMonitoring,
                          onHeartRateToggle: (v) => setState(() => heartRateMonitoring = v),
                          heartRateService: heartRateService,
                          fallDetectionService: fallDetectionService,
                          onFallDetected: () => _triggerSOS(context),
                        ),
                        FamilyPage(
                          api: api,
                          isAuthed: isAuthed,
                          contacts: family,
                          emergencyContactId1: _emergencyContactId1,
                          emergencyContactId2: _emergencyContactId2,
                          onSetEmergency1: _setEmergencyContact1,
                          onSetEmergency2: _setEmergencyContact2,
                          onContactsChanged: (contacts) {
                            setState(() {
                              family = contacts;
                            });
                          },
                        ),
                      ],
                    ),
        ),
        bottomNavigationBar: (!isAuthed || currentUserRole == 'child') ? null : NavigationBar(
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
