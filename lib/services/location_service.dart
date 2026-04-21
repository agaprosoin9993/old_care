import 'package:flutter/foundation.dart';
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

  static const double _defaultLatitude = 39.9042;
  static const double _defaultLongitude = 116.4074;
  static const String _defaultLocation = '北京市东城区';

  Future<LocationResult> getCurrentLocation() async {
    Position? position;
    bool useDefault = false;
    
    try {
      await _ensurePermission();
      
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (e) {
        debugPrint('高精度定位失败: $e');
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          );
        } catch (e2) {
          debugPrint('低精度定位失败: $e2');
          try {
            position = await Geolocator.getLastKnownPosition();
          } catch (e3) {
            debugPrint('获取最后位置失败: $e3');
          }
        }
      }
    } catch (e) {
      debugPrint('定位权限检查失败: $e');
    }
    
    if (position == null) {
      useDefault = true;
      position = Position(
        latitude: _defaultLatitude,
        longitude: _defaultLongitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
    
    String locationType;
    String display;
    
    if (useDefault) {
      locationType = '默认位置';
      display = _defaultLocation;
    } else if (position!.isMocked) {
      locationType = '模拟定位';
      display = '纬度 ${position.latitude.toStringAsFixed(6)}, 经度 ${position.longitude.toStringAsFixed(6)}';
    } else {
      locationType = 'GPS定位';
      display = '纬度 ${position.latitude.toStringAsFixed(6)}, 经度 ${position.longitude.toStringAsFixed(6)}';
    }
    
    return LocationResult(
      latitude: position!.latitude,
      longitude: position.longitude,
      display: display,
      accuracy: position.accuracy,
      locationType: locationType,
    );
  }

  Future<void> _ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('定位服务未开启');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('未授予定位权限');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('定位权限被永久拒绝');
    }
  }
}
