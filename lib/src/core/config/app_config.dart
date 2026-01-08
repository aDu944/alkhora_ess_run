class AppConfig {
  static const String baseUrl = 'https://bms.alkhora.com';

  /// Office geofence configuration.
  ///
  /// Set these to your real office coordinates to enforce geofencing.
  /// If left as 0, geofencing is treated as disabled (button won't lock).
  /// 
  /// Note: Per-employee locations are now fetched from ERPNext Employee doctype.
  /// These values are used as fallback if no employee-specific locations are configured.
  static const double officeLatitude = 0;
  static const double officeLongitude = 0;
  static const double officeRadiusMeters = 100;

  static bool get geofenceEnabled =>
      officeRadiusMeters > 0 && officeLatitude.abs() > 0.000001 && officeLongitude.abs() > 0.000001;
}

/// Represents an allowed check-in location
class AllowedLocation {
  AllowedLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 100,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  factory AllowedLocation.fromMap(Map<String, dynamic> map) {
    return AllowedLocation(
      name: map['name'] as String? ?? map['location_name'] as String? ?? 'Location',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (map['radius_meters'] as num?)?.toDouble() ?? 
                   (map['radius'] as num?)?.toDouble() ?? 
                   100.0,
    );
  }
}

