import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Generates a JSON file with 3 non-intersecting danger zones
Future<void> generateDangerZonesJson(LatLng currentLocation, String filePath) async {
  Random random = Random();
  List<Map<String, dynamic>> dangerZones = [];

  for (int i = 0; i < 3; i++) {
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
      dangerZones.add({
        "id": "zone_${i + 1}",
        "name": "Danger Zone ${i + 1}",
        "coordinates": coordinates,
      });
    } else {
      i--; // Retry if intersection occurs
    }
  }

  // Save the danger zones to a JSON file
  String jsonString = json.encode(dangerZones);
  File file = File(filePath);
  await file.writeAsString(jsonString);
  print("Danger zones JSON file saved to $filePath");
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
