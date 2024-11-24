
import 'package:google_maps_flutter/google_maps_flutter.dart';


import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';



/// Converts a List<List<double>> into a List<LatLng>
List<LatLng> convertToLatLng(List<List<double>> routeSegments) {
  return routeSegments.map((coords) {
    if (coords.length == 2) {
      return LatLng(coords[0], coords[1]);
    } else {
      throw Exception('Invalid coordinate format: Each point must have exactly 2 elements');
    }
  }).toList();
}

// Fetches the route as a polyline from the Google Directions API
Future<List<LatLng>> getActualRoutePolyline(
    List<LatLng> routePoints, String travelMode, String apiKey) async {
  List<LatLng> finalPolylinePoints = [];

  for (int i = 0; i < routePoints.length - 1; i++) {
    LatLng start = routePoints[i];
    LatLng end = routePoints[i + 1];

    String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&mode=$travelMode&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          String polyline = data['routes'][0]['overview_polyline']['points'];
          finalPolylinePoints.addAll(_decodePolyline(polyline));
        } else {
          print("No route found for segment: $start -> $end");
        }
      } else {
        print("Failed to fetch route segment: ${response.body}");
      }
    } catch (e) {
      print("Error fetching route segment: $e");
    }
  }

  return finalPolylinePoints;
}

/// Decodes a polyline string into a list of LatLng points
List<LatLng> _decodePolyline(String encoded) {
  List<LatLng> polyline = [];
  int index = 0, len = encoded.length;
  int lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    polyline.add(LatLng(lat / 1E5, lng / 1E5));
  }
  return polyline;
}


/// Finds the shortest path from start to end avoiding POLYGONS
List<LatLng> findSafeRoutePolygons(LatLng start, LatLng end, Set<Polygon> dangerZones) {
  List<LatLng> route = [start]; // Start with the starting point

//Avoiding danger zones using waypoints
  LatLng waypoint = LatLng(
    start.latitude + (end.latitude - start.latitude) / 2,
    start.longitude + (end.longitude - start.longitude) / 2,
  );

  // Adjust waypoint LOC to avoid danger zones
  bool intersects = dangerZones.any((polygon) => _isPointInsidePolygon(waypoint, polygon.points));
  if (intersects) {
    waypoint = LatLng(waypoint.latitude + 0.01, waypoint.longitude + 0.01);
  }

  route.add(waypoint);
  route.add(end);

  return route;
}



/// Finds the shortest path from start to end avoiding danger zones
List<LatLng> findSafeRoute(
    LatLng start, LatLng end, List<List<LatLng>> dangerZones) {
  List<LatLng> route = [start]; // Start with the starting point

  LatLng waypoint = LatLng(
    start.latitude + (end.latitude - start.latitude) / 2,
    start.longitude + (end.longitude - start.longitude) / 2,
  );

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


