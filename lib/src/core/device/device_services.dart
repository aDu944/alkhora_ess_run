import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceServices {
  static Future<bool> hasNetwork() async {
    final res = await Connectivity().checkConnectivity();
    return res != ConnectivityResult.none;
  }

  static Future<LocationPermission> ensureLocationPermission() async {
    // Check if location services are enabled first
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return LocationPermission.denied;
    }

    // Check current permission status
    final geolocatorStatus = await Geolocator.checkPermission();
    if (geolocatorStatus == LocationPermission.whileInUse || 
        geolocatorStatus == LocationPermission.always) {
      return geolocatorStatus;
    }

    // Request permission using permission_handler
    final status = await Permission.locationWhenInUse.request();
    
    if (status.isGranted) {
      // Double check with Geolocator
      final finalStatus = await Geolocator.checkPermission();
      return finalStatus;
    } else if (status.isPermanentlyDenied) {
      return LocationPermission.deniedForever;
    }

    return LocationPermission.denied;
  }

  /// Check if we can request permission (not permanently denied)
  static Future<bool> canRequestLocationPermission() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isDenied || status.isLimited;
  }

  /// Open app settings to enable location permission
  static Future<bool> openLocationSettings() async {
    // Open app settings using permission_handler
    return await openAppSettings();
  }

  static Future<Position> getPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } on TimeoutException {
      rethrow;
    } on LocationServiceDisabledException {
      rethrow;
    } catch (e) {
      // Wrap other exceptions
      throw Exception('Failed to get location: $e');
    }
  }
}

