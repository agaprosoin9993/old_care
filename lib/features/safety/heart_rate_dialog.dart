import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/heart_rate_service.dart';

class HeartRateDialog extends StatefulWidget {
  final HeartRateService heartRateService;

  const HeartRateDialog({
    super.key,
    required this.heartRateService,
  });

  @override
  State<HeartRateDialog> createState() => _HeartRateDialogState();
}

class _HeartRateDialogState extends State<HeartRateDialog> {
  bool _isDetecting = false;
  int? _currentHeartRate;
  double _progress = 0.0;
  String? _errorMessage;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final success = await widget.heartRateService.initialize();
    if (mounted) {
      setState(() {
        _isInitialized = success;
        if (!success) {
          _errorMessage = '无法初始化相机，请检查相机权限';
        }
      });
    }
  }

  Future<void> _startDetection() async {
    if (!_isInitialized) {
      await _initializeCamera();
      if (!_isInitialized) return;
    }

    setState(() {
      _isDetecting = true;
      _currentHeartRate = null;
      _progress = 0.0;
      _errorMessage = null;
    });

    await widget.heartRateService.startDetection(
      onProgress: (heartRate, progress) {
        if (mounted) {
          setState(() {
            _currentHeartRate = heartRate;
            _progress = progress;
          });
        }
      },
      onComplete: (heartRate) {
        if (mounted) {
          setState(() {
            _isDetecting = false;
            _currentHeartRate = heartRate;
            _progress = 1.0;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isDetecting = false;
            _errorMessage = error;
          });
        }
      },
    );
  }

  Future<void> _stopDetection() async {
    await widget.heartRateService.stopDetection();
    if (mounted) {
      setState(() {
        _isDetecting = false;
      });
    }
  }

  @override
  void dispose() {
    widget.heartRateService.stopDetection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '心率检测',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _stopDetection();
                    Navigator.of(context).pop(_currentHeartRate);
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (kIsWeb)
              _buildWebMessage()
            else if (!_isInitialized)
              _buildInitializing()
            else if (_isDetecting || _currentHeartRate != null)
              _buildDetectionUI()
            else
              _buildStartUI(),
            if (_errorMessage != null) _buildErrorMessage(),
          ],
        ),
      ),
    );
  }

  Widget _buildWebMessage() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.orange),
              SizedBox(height: 12),
              Text(
                '心率检测功能需要在手机上使用',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildInitializing() {
    return const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('正在初始化相机...'),
      ],
    );
  }

  Widget _buildStartUI() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.favorite,
            size: 64,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '请将手指完全覆盖在摄像头和闪光灯上',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          '保持手指静止，检测约需15秒',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _startDetection,
          icon: const Icon(Icons.play_arrow),
          label: const Text('开始检测'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDetectionUI() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isDetecting ? Colors.red : Colors.green,
                ),
              ),
            ),
            Column(
              children: [
                if (_currentHeartRate != null) ...[
                  Text(
                    '$_currentHeartRate',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const Text(
                    'BPM',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ] else
                  const Text(
                    '检测中...',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _isDetecting ? '请保持手指静止...' : '检测完成',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        if (_isDetecting)
          TextButton.icon(
            onPressed: _stopDetection,
            icon: const Icon(Icons.stop),
            label: const Text('停止检测'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: _startDetection,
                icon: const Icon(Icons.refresh),
                label: const Text('重新检测'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_currentHeartRate),
                child: const Text('确定'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
