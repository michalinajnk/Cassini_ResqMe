import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Finds the shortest path from start to end avoiding danger zones
List<LatLng> findSafeRoute(
    LatLng start, LatLng end, List<List<LatLng>> dangerZones) {
  List<LatLng> route = [start]; // Start with the starting point

  // Basic implementation: Avoiding danger zones using waypoints
  LatLng waypoint = LatLng(
    start.latitude + (end.latitude - start.latitude) / 2,
    start.longitude + (end.longitude - start.longitude) / 2,
  );

  // Adjust waypoint to avoid danger zones
  bool intersects = dangerZones.any((polygon) => _isPointInsidePolygon(waypoint, polygon));
  if (intersects) {
    waypoint = LatLng(waypoint.latitude + 0.01, waypoint.longitude + 0.01);
  }

  route.add(waypoint);
  route.add(end);

  return route;
}

/// Checks if a point is inside a polygon
bool _isPointInsidePolygon(LatLng point, List<LatLng> polygonPoints) {
  int i, j;
  bool isInside = false;
  for ((i = 0, j = polygonPoints.length - 1); i < polygonPoints.length; j = i++) {
    if ((polygonPoints[i].longitude > point.longitude) !=
        (polygonPoints[j].longitude > point.longitude) &&
        (point.latitude <
            (polygonPoints[j].latitude - polygonPoints[i].latitude) *
                (point.longitude - polygonPoints[i].longitude) /
                (polygonPoints[j].longitude - polygonPoints[i].longitude) +
                polygonPoints[i].latitude)) {
      isInside = !isInside;
    }
  }
  return isInside;
}


