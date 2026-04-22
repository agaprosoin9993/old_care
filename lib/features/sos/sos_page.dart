import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/location_map_widget.dart';

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
    this.latitude,
    this.longitude,
    this.isLocating = false,
    required this.onLocationRefresh,
    required this.lastLocationUpdate,
    this.onCallEmergency,
  });

  final DateTime? lastHelpTime;
  final String contact;
  final String? contactPhone;
  final VoidCallback onSOS;
  final bool locationSharing;
  final ValueChanged<bool> onLocationToggle;
  final String location;
  final double? latitude;
  final double? longitude;
  final bool isLocating;
  final VoidCallback onLocationRefresh;
  final DateTime? lastLocationUpdate;
  final VoidCallback? onCallEmergency;

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
              onPressed: () {
                onSOS();
                if (contactPhone != null && contactPhone!.isNotEmpty) {
                  onCallEmergency?.call();
                }
              },
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
    final hasLocation = latitude != null && longitude != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasLocation ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: hasLocation ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '我的位置',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasLocation 
                            ? (lastLocationUpdate != null 
                                ? '更新于 ${_formatTime(lastLocationUpdate!)}' 
                                : '已获取')
                            : '点击下方按钮获取位置',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasLocation ? Colors.green.shade600 : Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasLocation)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '已定位',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          LocationMapWidget(
            zoom: 16,
            height: 180,
            center: latitude != null && longitude != null 
                ? LatLng(latitude!, longitude!) 
                : null,
            markers: latitude != null && longitude != null 
                ? [
                    MapMarker(
                      position: LatLng(latitude!, longitude!),
                      label: '我的位置',
                      color: Colors.blue,
                    ),
                  ]
                : [],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                if (hasLocation) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location.isNotEmpty ? location : '位置已获取',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isLocating ? null : onLocationRefresh,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.blue.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: isLocating
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(Icons.my_location, color: Colors.blue.shade600),
                        label: Text(
                          isLocating ? '定位中...' : '更新我的位置',
                          style: TextStyle(color: Colors.blue.shade600),
                        ),
                      ),
                    ),
                    if (hasLocation) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openInMapApp(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.green.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: Icon(Icons.map, color: Colors.green.shade600),
                          label: Text(
                            '在地图中打开',
                            style: TextStyle(color: Colors.green.shade600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openInMapApp(BuildContext context) async {
    if (latitude == null || longitude == null) return;
    final uri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
