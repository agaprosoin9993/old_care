import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class HeartRateService {
  CameraController? _controller;
  bool _isDetecting = false;
  final List<double> _redValues = [];
  Timer? _detectionTimer;
  int? _lastHeartRate;

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

    try {
      await _controller!.setFlashMode(FlashMode.torch);
      await _controller!.startImageStream((image) {
        if (!_isDetecting) return;

        double redSum = 0;
        int pixelCount = 0;

        if (Platform.isAndroid) {
          final yPlane = image.planes[0];
          final uPlane = image.planes[1];
          final vPlane = image.planes[2];

          final width = image.width;
          final height = image.height;

          for (int y = 0; y < height; y += 10) {
            for (int x = 0; x < width; x += 10) {
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

          for (int i = 0; i < bytes.length; i += 4) {
            final row = i ~/ bytesPerRow;
            final col = (i % bytesPerRow) ~/ 4;
            if (row % 10 == 0 && col % 10 == 0) {
              final r = bytes[i + 2];
              redSum += r;
              pixelCount++;
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

        if (_redValues.length >= 30) {
          final heartRate = _calculateHeartRate();
          if (heartRate != null && heartRate > 40 && heartRate < 200) {
            _lastHeartRate = heartRate;
            onProgress(heartRate, progress);
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
    if (_redValues.length < 30) return null;

    final values = _redValues.sublist(_redValues.length - 150);
    final mean = values.reduce((a, b) => a + b) / values.length;

    final peaks = <int>[];
    for (int i = 1; i < values.length - 1; i++) {
      if (values[i] > values[i - 1] &&
          values[i] > values[i + 1] &&
          values[i] > mean) {
        peaks.add(i);
      }
    }

    if (peaks.length < 2) return null;

    final intervals = <int>[];
    for (int i = 1; i < peaks.length; i++) {
      intervals.add(peaks[i] - peaks[i - 1]);
    }

    final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    final fps = 30.0;
    final bpm = 60.0 * fps / avgInterval;

    return bpm.round();
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
