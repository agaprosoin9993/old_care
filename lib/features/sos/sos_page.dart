import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SosPage extends StatelessWidget {
  const SosPage({
    super.key,
    required this.lastHelpTime,
    required this.contact,
    this.contactPhone,
    required this.onSOS,
    required this.locationSharing,
    required this.onLocationToggle,
    required this.location,
    this.isLocating = false,
    required this.onLocationRefresh,
    required this.lastLocationUpdate,
  });

  final DateTime? lastHelpTime;
  final String contact;
  final String? contactPhone;
  final VoidCallback onSOS;
  final bool locationSharing;
  final ValueChanged<bool> onLocationToggle;
  final String location;
  final bool isLocating;
  final VoidCallback onLocationRefresh;
  final DateTime? lastLocationUpdate;

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      final launched = await launchUrl(
        phoneUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法打开拨号界面，请手动拨打: $phoneNumber'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('拨号失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _callEmergencyContact(BuildContext context) {
    if (contactPhone != null && contactPhone!.isNotEmpty) {
      _makePhoneCall(context, contactPhone!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先设置紧急联系人电话'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _callPolice(BuildContext context) {
    _makePhoneCall(context, '110');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroCard(context),
          const SizedBox(height: 16),
          _buildContactCard(context),
          const SizedBox(height: 16),
          _buildLocationCard(context),
          const SizedBox(height: 16),
          _buildQuickActions(context),
          const SizedBox(height: 16),
          _buildStatus(context),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '遇到紧急情况？',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onSOS,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 64),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.sos, size: 28),
              label: const Text('呼叫家人 / SOS', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 6),
            Text(
              '一键呼救',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (lastHelpTime != null) ...[
              const SizedBox(height: 8),
              Text(
                '上次呼救：${_formatTime(lastHelpTime!)}',
                style: TextStyle(color: Colors.grey.shade700),
              )
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.family_restroom, color: Colors.redAccent, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('紧急联系人', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Text(
                    contact,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_pin, color: Colors.redAccent),
                const SizedBox(width: 8),
                const Text('位置共享'),
                const Spacer(),
                Switch(value: locationSharing, onChanged: onLocationToggle),
              ],
            ),
            const SizedBox(height: 6),
            Text(location, style: const TextStyle(fontSize: 15)),
            if (lastLocationUpdate != null) ...[
              const SizedBox(height: 4),
              Text(
                '上次更新：${_formatTime(lastLocationUpdate!)}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: isLocating ? null : onLocationRefresh,
                icon: isLocating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: Text(isLocating ? '定位中...' : '更新位置'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _callEmergencyContact(context),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.phone, color: Colors.redAccent),
            label: const Text('拨打联系人'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _callPolice(context),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.local_police, color: Colors.redAccent),
            label: const Text('拨打110'),
          ),
        ),
      ],
    );
  }

  Widget _buildStatus(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: const [
            Icon(Icons.info_outline, color: Colors.blueGrey),
            SizedBox(width: 10),
            Expanded(
              child: Text('提醒：保持手机有电并开启定位，紧急时可快速联系家人。'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}
