// =========================================================================
// Nominatim Service - OpenStreetMap Geocoding
// =========================================================================
// Purpose: Free geocoding service for location search (no API key required)
// API: https://nominatim.openstreetmap.org/search
// Rate Limit: Max 1 request/second (handled with debounce in UI)
// =========================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Represents a location result from Nominatim API
class NominatimPlace {
  final String placeId;
  final String displayName;
  final double lat;
  final double lon;
  final String? type;
  final String? addressType;

  NominatimPlace({
    required this.placeId,
    required this.displayName,
    required this.lat,
    required this.lon,
    this.type,
    this.addressType,
  });

  factory NominatimPlace.fromJson(Map<String, dynamic> json) {
    return NominatimPlace(
      placeId: json['place_id'].toString(),
      displayName: json['display_name'] as String,
      lat: double.parse(json['lat'] as String),
      lon: double.parse(json['lon'] as String),
      type: json['type'] as String?,
      addressType: json['addresstype'] as String?,
    );
  }

  /// Get a shorter name (first part before comma)
  String get shortName {
    final parts = displayName.split(',');
    if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return displayName;
  }

  /// Get address (everything after the first two parts)
  String? get address {
    final parts = displayName.split(',');
    if (parts.length > 2) {
      return parts.sublist(2).join(',').trim();
    }
    return null;
  }
}

/// Service for searching locations using OpenStreetMap Nominatim API
class NominatimService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent =
      'Nova School Events App (contact@galileimoro.edu.it)';

  final http.Client _client;

  NominatimService({http.Client? client}) : _client = client ?? http.Client();

  /// Search for places matching the query
  ///
  /// [query] - Search text (e.g., "Piazza Duomo Milano")
  /// [limit] - Maximum number of results (default 5)
  /// [countryCode] - Limit to specific country (default "it" for Italy)
  Future<List<NominatimPlace>> search(
    String query, {
    int limit = 5,
    String countryCode = 'it',
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final uri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': limit.toString(),
          'countrycodes': countryCode,
          'addressdetails': '1',
        },
      );

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => NominatimPlace.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Reverse geocode coordinates to get place name
  ///
  /// [lat] - Latitude
  /// [lon] - Longitude
  Future<NominatimPlace?> reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse('$_baseUrl/reverse').replace(
        queryParameters: {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'format': 'json',
        },
      );

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['place_id'] != null) {
          return NominatimPlace.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}
