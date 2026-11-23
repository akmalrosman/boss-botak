import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../data/backend.dart';

class GeoPlace {
  const GeoPlace({required this.address, required this.lat, required this.lng});
  final String address;
  final double lat;
  final double lng;
}

/// Location features:
/// * device GPS through `geolocator`, with runtime permission handling
/// * geocoding through the public OpenStreetMap **Nominatim** API (HTTPS)
///   - reverse: GPS coordinates -> readable delivery address
///   - search:  typed address -> coordinates (to compute delivery fee)
class LocationService {
  LocationService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  static const _host = 'nominatim.openstreetmap.org';

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Accept-Language': 'en,ms',
        // Nominatim's usage policy asks apps to identify themselves.
        // Browsers do not allow setting User-Agent, so skip it on web.
        if (!kIsWeb) 'User-Agent': 'BossBotakApp/1.0 (Flutter student project)',
      };

  /// Asks for location permission (if needed) and returns the current position.
  Future<({double lat, double lng})> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppException('Location is turned off. Please enable GPS and try again.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const AppException(
          'Location permission was denied. You can type your address instead.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const AppException(
          'Location permission is blocked. Enable it in your phone Settings > Apps > Boss Botak.');
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return (lat: last.latitude, lng: last.longitude);
      throw const AppException('Could not get your location. Please try again outdoors.');
    }
  }

  Future<GeoPlace> reverseGeocode(double lat, double lng) async {
    final uri = Uri.https(_host, '/reverse', {
      'format': 'jsonv2',
      'lat': '$lat',
      'lon': '$lng',
      'addressdetails': '1',
      'zoom': '18',
    });
    final data = await _get(uri) as Map<String, dynamic>;
    if (data['error'] != null) {
      throw const AppException('No address found for this location.');
    }
    return GeoPlace(address: _format(data), lat: lat, lng: lng);
  }

  Future<List<GeoPlace>> search(String query) async {
    if (query.trim().length < 3) return [];
    final uri = Uri.https(_host, '/search', {
      'format': 'jsonv2',
      'q': query.trim(),
      'countrycodes': 'my',
      'addressdetails': '1',
      'limit': '5',
    });
    final list = await _get(uri) as List<dynamic>;
    return [
      for (final e in list.cast<Map<String, dynamic>>())
        GeoPlace(
          address: _format(e),
          lat: double.parse(e['lat'] as String),
          lng: double.parse(e['lon'] as String),
        ),
    ];
  }

  Future<dynamic> _get(Uri uri) async {
    assert(uri.scheme == 'https');
    try {
      final res = await _http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw AppException('Address service error (${res.statusCode}).');
      }
      return jsonDecode(utf8.decode(res.bodyBytes));
    } on TimeoutException {
      throw const AppException('Address service is not responding.');
    } on AppException {
      rethrow;
    } catch (_) {
      throw const AppException('Cannot reach the address service. Check your internet.');
    }
  }

  /// Builds a short, readable Malaysian address from Nominatim's fields.
  static String _format(Map<String, dynamic> data) {
    final a = (data['address'] as Map?)?.cast<String, dynamic>() ?? {};
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = a[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    final parts = <String?>[
      [a['house_number'], a['road']].whereType<String>().join(' ').trim(),
      pick(['neighbourhood', 'suburb', 'residential', 'quarter', 'village']),
      [a['postcode'], pick(['city', 'town', 'municipality', 'county'])]
          .whereType<String>()
          .join(' '),
      a['state'] as String?,
    ].where((p) => p != null && p.isNotEmpty).toList();
    final text = parts.join(', ');
    return text.isNotEmpty ? text : (data['display_name'] as String? ?? '');
  }
}
