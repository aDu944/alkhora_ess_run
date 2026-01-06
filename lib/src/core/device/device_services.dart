import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceServices {
  static Future<bool> hasNetwork() async {
    final res = await Connectivity().checkConnectivity();
    return res != ConnectivityResult.none;
  }

  static Future<LocationPermission> ensureLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) return LocationPermission.denied;

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return LocationPermission.denied;

    return Geolocator.checkPermission();
  }

  static Future<Position> getPosition() async {
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
  }
}

