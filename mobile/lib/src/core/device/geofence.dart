import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../config/app_config.dart';

class GeofenceStatus {
  GeofenceStatus({
    required this.enabled,
    required this.within,
    required this.mockLocationDetected,
    required this.distanceMeters,
    required this.accuracyMeters,
    required this.error,
  });

  final bool enabled;
  final bool within;
  final bool mockLocationDetected;
  final double? distanceMeters;
  final double? accuracyMeters;

  /// Non-null when status cannot be computed (permissions/services disabled/etc).
  final String? error;

  static GeofenceStatus disabled() => GeofenceStatus(
        enabled: false,
        within: true,
        mockLocationDetected: false,
        distanceMeters: null,
        accuracyMeters: null,
        error: null,
      );
}

final geofenceStatusProvider = StreamProvider<GeofenceStatus>((ref) async* {
  if (!AppConfig.geofenceEnabled) {
    yield GeofenceStatus.disabled();
    return;
  }

  final servicesEnabled = await Geolocator.isLocationServiceEnabled();
  if (!servicesEnabled) {
    yield GeofenceStatus(
      enabled: true,
      within: false,
      mockLocationDetected: false,
      distanceMeters: null,
      accuracyMeters: null,
      error: 'location_services_disabled',
    );
    return;
  }

  final perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
    yield GeofenceStatus(
      enabled: true,
      within: false,
      mockLocationDetected: false,
      distanceMeters: null,
      accuracyMeters: null,
      error: 'location_permission_denied',
    );
    return;
  }

  final stream = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  );

  await for (final pos in stream) {
    final dist = Geolocator.distanceBetween(
      AppConfig.officeLatitude,
      AppConfig.officeLongitude,
      pos.latitude,
      pos.longitude,
    );
    yield GeofenceStatus(
      enabled: true,
      within: dist <= AppConfig.officeRadiusMeters,
      mockLocationDetected: pos.isMocked,
      distanceMeters: dist,
      accuracyMeters: pos.accuracy,
      error: null,
    );
  }
});

