import 'package:geolocator/geolocator.dart';

class LocationResult {
  LocationResult({required this.latitude, required this.longitude, required this.display, this.mapPreviewUrl});

  final double latitude;
  final double longitude;
  final String display;
  final String? mapPreviewUrl;
}

class LocationService {
  LocationService({String? tencentMapKey})
      : _tencentMapKey = tencentMapKey ?? const String.fromEnvironment('TENCENT_MAP_KEY', defaultValue: '');

  final String _tencentMapKey;

  Future<LocationResult> getCurrentLocation() async {
    await _ensurePermission();
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    final display = '纬度 ${position.latitude.toStringAsFixed(6)}, 经度 ${position.longitude.toStringAsFixed(6)}';
    final mapUrl = _buildTencentStaticMap(position.latitude, position.longitude);
    return LocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      display: mapUrl == null ? display : '$display (已生成腾讯地图预览)',
      mapPreviewUrl: mapUrl,
    );
  }

  Future<void> _ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('定位服务未开启，请在系统设置中开启定位');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('未授予定位权限');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('定位权限被永久拒绝，请到系统设置开启');
    }
  }

  String? _buildTencentStaticMap(double lat, double lng) {
    if (_tencentMapKey.isEmpty) return null;
    // Static map API: https://lbs.qq.com/service/static_map
    final size = '600*360';
    final center = '$lat,$lng';
    final marker = 'color:0xff0000|label:S|$lat,$lng';
    return 'https://apis.map.qq.com/ws/staticmap/v2/?center=$center&zoom=16&size=$size&maptype=roadmap&markers=$marker&key=$_tencentMapKey';
  }
}
