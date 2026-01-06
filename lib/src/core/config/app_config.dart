class AppConfig {
  static const String baseUrl = 'https://bms.alkhora.com';

  /// Office geofence configuration.
  ///
  /// Set these to your real office coordinates to enforce geofencing.
  /// If left as 0, geofencing is treated as disabled (button won't lock).
  static const double officeLatitude = 0;
  static const double officeLongitude = 0;
  static const double officeRadiusMeters = 100;

  static bool get geofenceEnabled =>
      officeRadiusMeters > 0 && officeLatitude.abs() > 0.000001 && officeLongitude.abs() > 0.000001;
}

