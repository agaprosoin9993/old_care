import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationResult {
  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.display,
    this.address,
    this.accuracy,
    this.locationType,
    this.province,
    this.city,
    this.district,
    this.street,
  });

  final double latitude;
  final double longitude;
  final String display;
  final String? address;
  final double? accuracy;
  final String? locationType;
  final String? province;
  final String? city;
  final String? district;
  final String? street;
}

class LocationService {
  LocationService();

  static const double _defaultLatitude = 39.9042;
  static const double _defaultLongitude = 116.4074;
  static const String _defaultLocation = '北京市东城区';

  static const MethodChannel _channel = MethodChannel('tencent_location_service');

  Future<bool> requestPermission() async {
    try {
      final status = await Permission.location.request();
      debugPrint('定位权限状态: $status');
      
      if (status.isDenied) {
        final status2 = await Permission.location.request();
        debugPrint('再次请求定位权限: $status2');
      }
      
      if (status.isPermanentlyDenied) {
        debugPrint('定位权限被永久拒绝，请到设置中开启');
        await openAppSettings();
        return false;
      }
      
      return status.isGranted;
    } catch (e) {
      debugPrint('请求定位权限失败: $e');
      return false;
    }
  }

  Future<LocationResult> getCurrentLocation() async {
    debugPrint('开始获取位置...');
    
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('没有定位权限');
    }
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      final result = await _getTencentLocation();
      if (result.locationType != '默认位置') {
        return result;
      }
    }
    
    return _getGeolocatorLocation();
  }

  Future<LocationResult> _getTencentLocation() async {
    try {
      debugPrint('尝试Android原生定位...');
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getCurrentLocation');
      
      if (result != null) {
        final latitude = (result['latitude'] as num).toDouble();
        final longitude = (result['longitude'] as num).toDouble();
        final accuracy = result['accuracy'] as double?;
        final address = result['address'] as String?;
        final province = result['province'] as String?;
        final city = result['city'] as String?;
        final district = result['district'] as String?;
        final street = result['street'] as String?;
        final provider = result['provider'] as String?;

        debugPrint('Android原生定位结果: lat=$latitude, lng=$longitude, provider=$provider');

        String display;
        if (address != null && address.isNotEmpty) {
          display = address;
        } else if (district != null && district.isNotEmpty) {
          display = '$province$city$district';
        } else {
          display = '纬度 ${latitude.toStringAsFixed(6)}, 经度 ${longitude.toStringAsFixed(6)}';
        }

        return LocationResult(
          latitude: latitude,
          longitude: longitude,
          display: display,
          address: address,
          accuracy: accuracy,
          locationType: provider ?? '腾讯定位',
          province: province,
          city: city,
          district: district,
          street: street,
        );
      }
    } catch (e) {
      debugPrint('Android原生定位失败: $e');
    }

    return LocationResult(
      latitude: _defaultLatitude,
      longitude: _defaultLongitude,
      display: _defaultLocation,
      locationType: '默认位置',
    );
  }

  Future<LocationResult> _getGeolocatorLocation() async {
    Position? position;
    bool useDefault = false;
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('定位服务是否启用: $serviceEnabled');
      
      if (!serviceEnabled) {
        debugPrint('定位服务未启用，尝试启用...');
        serviceEnabled = await Geolocator.openLocationSettings();
        await Future.delayed(const Duration(seconds: 2));
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      }
      
      if (!serviceEnabled) {
        debugPrint('定位服务仍未启用');
        useDefault = true;
      } else {
        LocationPermission permission = await Geolocator.checkPermission();
        debugPrint('当前定位权限: $permission');
        
        if (permission == LocationPermission.denied) {
          debugPrint('请求定位权限...');
          permission = await Geolocator.requestPermission();
          debugPrint('权限请求结果: $permission');
        }

        if (permission == LocationPermission.denied) {
          debugPrint('定位权限被拒绝');
          useDefault = true;
        } else if (permission == LocationPermission.deniedForever) {
          debugPrint('定位权限被永久拒绝');
          await Geolocator.openAppSettings();
          useDefault = true;
        } else {
          debugPrint('尝试高精度定位...');
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 15),
              ),
            );
            debugPrint('高精度定位成功: ${position.latitude}, ${position.longitude}');
          } catch (e) {
            debugPrint('高精度定位失败: $e，尝试低精度...');
            try {
              position = await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.low,
                  timeLimit: Duration(seconds: 10),
                ),
              );
              debugPrint('低精度定位成功: ${position.latitude}, ${position.longitude}');
            } catch (e2) {
              debugPrint('低精度定位失败: $e2，尝试获取最后位置...');
              try {
                position = await Geolocator.getLastKnownPosition();
                if (position != null) {
                  debugPrint('获取最后位置成功: ${position.latitude}, ${position.longitude}');
                }
              } catch (e3) {
                debugPrint('获取最后位置失败: $e3');
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('定位过程出错: $e');
      useDefault = true;
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
    } else if (position.isMocked) {
      locationType = '模拟定位';
      display = '当前位置（模拟）';
    } else {
      locationType = 'GPS定位';
      display = '当前位置';
    }
    
    debugPrint('最终位置: ${position.latitude}, ${position.longitude}, 类型: $locationType');
    
    return LocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      display: display,
      accuracy: position.accuracy,
      locationType: locationType,
    );
  }
}
