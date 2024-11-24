import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Generates a JSON file with 3 non-intersecting danger zones
Set<Polygon> getDangerZonePolygons(LatLng currentLocation, double inDangerRay) {
  // Get danger zones as a List<Map<String, dynamic>>
  List<Map<String, dynamic>> dangerZones = getDangerZonesWithinRay(currentLocation, inDangerRay);

  // Convert each zone into a Polygon
  return dangerZones.map((zone) {
    List<LatLng> coordinates = (zone['coordinates'] as List)
        .map((point) => LatLng(point['lat'], point['lng']))
        .toList();

    return Polygon(
      polygonId: PolygonId(zone['id']),
      points: coordinates,
      fillColor: Colors.red.withOpacity(0.3),
      strokeColor: Colors.red,
      strokeWidth: 2,
    );
  }).toSet(); // Convert the Iterable to a Set
}

/// Filters danger zones within a given radius (inDangerRay) from the current location
List<Map<String, dynamic>> getDangerZonesWithinRay(LatLng currentLocation, double inDangerRay) {
  Random random = Random();
  List<Map<String, dynamic>> dangerZones = [];

  for (int i = 0; i < 6; i++) {
    // Generate random offsets for the polygon vertices, ensuring non-intersection
    double baseLat = currentLocation.latitude + (random.nextDouble() * 0.01) - 0.005;
    double baseLng = currentLocation.longitude + (random.nextDouble() * 0.01) - 0.005;

    // Create a square polygon around the base point
    List<Map<String, double>> coordinates = [
      {"lat": baseLat, "lng": baseLng},
      {"lat": baseLat + 0.002, "lng": baseLng},
      {"lat": baseLat + 0.002, "lng": baseLng + 0.002},
      {"lat": baseLat, "lng": baseLng + 0.002},
    ];

    // Ensure no intersection with existing polygons
    bool intersects = dangerZones.any((zone) {
      return _doesPolygonIntersect(coordinates, zone['coordinates']);
    });

    if (!intersects) {
      double centerLat = baseLat + 0.001;
      double centerLng = baseLng + 0.001;
      double distance = _calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        centerLat,
        centerLng,
      );

      // Only add zones within the inDangerRay
      if (distance <= inDangerRay) {
        dangerZones.add({
          "id": "zone_${i + 1}",
          "name": "Danger Zone ${i + 1}",
          "coordinates": coordinates,
        });
      } else {
        i--; // Retry if the zone is out of range
      }
    } else {
      i--; // Retry if intersection occurs
    }
  }
  return dangerZones;
}

/// Saves the filtered danger zones to a JSON file
Future<void> generateDangerZonesJson(LatLng currentLocation, String filePath, double inDangerRay) async {
  List<Map<String, dynamic>> dangerZones = getDangerZonesWithinRay(currentLocation, inDangerRay);

  // Save the danger zones to a JSON file
  String jsonString = json.encode(dangerZones);
  File file = File(filePath);
  await file.writeAsString(jsonString);
}

/// Checks if two polygons intersect
bool _doesPolygonIntersect(List<Map<String, double>> polygon1, List<dynamic> polygon2) {
  List<LatLng> poly1 = polygon1.map((p) => LatLng(p['lat']!, p['lng']!)).toList();
  List<LatLng> poly2 = polygon2.map((p) => LatLng(p['lat'], p['lng'])).toList();

  for (int i = 0; i < poly1.length; i++) {
    for (int j = 0; j < poly2.length; j++) {
      LatLng a1 = poly1[i];
      LatLng a2 = poly1[(i + 1) % poly1.length];
      LatLng b1 = poly2[j];
      LatLng b2 = poly2[(j + 1) % poly2.length];

      if (_doLinesIntersect(a1, a2, b1, b2)) return true;
    }
  }
  return false;
}

/// Checks if two line segments intersect
bool _doLinesIntersect(LatLng a1, LatLng a2, LatLng b1, LatLng b2) {
  int orientation(LatLng p, LatLng q, LatLng r) {
    double val = (q.longitude - p.longitude) * (r.latitude - q.latitude) -
        (q.latitude - p.latitude) * (r.longitude - q.longitude);
    if (val == 0) return 0; // Collinear
    return (val > 0) ? 1 : 2; // Clockwise or Counterclockwise
  }

  bool onSegment(LatLng p, LatLng q, LatLng r) {
    return q.latitude <= max(p.latitude, r.latitude) &&
        q.latitude >= min(p.latitude, r.latitude) &&
        q.longitude <= max(p.longitude, r.longitude) &&
        q.longitude >= min(p.longitude, r.longitude);
  }

  int o1 = orientation(a1, a2, b1);
  int o2 = orientation(a1, a2, b2);
  int o3 = orientation(b1, b2, a1);
  int o4 = orientation(b1, b2, a2);

  // General case
  if (o1 != o2 && o3 != o4) return true;

  // Special cases
  if (o1 == 0 && onSegment(a1, b1, a2)) return true;
  if (o2 == 0 && onSegment(a1, b2, a2)) return true;
  if (o3 == 0 && onSegment(b1, a1, b2)) return true;
  if (o4 == 0 && onSegment(b1, a2, b2)) return true;

  return false;
}

/// Calculates the distance (in meters) between two points
double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
  const double earthRadius = 6371000; // in meters
  double dLat = _toRadians(lat2 - lat1);
  double dLng = _toRadians(lng2 - lng1);

  double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadius * c;
}

double _toRadians(double degrees) {
  return degrees * pi / 180;
}
