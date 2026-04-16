import 'package:flutter/material.dart';
import 'heart_rate_dialog.dart';
import '../../services/heart_rate_service.dart';
import '../../services/fall_detection_service.dart';

class SafetyPage extends StatefulWidget {
  const SafetyPage({
    super.key,
    required this.fallDetection,
    required this.onFallToggle,
    required this.heartRateMonitoring,
    required this.onHeartRateToggle,
    required this.heartRateService,
    required this.fallDetectionService,
    this.onFallDetected,
  });

  final bool fallDetection;
  final ValueChanged<bool> onFallToggle;
  final bool heartRateMonitoring;
  final ValueChanged<bool> onHeartRateToggle;
  final HeartRateService heartRateService;
  final FallDetectionService fallDetectionService;
  final VoidCallback? onFallDetected;

  @override
  State<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends State<SafetyPage> {
  bool _fallAlertShown = false;

  @override
  void initState() {
    super.initState();
    _setupFallDetection();
  }

  void _setupFallDetection() {
    widget.fallDetectionService.onFallDetected = () {
      if (mounted && !_fallAlertShown) {
        _fallAlertShown = true;
        _showFallAlert();
        widget.onFallDetected?.call();
      }
    };
  }

  void _showFallAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            const Text('跌倒检测'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('系统检测到可能发生了跌倒！'),
            SizedBox(height: 12),
            Text('如果您需要帮助，请点击SOS按钮。'),
            Text('如果这是误报，请点击"我没事"。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _fallAlertShown = false);
              widget.fallDetectionService.resetFallStatus();
            },
            child: const Text('我没事'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _fallAlertShown = false);
              widget.onFallDetected?.call();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('立即求助'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSectionTitle('安全防护'),
          const SizedBox(height: 8),
          _buildCard(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('跌倒检测'),
                  subtitle: Text(
                    widget.fallDetection
                        ? '正在监测中，检测到异常会自动提醒'
                        : '使用加速度传感器和陀螺仪检测跌倒',
                  ),
                  value: widget.fallDetection,
                  onChanged: (v) {
                    widget.onFallToggle(v);
                    if (v) {
                      widget.fallDetectionService.startMonitoring();
                    } else {
                      widget.fallDetectionService.stopMonitoring();
                    }
                  },
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.fallDetection ? Colors.red.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.health_and_safety,
                      color: widget.fallDetection ? Colors.red : Colors.grey,
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('心率监测'),
                  subtitle: const Text('使用相机检测心率变化'),
                  value: widget.heartRateMonitoring,
                  onChanged: widget.onHeartRateToggle,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.heartRateMonitoring ? Colors.pink.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: widget.heartRateMonitoring ? Colors.pink : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.fallDetection) ...[
            const SizedBox(height: 12),
            _buildCard(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '跌倒检测已开启',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '传感器正在后台运行监测中',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildSectionTitle('快速检测'),
          const SizedBox(height: 8),
          _buildCard(
            child: InkWell(
              onTap: () => _showHeartRateDialog(context),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.monitor_heart,
                        color: Colors.red,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '心率检测',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '使用手机相机检测心率',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '开始',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('安全提示'),
          const SizedBox(height: 8),
          _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTipItem(Icons.phone_android, '手机保持电量充足', '建议电量低于20%时及时充电'),
                  const SizedBox(height: 12),
                  _buildTipItem(Icons.wb_sunny_outlined, '注意天气变化', '外出前查看天气预报，备好雨具'),
                  const SizedBox(height: 12),
                  _buildTipItem(Icons.medication_outlined, '按时服药', '设置用药提醒，保持健康作息'),
                  const SizedBox(height: 12),
                  _buildTipItem(Icons.family_restroom, '保持联系', '出门前告知家人去向，定期报平安'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('紧急情况'),
          const SizedBox(height: 8),
          _buildCard(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.sos,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '遇到紧急情况',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '请点击首页SOS按钮求助',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHeartRateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => HeartRateDialog(
        heartRateService: widget.heartRateService,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.orange.shade700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}
