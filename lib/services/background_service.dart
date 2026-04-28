import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class BackgroundServiceManager {
  static final BackgroundServiceManager _instance = BackgroundServiceManager._internal();
  factory BackgroundServiceManager() => _instance;
  BackgroundServiceManager._internal();

  static const String _channelId = 'guardian_background_service';
  static const String _channelName = '安心儿后台服务';
  
  bool _initialized = false;

  Future<void> initializeService() async {
    if (_initialized) return;
    
    try {
      final service = FlutterBackgroundService();

      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onStart,
          autoStart: false,
          isForegroundMode: true,
          autoStartOnBoot: false,
          foregroundServiceNotificationId: 888,
          notificationChannelId: _channelId,
          initialNotificationTitle: '安心儿',
          initialNotificationContent: '正在后台监测中...',
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
          onBackground: _onIosBackground,
        ),
      );
      _initialized = true;
      debugPrint('后台服务初始化成功');
    } catch (e) {
      debugPrint('后台服务初始化失败: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    service.on('updateConfig').listen((event) async {
      final prefs = await SharedPreferences.getInstance();
      if (event?['fallDetection'] != null) {
        await prefs.setBool('bg_fall_detection', event!['fallDetection']);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    bool fallDetectionEnabled = prefs.getBool('bg_fall_detection') ?? true;

    const double gravityMagnitude = 9.8;
    const double impactThreshold = 4.5;
    const double stillnessThreshold = 5.0;
    const Duration stillnessDuration = Duration(seconds: 2);
    
    List<double> accelerationHistory = [];
    DateTime? impactTime;
    bool waitingForStillness = false;
    bool fallDetected = false;

    final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
    
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'guardian_fall_alert',
      '跌倒告警',
      description: '跌倒检测告警通知',
      importance: Importance.high,
    );
    
    await notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    try {
      accelerometerEventStream().listen((AccelerometerEvent event) async {
        if (!fallDetectionEnabled) return;

        final magnitude = math.sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z
        );
        final deviation = (magnitude - gravityMagnitude).abs();

        accelerationHistory.add(deviation);
        if (accelerationHistory.length > 20) {
          accelerationHistory.removeAt(0);
        }

        if (deviation > impactThreshold && !waitingForStillness && !fallDetected) {
          impactTime = DateTime.now();
          waitingForStillness = true;
          fallDetected = false;
          debugPrint('后台: 检测到撞击! 偏差值: $deviation');
        }

        if (waitingForStillness && impactTime != null) {
          final elapsed = DateTime.now().difference(impactTime!);
          
          if (deviation < stillnessThreshold) {
            if (elapsed >= stillnessDuration && !fallDetected) {
              fallDetected = true;
              waitingForStillness = false;
              debugPrint('后台: 确认跌倒！');
              
              try {
                await notifications.show(
                  999,
                  '跌倒检测告警',
                  '检测到可能的跌倒，请确认老人安全！',
                  NotificationDetails(
                    android: AndroidNotificationDetails(
                      channel.id,
                      channel.name,
                      importance: Importance.max,
                      priority: Priority.high,
                    ),
                  ),
                );
              } catch (e) {
                debugPrint('显示通知失败: $e');
              }
              
              service.invoke('fallDetected', {'timestamp': DateTime.now().toIso8601String()});
            }
          } else if (elapsed > const Duration(seconds: 10)) {
            waitingForStillness = false;
            impactTime = null;
          }
        }
      }, onError: (error) {
        debugPrint('加速度计错误: $error');
      });
    } catch (e) {
      debugPrint('加速度计监听启动失败: $e');
    }

    Timer.periodic(const Duration(minutes: 1), (timer) async {
      final newPrefs = await SharedPreferences.getInstance();
      fallDetectionEnabled = newPrefs.getBool('bg_fall_detection') ?? true;
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }

  Future<void> startService({bool fallDetection = true}) async {
    if (!_initialized) {
      debugPrint('后台服务未初始化，无法启动');
      return;
    }
    
    try {
      final service = FlutterBackgroundService();
      
      final isRunning = await service.isRunning();
      if (isRunning) {
        debugPrint('后台服务已在运行中');
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('bg_fall_detection', fallDetection);
      await service.startService();
      debugPrint('后台服务启动成功');
    } catch (e) {
      debugPrint('启动后台服务失败: $e');
    }
  }

  Future<void> stopService() async {
    try {
      final service = FlutterBackgroundService();
      service.invoke('stopService');
      debugPrint('后台服务已停止');
    } catch (e) {
      debugPrint('停止后台服务失败: $e');
    }
  }

  Future<void> updateFallDetection(bool enabled) async {
    final service = FlutterBackgroundService();
    service.invoke('updateConfig', {'fallDetection': enabled});
  }

  Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return await service.isRunning();
  }
}
