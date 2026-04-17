import 'package:geolocator/geolocator.dart';

class LocationResult {
  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.display,
    this.address,
    this.accuracy,
    this.locationType,
  });

  final double latitude;
  final double longitude;
  final String display;
  final String? address;
  final double? accuracy;
  final String? locationType;
}

class LocationService {
  LocationService();

  Future<LocationResult> getCurrentLocation() async {
    await _ensurePermission();
    
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    
    String locationType = 'GPS定位';
    if (position.isMocked) {
      locationType = '模拟定位';
    }
    
    final display = '纬度 ${position.latitude.toStringAsFixed(6)}, 经度 ${position.longitude.toStringAsFixed(6)}';
    
    return LocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      display: display,
      accuracy: position.accuracy,
      locationType: locationType,
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
}
