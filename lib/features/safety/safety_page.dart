import 'package:flutter/material.dart';

class SafetyPage extends StatelessWidget {
  const SafetyPage({
    super.key,
    required this.fallDetection,
    required this.onFallToggle,
    required this.geoFenceEnabled,
    required this.onGeoFenceToggle,
    required this.geoFenceRadius,
    required this.onGeoFenceRadius,
    required this.location,
  });

  final bool fallDetection;
  final ValueChanged<bool> onFallToggle;
  final bool geoFenceEnabled;
  final ValueChanged<bool> onGeoFenceToggle;
  final double geoFenceRadius;
  final ValueChanged<double> onGeoFenceRadius;
  final String location;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCard(
            child: SwitchListTile(
              title: const Text('跌倒检测'),
              subtitle: const Text('检测到异常时自动通知家属'),
              value: fallDetection,
              onChanged: onFallToggle,
              secondary: const Icon(Icons.health_and_safety),
            ),
          ),
          const SizedBox(height: 12),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('电子围栏'),
                  subtitle: Text('超出范围自动通知 · ${geoFenceRadius.toStringAsFixed(0)} 米'),
                  value: geoFenceEnabled,
                  onChanged: onGeoFenceToggle,
                  secondary: const Icon(Icons.shield_moon_outlined),
                ),
                Wrap(
                  spacing: 8,
                  children: [300, 500, 800, 1200]
                      .map(
                        (v) => ChoiceChip(
                          label: Text('${v}米'),
                          selected: geoFenceRadius.round() == v,
                          onSelected: (_) => onGeoFenceRadius(v.toDouble()),
                        ),
                      )
                      .toList(),
                ),
                Slider(
                  value: geoFenceRadius,
                  min: 200,
                  max: 1500,
                  divisions: 13,
                  label: '${geoFenceRadius.toStringAsFixed(0)} 米',
                  onChanged: onGeoFenceRadius,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildCard(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('当前位置'),
              subtitle: Text(location),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 12),
          _buildCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('安全提示', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('• 晚间行走请随身携带手机，保持电量充足'),
                  Text('• 家中地面保持干燥，避免滑倒'),
                  Text('• 出门记得告知家人，开启位置共享'),
                ],
              ),
            ),
          ),
        ],
      ),
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
