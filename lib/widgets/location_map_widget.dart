import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LocationMapWidget extends StatefulWidget {
  const LocationMapWidget({
    super.key,
    this.center,
    this.zoom = 15.0,
    this.markers = const [],
    this.height = 250,
    this.onMapReady,
  });

  final dynamic center;
  final double zoom;
  final List<MapMarker> markers;
  final double height;
  final VoidCallback? onMapReady;

  @override
  State<LocationMapWidget> createState() => _LocationMapWidgetState();
}

class _LocationMapWidgetState extends State<LocationMapWidget> {
  MethodChannel? _mapChannel;
  double _currentZoom = 12.0;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _latitude = widget.center?.latitude ?? 39.9042;
    _longitude = widget.center?.longitude ?? 116.4074;
    _currentZoom = widget.zoom;
  }

  @override
  void didUpdateWidget(LocationMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.markers != oldWidget.markers && _mapChannel != null) {
      _updateMarkers();
    }
    if (widget.center != oldWidget.center && widget.center != null) {
      _latitude = widget.center.latitude;
      _longitude = widget.center.longitude;
      if (_mapChannel != null) {
        _moveToLocation(_latitude!, _longitude!);
      }
    }
  }

  void _onPlatformViewCreated(int id) {
    _mapChannel = MethodChannel('tencent_map_$id');
    widget.onMapReady?.call();
    
    if (_latitude != null && _longitude != null) {
      _moveToLocation(_latitude!, _longitude!);
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMarkers();
    });
  }

  Future<void> _updateMarkers() async {
    if (_mapChannel == null) return;
    
    try {
      await _mapChannel?.invokeMethod('clearMarkers');
      
      for (final marker in widget.markers) {
        if (marker.position != null) {
          await _mapChannel?.invokeMethod('addMarker', {
            'latitude': marker.position!.latitude,
            'longitude': marker.position!.longitude,
            'title': marker.label ?? '',
            'color': marker.color?.toARGB32().toRadixString(16) ?? 'red',
          });
        }
      }
    } catch (e) {
      debugPrint('更新标记点失败: $e');
    }
  }

  Future<void> _moveToLocation(double lat, double lng) async {
    try {
      await _mapChannel?.invokeMethod('moveToLocation', {
        'latitude': lat,
        'longitude': lng,
        'zoom': _currentZoom,
      });
    } catch (e) {
      debugPrint('移动地图失败: $e');
    }
  }

  Future<void> _zoomIn() async {
    if (_currentZoom < 18) {
      _currentZoom += 1;
      try {
        await _mapChannel?.invokeMethod('zoomIn');
      } catch (e) {
        debugPrint('放大失败: $e');
      }
    }
  }

  Future<void> _zoomOut() async {
    if (_currentZoom > 3) {
      _currentZoom -= 1;
      try {
        await _mapChannel?.invokeMethod('zoomOut');
      } catch (e) {
        debugPrint('缩小失败: $e');
      }
    }
  }

  Future<void> _moveToMyLocation() async {
    if (_latitude != null && _longitude != null) {
      await _moveToLocation(_latitude!, _longitude!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AndroidView(
                viewType: 'tencent_map_view',
                creationParams: {
                  'zoom': widget.zoom,
                  'latitude': _latitude,
                  'longitude': _longitude,
                },
                creationParamsCodec: const StandardMessageCodec(),
                onPlatformViewCreated: _onPlatformViewCreated,
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Column(
                children: [
                  _buildControlButton(Icons.add, '放大', _zoomIn),
                  const SizedBox(height: 4),
                  _buildControlButton(Icons.remove, '缩小', _zoomOut),
                  const SizedBox(height: 4),
                  _buildControlButton(Icons.my_location, '定位', _moveToMyLocation),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: Center(
        child: Text(
          '地图仅支持 Android 平台',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: FloatingActionButton.small(
        heroTag: tooltip,
        onPressed: onPressed,
        backgroundColor: Colors.white,
        elevation: 2,
        child: Icon(icon, color: Colors.blue, size: 20),
      ),
    );
  }
}

class MapMarker {
  MapMarker({
    required this.position,
    this.icon,
    this.color,
    this.label,
    this.onTap,
  });

  final LatLng? position;
  final IconData? icon;
  final Color? color;
  final String? label;
  final VoidCallback? onTap;
}

class LatLng {
  const LatLng(this.latitude, this.longitude);
  
  final double latitude;
  final double longitude;
}
