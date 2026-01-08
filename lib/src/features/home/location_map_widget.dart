import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/device/device_services.dart';

class LocationMapWidget extends ConsumerStatefulWidget {
  const LocationMapWidget({super.key});

  @override
  ConsumerState<LocationMapWidget> createState() => _LocationMapWidgetState();
}

class _LocationMapWidgetState extends ConsumerState<LocationMapWidget> {
  Position? _currentPosition;
  bool _isLoading = true;
  String? _error;
  bool _isPermissionDenied = false;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Check if location services are enabled
      final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled) {
        if (mounted) {
          setState(() {
            _error = 'Location services are disabled';
            _isLoading = false;
          });
        }
        return;
      }

      // Ensure we have location permission using DeviceServices
      final perm = await DeviceServices.ensureLocationPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _error = perm == LocationPermission.deniedForever 
                ? 'Location permission permanently denied. Please enable it in settings.'
                : 'Location permission denied';
            _isPermissionDenied = true;
            _isLoading = false;
          });
        }
        return;
      }
      
      _isPermissionDenied = false;

      // Get current position using DeviceServices (has better error handling)
      Position? position;
      try {
        position = await DeviceServices.getPosition();
      } catch (e) {
        // If getting current position fails, try last known position as fallback
        try {
          position = await Geolocator.getLastKnownPosition();
          if (position == null) {
            rethrow; // Re-throw original error if no last known position
          }
        } catch (_) {
          rethrow; // Re-throw original error
        }
      }
      
      if (position == null) {
        throw Exception('No location data available');
      }
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
          _isPermissionDenied = false;
        });
        // Center map on location after it's loaded
        // Use a small delay to ensure map is rendered
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            try {
              _mapController.move(LatLng(position!.latitude, position!.longitude), 17.0);
            } catch (_) {
              // Map controller might not be ready yet, will center on next build
            }
          }
        });
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Location request timed out. Please ensure location services are enabled and try again.';
          _isLoading = false;
        });
      }
    } on LocationServiceDisabledException catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Location services are disabled. Please enable them in settings.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        // Clean up error message
        errorMsg = errorMsg.replaceAll('Exception: ', '');
        errorMsg = errorMsg.replaceAll('Failed to get location: ', '');
        
        // Provide helpful message for common issues
        if (errorMsg.contains('timeout') || errorMsg.contains('Timeout')) {
          errorMsg = 'Location request timed out. If using an emulator, please set a location in the emulator settings.';
        } else if (errorMsg.contains('permission') || errorMsg.contains('Permission')) {
          errorMsg = 'Location permission is required. Please grant location permission.';
        } else if (errorMsg.isEmpty || errorMsg == 'null') {
          errorMsg = 'Unable to get location. Please ensure location services are enabled.';
        }
        
        setState(() {
          _error = errorMsg;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey[100],
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_error != null || _currentPosition == null) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey[100],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    _error ?? 'Location unavailable',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isPermissionDenied)
                        TextButton.icon(
                          onPressed: () async {
                            await DeviceServices.openLocationSettings();
                          },
                          icon: const Icon(Icons.settings, size: 18),
                          label: const Text('Settings'),
                        ),
                      if (_isPermissionDenied) const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _fetchLocation,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;
    final accuracy = _currentPosition!.accuracy;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 180,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(lat, lng),
                  initialZoom: 17.0,
                  minZoom: 17.0,
                  maxZoom: 17.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none, // Completely disable all interactions
                  ),
                  onMapReady: () {
                    // Ensure map centers on location when ready
                    _mapController.move(LatLng(lat, lng), 17.0);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.alkhora.alkhora_ess',
                    maxZoom: 19,
                  ),
                  // Accuracy circle - show location accuracy radius (only if reasonable)
                  if (accuracy > 0 && accuracy < 100)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(lat, lng),
                          // At zoom 17: ~1 meter = 0.119 pixels, clamp to reasonable size
                          radius: (accuracy * 0.119).clamp(10.0, 50.0),
                          color: const Color(0xFF1C4CA5).withOpacity(0.15),
                          borderColor: const Color(0xFF1C4CA5).withOpacity(0.3),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(lat, lng),
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C4CA5),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  elevation: 2,
                  child: IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _fetchLocation,
                    color: const Color(0xFF1C4CA5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

