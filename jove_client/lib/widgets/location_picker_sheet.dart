import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../theme/app_theme_controller.dart';

/// Amazon-style location selection bottom sheet.
/// Shows "Use Current Location" or "Search Manually" options.
/// Saves the selected location to Firestore and calls [onLocationSelected].
class LocationPickerSheet extends StatefulWidget {
  final VoidCallback? onLocationSelected;

  const LocationPickerSheet({super.key, this.onLocationSelected});

  /// Shows the location picker as a bottom sheet. Returns true if a location was selected.
  static Future<bool> show(BuildContext context, {VoidCallback? onLocationSelected}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LocationPickerSheet(onLocationSelected: onLocationSelected),
    );
    return result ?? false;
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  static const String _mapsApiKey = 'AIzaSyBLYE2YyC-8ba229aNxHC1BjkIRHkaZVnA';

  static const Color _navBgColor = Color(0xFF00215F);
  static const Color _iconBg = Color(0xFFF0F2F5);
  static const Color _textMain = Color(0xFF1A1A1A);

  bool _isLoading = false;
  String? _errorMessage;

  bool get _isDark => AppThemeController.isDark;

  Future<void> _useCurrentLocation() async {
    HapticFeedback.selectionClick();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied. Enable in Settings.');
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        final locTitle = place.locality ?? place.subLocality ?? 'Current Location';
        final locAddr =
            '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.administrativeArea ?? ''}'
                .trim()
                .replaceAll(RegExp(r'^,\s*|,\s*$|,(?=\s*,)'), '');

        await _saveLocationToFirestore(
          title: locTitle,
          address: locAddr,
          lat: position.latitude,
          lng: position.longitude,
        );

        if (mounted) {
          widget.onLocationSelected?.call();
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _searchManually() async {
    HapticFeedback.selectionClick();

    Prediction? p = await PlacesAutocomplete.show(
      context: context,
      apiKey: _mapsApiKey,
      mode: Mode.overlay,
      language: "en",
      components: [Component(Component.country, "in")],
    );

    if (p != null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final places = GoogleMapsPlaces(apiKey: _mapsApiKey);
        PlacesDetailsResponse detail = await places.getDetailsByPlaceId(p.placeId!);

        if (detail.result.geometry != null) {
          final lat = detail.result.geometry!.location.lat;
          final lng = detail.result.geometry!.location.lng;
          final title = p.structuredFormatting?.mainText ?? 'Selected Location';
          final address = p.description ?? '';

          await _saveLocationToFirestore(
            title: title,
            address: address,
            lat: lat,
            lng: lng,
          );

          if (mounted) {
            widget.onLocationSelected?.call();
            Navigator.pop(context, true);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to get location details.';
          });
        }
      }
    }
  }

  Future<void> _saveLocationToFirestore({
    required String title,
    required String address,
    required double lat,
    required double lng,
  }) async {
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (userUid != null && userUid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(userUid).set({
        'location': address.isNotEmpty ? address : title,
        'address': address,
        'city': title,
        'currentLocation': {
          'address': address,
          'title': title,
          'lat': lat,
          'lng': lng,
        },
        'lat': lat,
        'lng': lng,
        'latitude': lat,
        'longitude': lng,
        'hasSetLocation': true,
        'lastLocationUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDark;
    final Color cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textMain = isDark ? const Color(0xFFF5F5F5) : _textMain;
    final Color subText = isDark ? const Color(0xFFA8A8A8) : Colors.grey.shade600;
    final Color accentColor = isDark ? const Color(0xFF3B82F6) : _navBgColor;
    final Color dividerColor = isDark ? const Color(0xFF262626) : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF333333) : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.location_on_rounded, color: accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Your Location',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textMain,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'We need your location for home fitness sessions',
                        style: TextStyle(
                          fontSize: 13,
                          color: subText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade400, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_errorMessage != null) const SizedBox(height: 16),

          // Option 1: Use Current Location
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: InkWell(
              onTap: _isLoading ? null : _useCurrentLocation,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : _iconBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: dividerColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: accentColor,
                              ),
                            )
                          : Icon(Icons.my_location_rounded, color: accentColor, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Use Current Location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textMain,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Auto-detect using GPS',
                            style: TextStyle(fontSize: 13, color: subText),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: subText, size: 22),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Option 2: Search Manually
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: InkWell(
              onTap: _isLoading ? null : _searchManually,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : _iconBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: dividerColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.search_rounded, color: Colors.orange, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter Location Manually',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textMain,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Search for your address',
                            style: TextStyle(fontSize: 13, color: subText),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: subText, size: 22),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: 24 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
