import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class FallDetectionService {
  static final FallDetectionService _instance = FallDetectionService._internal();
  factory FallDetectionService() => _instance;
  FallDetectionService._internal();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  bool _isMonitoring = false;
  bool _fallDetected = false;
  DateTime? _lastFallTime;

  final List<double> _accelerometerHistory = [];
  final List<double> _gyroscopeHistory = [];

  static const int _historySize = 50;
  static const double _fallThreshold = 25.0;
  static const double _gyroscopeThreshold = 5.0;
  static const Duration _fallWindow = Duration(seconds: 3);

  Function()? onFallDetected;

  bool get isMonitoring => _isMonitoring;
  bool get fallDetected => _fallDetected;
  DateTime? get lastFallTime => _lastFallTime;

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

      _gyroscopeSubscription = gyroscopeEventStream().listen(
        _onGyroscopeEvent,
        onError: (error) {
          debugPrint('Gyroscope error: $error');
        },
      );

      _isMonitoring = true;
      _fallDetected = false;
      return true;
    } catch (e) {
      debugPrint('Failed to start fall detection: $e');
      return false;
    }
  }

  void stopMonitoring() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    _isMonitoring = false;
    _accelerometerHistory.clear();
    _gyroscopeHistory.clear();
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    final magnitude = _calculateMagnitude(event.x, event.y, event.z);
    
    _accelerometerHistory.add(magnitude);
    if (_accelerometerHistory.length > _historySize) {
      _accelerometerHistory.removeAt(0);
    }

    _checkForFall();
  }

  void _onGyroscopeEvent(GyroscopeEvent event) {
    final magnitude = _calculateMagnitude(event.x, event.y, event.z);
    
    _gyroscopeHistory.add(magnitude);
    if (_gyroscopeHistory.length > _historySize) {
      _gyroscopeHistory.removeAt(0);
    }
  }

  double _calculateMagnitude(double x, double y, double z) {
    return (x * x + y * y + z * z);
  }

  void _checkForFall() {
    if (_accelerometerHistory.length < 10) return;

    final recentAccel = _accelerometerHistory.sublist(_accelerometerHistory.length - 10);
    final maxAccel = recentAccel.reduce((a, b) => a > b ? a : b);

    if (maxAccel > _fallThreshold) {
      final recentGyro = _gyroscopeHistory.length >= 10
          ? _gyroscopeHistory.sublist(_gyroscopeHistory.length - 10)
          : _gyroscopeHistory;
      
      final maxGyro = recentGyro.isNotEmpty
          ? recentGyro.reduce((a, b) => a > b ? a : b)
          : 0.0;

      if (maxGyro > _gyroscopeThreshold || recentGyro.isEmpty) {
        final now = DateTime.now();
        
        if (_lastFallTime == null || 
            now.difference(_lastFallTime!) > _fallWindow) {
          _lastFallTime = now;
          _fallDetected = true;
          debugPrint('Fall detected! Accel: $maxAccel, Gyro: $maxGyro');
          onFallDetected?.call();
        }
      }
    }
  }

  void resetFallStatus() {
    _fallDetected = false;
  }

  Map<String, dynamic> getStatus() {
    return {
      'isMonitoring': _isMonitoring,
      'fallDetected': _fallDetected,
      'lastFallTime': _lastFallTime?.toIso8601String(),
      'accelerometerHistory': _accelerometerHistory.length,
      'gyroscopeHistory': _gyroscopeHistory.length,
    };
  }
}
