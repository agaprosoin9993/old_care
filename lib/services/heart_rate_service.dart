import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class HeartRateService {
  CameraController? _controller;
  bool _isDetecting = false;
  final List<double> _redValues = [];
  Timer? _detectionTimer;
  int? _lastHeartRate;
  final List<int> _heartRateHistory = [];
  
  double _actualFps = 30.0;
  DateTime? _lastFrameTime;
  int _frameCount = 0;

  bool get isDetecting => _isDetecting;
  int? get lastHeartRate => _lastHeartRate;
  CameraController? get controller => _controller;

  Future<bool> initialize() async {
    if (kIsWeb) {
      debugPrint('Heart rate detection not supported on web');
      return false;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('No cameras available');
        return false;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      return true;
    } catch (e) {
      debugPrint('Failed to initialize camera: $e');
      return false;
    }
  }

  Future<void> startDetection({
    required Function(int heartRate, double progress) onProgress,
    required Function(int heartRate) onComplete,
    required Function(String error) onError,
  }) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      onError('相机未初始化');
      return;
    }

    if (_isDetecting) return;

    _isDetecting = true;
    _redValues.clear();
    _lastHeartRate = null;
    _heartRateHistory.clear();
    _frameCount = 0;
    _lastFrameTime = null;

    try {
      await _controller!.setFlashMode(FlashMode.torch);
      await _controller!.startImageStream((image) {
        if (!_isDetecting) return;

        final now = DateTime.now();
        if (_lastFrameTime != null) {
          _frameCount++;
          final elapsed = now.difference(_lastFrameTime!).inMilliseconds;
          if (elapsed >= 1000) {
            _actualFps = _frameCount * 1000.0 / elapsed;
            _frameCount = 0;
            _lastFrameTime = now;
          }
        } else {
          _lastFrameTime = now;
        }

        double redSum = 0;
        int pixelCount = 0;

        if (Platform.isAndroid) {
          final yPlane = image.planes[0];
          final uPlane = image.planes[1];
          final vPlane = image.planes[2];

          final width = image.width;
          final height = image.height;

          for (int y = height ~/ 4; y < height * 3 ~/ 4; y += 8) {
            for (int x = width ~/ 4; x < width * 3 ~/ 4; x += 8) {
              final yIndex = y * yPlane.bytesPerRow + x;
              final uvIndex = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2);

              if (yIndex < yPlane.bytes.length &&
                  uvIndex < uPlane.bytes.length &&
                  uvIndex < vPlane.bytes.length) {
                final yVal = yPlane.bytes[yIndex];
                final vVal = vPlane.bytes[uvIndex];

                int r = (yVal + 1.402 * (vVal - 128)).clamp(0, 255).toInt();
                redSum += r;
                pixelCount++;
              }
            }
          }
        } else {
          final plane = image.planes[0];
          final bytes = plane.bytes;
          final bytesPerRow = plane.bytesPerRow;
          final width = image.width;
          final height = image.height;

          for (int row = height ~/ 4; row < height * 3 ~/ 4; row += 8) {
            for (int col = width ~/ 4; col < width * 3 ~/ 4; col += 8) {
              final i = row * bytesPerRow + col * 4;
              if (i + 2 < bytes.length) {
                final r = bytes[i + 2];
                redSum += r;
                pixelCount++;
              }
            }
          }
        }

        if (pixelCount > 0) {
          final avgRed = redSum / pixelCount;
          _redValues.add(avgRed);
        }
      });

      const detectionDuration = Duration(seconds: 15);
      const updateInterval = Duration(milliseconds: 100);
      int elapsed = 0;

      _detectionTimer = Timer.periodic(updateInterval, (timer) async {
        elapsed += updateInterval.inMilliseconds;
        final progress = elapsed / detectionDuration.inMilliseconds;

        if (_redValues.length >= 60) {
          final heartRate = _calculateHeartRate();
          if (heartRate != null && heartRate >= 50 && heartRate <= 160) {
            _heartRateHistory.add(heartRate);
            
            if (_heartRateHistory.length > 5) {
              _heartRateHistory.removeAt(0);
            }
            
            final smoothedHeartRate = _heartRateHistory.reduce((a, b) => a + b) ~/ _heartRateHistory.length;
            _lastHeartRate = smoothedHeartRate;
            onProgress(smoothedHeartRate, progress);
          }
        }

        if (elapsed >= detectionDuration.inMilliseconds) {
          await stopDetection();
          if (_lastHeartRate != null) {
            onComplete(_lastHeartRate!);
          } else {
            onError('无法检测到有效心率，请确保手指完全覆盖摄像头');
          }
          timer.cancel();
        }
      });
    } catch (e) {
      _isDetecting = false;
      onError('检测失败: $e');
    }
  }

  int? _calculateHeartRate() {
    if (_redValues.length < 60) return null;

    final values = _redValues.sublist(_redValues.length - 300.clamp(60, _redValues.length));
    
    final filtered = _bandpassFilter(values);
    
    final peaks = _findPeaks(filtered);
    
    if (peaks.length < 2) return null;

    final validIntervals = <int>[];
    for (int i = 1; i < peaks.length; i++) {
      final interval = peaks[i] - peaks[i - 1];
      final instantBpm = 60.0 * _actualFps / interval;
      
      if (instantBpm >= 50 && instantBpm <= 160) {
        validIntervals.add(interval);
      }
    }

    if (validIntervals.length < 2) return null;

    validIntervals.sort();
    final trimmedIntervals = validIntervals.sublist(
      (validIntervals.length * 0.1).floor(),
      (validIntervals.length * 0.9).ceil(),
    );

    if (trimmedIntervals.isEmpty) return null;

    final avgInterval = trimmedIntervals.reduce((a, b) => a + b) / trimmedIntervals.length;
    final bpm = 60.0 * _actualFps / avgInterval;

    return bpm.round().clamp(50, 160);
  }

  List<double> _bandpassFilter(List<double> input) {
    if (input.length < 10) return input;

    final smoothed = List<double>.filled(input.length, 0);
    
    for (int i = 0; i < input.length; i++) {
      int start = (i - 5).clamp(0, input.length - 1);
      int end = (i + 5).clamp(0, input.length - 1);
      double sum = 0;
      int count = 0;
      for (int j = start; j <= end; j++) {
        sum += input[j];
        count++;
      }
      smoothed[i] = sum / count;
    }

    final detrended = List<double>.filled(input.length, 0);
    for (int i = 1; i < smoothed.length; i++) {
      detrended[i] = smoothed[i] - smoothed[i - 1];
    }

    return detrended;
  }

  List<int> _findPeaks(List<double> values) {
    final peaks = <int>[];
    final mean = values.reduce((a, b) => a + b) / values.length;
    final stdDev = sqrt(
      values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length
    );
    final threshold = mean + stdDev * 0.5;

    int? lastPeak;
    int minPeakDistance = (_actualFps * 0.4).round();

    for (int i = 2; i < values.length - 2; i++) {
      if (values[i] > threshold &&
          values[i] > values[i - 1] &&
          values[i] > values[i + 1] &&
          values[i] > values[i - 2] &&
          values[i] > values[i + 2]) {
        
        if (lastPeak == null || (i - lastPeak) >= minPeakDistance) {
          peaks.add(i);
          lastPeak = i;
        } else if (values[i] > values[lastPeak]) {
          peaks.remove(lastPeak);
          peaks.add(i);
          lastPeak = i;
        }
      }
    }

    return peaks;
  }

  Future<void> stopDetection() async {
    _isDetecting = false;
    _detectionTimer?.cancel();
    _detectionTimer = null;

    try {
      await _controller?.stopImageStream();
      await _controller?.setFlashMode(FlashMode.off);
    } catch (e) {
      debugPrint('Error stopping detection: $e');
    }
  }

  Future<void> dispose() async {
    await stopDetection();
    await _controller?.dispose();
    _controller = null;
  }
}
