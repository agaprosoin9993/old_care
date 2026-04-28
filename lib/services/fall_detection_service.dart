import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class FallDetectionService {
  static final FallDetectionService _instance = FallDetectionService._internal();
  factory FallDetectionService() => _instance;
  FallDetectionService._internal();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  bool _isMonitoring = false;
  bool _fallDetected = false;
  DateTime? _lastFallTime;
  
  bool _impactDetected = false;
  DateTime? _impactTime;
  Timer? _stillnessTimer;
  
  final List<double> _accelerometerHistory = [];
  final List<double> _accelerometerMagnitudeHistory = [];

  static const int _historySize = 100;
  static const double _impactThreshold = 4.5;
  static const double _stillnessThreshold = 5.0;
  static const int _stillnessCheckCount = 10;
  static const Duration _stillnessDuration = Duration(seconds: 2);
  static const Duration _impactWindow = Duration(seconds: 10);
  static const double _gravityMagnitude = 9.8;

  Function()? onFallDetected;

  bool get isMonitoring => _isMonitoring;
  bool get fallDetected => _fallDetected;
  DateTime? get lastFallTime => _lastFallTime;
  bool get impactDetected => _impactDetected;

  Future<bool> startMonitoring() async {
    if (_isMonitoring) return true;
    if (kIsWeb) {
      debugPrint('Fall detection not supported on web');
      return false;
    }

    try {
      _accelerometerSubscription = accelerometerEventStream().listen(
        _onAccelerometerEvent,
        onError: (error) {
          debugPrint('Accelerometer error: $error');
        },
      );

      _isMonitoring = true;
      _fallDetected = false;
      _impactDetected = false;
      _impactTime = null;
      _stillnessTimer?.cancel();
      _stillnessTimer = null;
      debugPrint('跌倒检测已启动，撞击阈值: $_impactThreshold');
      return true;
    } catch (e) {
      debugPrint('Failed to start fall detection: $e');
      return false;
    }
  }

  void stopMonitoring() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _stillnessTimer?.cancel();
    _stillnessTimer = null;
    _isMonitoring = false;
    _impactDetected = false;
    _accelerometerHistory.clear();
    _accelerometerMagnitudeHistory.clear();
    debugPrint('跌倒检测已停止');
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final deviation = (magnitude - _gravityMagnitude).abs();
    
    _accelerometerHistory.add(deviation);
    _accelerometerMagnitudeHistory.add(magnitude);
    
    if (_accelerometerHistory.length > _historySize) {
      _accelerometerHistory.removeAt(0);
    }
    if (_accelerometerMagnitudeHistory.length > _historySize) {
      _accelerometerMagnitudeHistory.removeAt(0);
    }

    _checkForFall();
  }

  void _checkForFall() {
    if (_accelerometerHistory.length < 10) return;

    final now = DateTime.now();
    
    if (_impactDetected) {
      _checkStillness(now);
      return;
    }

    final recentDeviation = _accelerometerHistory.sublist(_accelerometerHistory.length - 5);
    final maxDeviation = recentDeviation.reduce((a, b) => a > b ? a : b);

    if (maxDeviation > _impactThreshold) {
      debugPrint('检测到撞击! 偏差值: $maxDeviation (阈值: $_impactThreshold)');
      _impactDetected = true;
      _impactTime = now;
      _stillnessTimer?.cancel();
    }
  }

  void _checkStillness(DateTime now) {
    if (_impactTime == null) return;
    
    if (now.difference(_impactTime!) > _impactWindow) {
      debugPrint('撞击窗口已过期，重置检测');
      _resetImpactDetection();
      return;
    }

    if (_accelerometerHistory.length < _stillnessCheckCount) return;

    final recentDeviation = _accelerometerHistory.sublist(
      _accelerometerHistory.length - _stillnessCheckCount
    );
    
    final avgDeviation = recentDeviation.reduce((a, b) => a + b) / recentDeviation.length;
    final maxDeviation = recentDeviation.reduce((a, b) => a > b ? a : b);

    debugPrint('静止检测 - 平均偏差: ${avgDeviation.toStringAsFixed(2)}, 最大偏差: ${maxDeviation.toStringAsFixed(2)}');

    if (avgDeviation < _stillnessThreshold && maxDeviation < _stillnessThreshold * 2) {
      if (_stillnessTimer == null) {
        debugPrint('检测到静止，开始5秒倒计时...');
        _stillnessTimer = Timer(_stillnessDuration, () {
          _triggerFallAlert();
        });
      }
    } else {
      if (_stillnessTimer != null) {
        debugPrint('检测到移动，取消倒计时');
        _stillnessTimer?.cancel();
        _stillnessTimer = null;
      }
    }
  }

  void _triggerFallAlert() {
    final now = DateTime.now();
    
    if (_lastFallTime == null || now.difference(_lastFallTime!) > Duration(seconds: 30)) {
      _lastFallTime = now;
      _fallDetected = true;
      debugPrint('确认跌倒！触发警报');
      onFallDetected?.call();
    }
    
    _resetImpactDetection();
  }

  void _resetImpactDetection() {
    _impactDetected = false;
    _impactTime = null;
    _stillnessTimer?.cancel();
    _stillnessTimer = null;
  }

  void resetFallStatus() {
    _fallDetected = false;
    _resetImpactDetection();
  }

  void simulateFall() {
    debugPrint('模拟跌倒触发');
    _fallDetected = true;
    _lastFallTime = DateTime.now();
    onFallDetected?.call();
  }

  Map<String, dynamic> getStatus() {
    return {
      'isMonitoring': _isMonitoring,
      'fallDetected': _fallDetected,
      'lastFallTime': _lastFallTime?.toIso8601String(),
      'impactDetected': _impactDetected,
      'impactTime': _impactTime?.toIso8601String(),
      'historyLength': _accelerometerHistory.length,
      'impactThreshold': _impactThreshold,
      'stillnessThreshold': _stillnessThreshold,
    };
  }
}
