import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceResult {
  final String displayName;
  final double? latitude;
  final double? longitude;
  final String? area;
  final String? city;

  const PlaceResult({
    required this.displayName,
    this.latitude,
    this.longitude,
    this.area,
    this.city,
  });

  factory PlaceResult.fromNominatim(Map<String, dynamic> json) {
    final address = (json['address'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    String? firstNonEmpty(List<String> keys) {
      for (final key in keys) {
        final value = address[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    return PlaceResult(
      displayName: json['display_name']?.toString() ?? 'بلاصة',
      latitude: double.tryParse(json['lat']?.toString() ?? ''),
      longitude: double.tryParse(json['lon']?.toString() ?? ''),
      area: firstNonEmpty(const ['suburb', 'neighbourhood', 'quarter', 'village', 'town']),
      city: firstNonEmpty(const ['city', 'municipality', 'county', 'state']),
    );
  }
}

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
  const RouteResult(this.points, this.distanceKm, this.durationMinutes);
}

class RouteService {
  static const _nominatimAgent = 'LEF_LEF/1.0 (place search)';

  static bool _validPoint(LatLng point) =>
      point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.latitude >= -90 &&
      point.latitude <= 90 &&
      point.longitude >= -180 &&
      point.longitude <= 180;

  static Future<List<PlaceResult>> searchPlaces(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '8',
      'accept-language': 'ar,fr,en',
      'countrycodes': 'tn',
    });

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'User-Agent': _nominatimAgent,
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('place_search_${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw const FormatException('invalid_place_search_response');

    return decoded
        .whereType<Map>()
        .map((item) => PlaceResult.fromNominatim(item.cast<String, dynamic>()))
        .where((place) {
          final lat = place.latitude;
          final lon = place.longitude;
          return lat != null &&
              lon != null &&
              lat.isFinite &&
              lon.isFinite &&
              lat >= -90 &&
              lat <= 90 &&
              lon >= -180 &&
              lon <= 180 &&
              place.displayName.trim().isNotEmpty;
        })
        .toList(growable: false);
  }

  static Future<PlaceResult?> reverseGeocode(LatLng point) async {
    if (!_validPoint(point)) {
      throw const FormatException('invalid_coordinates');
    }
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': point.latitude.toStringAsFixed(6),
      'lon': point.longitude.toStringAsFixed(6),
      'format': 'jsonv2',
      'addressdetails': '1',
      'zoom': '18',
      'accept-language': 'ar,fr,en',
    });
    final response = await http.get(uri, headers: {
      'Accept': 'application/json',
      'User-Agent': _nominatimAgent,
    }).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('reverse_geocode_${response.statusCode}');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    return PlaceResult.fromNominatim(decoded);
  }

  static Future<RouteResult> roadRoute(LatLng from, LatLng to) async {
    if (!_validPoint(from) || !_validPoint(to)) {
      throw const FormatException('invalid_route_coordinates');
    }
    if (from.latitude == to.latitude && from.longitude == to.longitude) {
      throw const FormatException('route_points_are_identical');
    }
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson',
    );
    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw Exception('route_${response.statusCode}');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('invalid_route_response');
    }
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) {
      throw const FormatException('no_route');
    }
    final first = (routes.first as Map).cast<String, dynamic>();
    final geometryValue = first['geometry'];
    if (geometryValue is! Map || geometryValue['coordinates'] is! List) {
      throw const FormatException('invalid_route_geometry');
    }
    final rawCoordinates = geometryValue['coordinates'] as List;
    final points = <LatLng>[];
    for (final coordinate in rawCoordinates) {
      if (coordinate is! List || coordinate.length < 2 ||
          coordinate[0] is! num || coordinate[1] is! num) {
        continue;
      }
      final point = LatLng(
        (coordinate[1] as num).toDouble(),
        (coordinate[0] as num).toDouble(),
      );
      if (_validPoint(point)) points.add(point);
    }
    final distance = first['distance'];
    final duration = first['duration'];
    if (points.length < 2 || distance is! num || duration is! num ||
        !distance.isFinite || !duration.isFinite || distance <= 0 || duration < 0) {
      throw const FormatException('invalid_route_metrics');
    }
    final distanceKm = distance.toDouble() / 1000.0;
    final durationMinutes = (duration.toDouble() / 60.0).ceil();
    return RouteResult(points, distanceKm, durationMinutes);
  }
}
