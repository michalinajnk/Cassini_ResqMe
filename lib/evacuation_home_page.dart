import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:http/http.dart' as http;

import 'mock_helper/generate_danger_zones.dart';
import 'mock_helper/get_route.dart';

class EvacuationHomePage extends StatefulWidget {
  @override
  _EvacuationHomePageState createState() => _EvacuationHomePageState();
}

class _EvacuationHomePageState extends State<EvacuationHomePage> {
  GoogleMapController? _mapController;
  Set<Polygon> _dangerZonePolygons = {};
  Set<Marker> _markers = {};
  LatLng? _currentPosition;
  LatLng? _destinationPosition;
  Polyline? _routePolyline;
  TextEditingController _destinationController = TextEditingController();

  final String _googleApiKey = 'AIzaSyAtuucM4ZmPmcqZiYwGZUpme_h5CYsXVD0';

  @override
  void initState() {
    super.initState();
    _initLocationService();
    _loadDangerZonesFromJson();
  }

  Future<void> _initLocationService() async {
    bool serviceEnabled;
    geolocator.LocationPermission permission;

    serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await geolocator.Geolocator.checkPermission();
    if (permission == geolocator.LocationPermission.denied) {
      permission = await geolocator.Geolocator.requestPermission();
      if (permission == geolocator.LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == geolocator.LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, cannot request.');
    }

    geolocator.Position position = await geolocator.Geolocator.getCurrentPosition(
      locationSettings: geolocator.LocationSettings(
        accuracy: geolocator.LocationAccuracy.high,
      ),
    );

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _markers.add(Marker(
        markerId: MarkerId("current_location"),
        position: _currentPosition!,
        infoWindow: InfoWindow(title: "Your Location"),
      ));
    });
  }

  Future<void> _loadDangerZonesFromJson() async {
    try {
      // Load danger zones from JSON
      //String jsonString = await rootBundle.loadString('C:/Users/MichalinaJanik/AndroidStudioProjects/cassini_hackathon/data/danger_zones.json');
      //List<dynamic> data = json.decode(jsonString);

      Set<Polygon> polygons = getDangerZonePolygons(_currentPosition!); //{}
      setState(() {
        _dangerZonePolygons = polygons;
      });
    }catch (e)
      {
          print("Error loading danger zones: $e");
      }
  }
    //  for (var zone in data) {
    //  List<LatLng> coordinates = (zone['coordinates'] as List)
    //   .map((point) => LatLng(point['lat'], point['lng']))
    //   .toList();

    //polygons.add(
    //Polygon(
    //polygonId: PolygonId(zone['id']),
    //points: coordinates,
    //fillColor: Colors.red.withOpacity(0.3),
    //strokeColor: Colors.red,
    //  strokeWidth: 2,
    //  ),
    //  );
    //}

    //setState(() {
    //    _dangerZonePolygons = polygons;
    //   });
    //  } catch (e) {
    //    print("Error loading danger zones: $e");
    //  }
    // }

  Future<void> _setDestinationFromTap(LatLng tappedPosition) async {
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${tappedPosition.latitude},${tappedPosition.longitude}&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['results'][0]['formatted_address'];

        setState(() {
          _destinationPosition = tappedPosition;
          _markers.add(Marker(
            markerId: MarkerId("destination"),
            position: _destinationPosition!,
            infoWindow: InfoWindow(title: address),
          ));
        });

        await _fetchRoute(_currentPosition!, _destinationPosition!);
      }
    } catch (e) {
      print("Error setting destination from tap: $e");
    }
  }

  Future<void> _setDestinationFromSearch(String destination) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=$destination&inputtype=textquery&fields=geometry,formatted_address&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final location = data['candidates'][0]['geometry']['location'];
        final address = data['candidates'][0]['formatted_address'];

        setState(() {
          _destinationPosition =
              LatLng(location['lat'], location['lng']); // Destination coordinates
          _markers.add(Marker(
            markerId: MarkerId("destination"),
            position: _destinationPosition!,
            infoWindow: InfoWindow(title: address),
          ));
        });

        await _fetchRoute(_currentPosition!, _destinationPosition!);
      }
    } catch (e) {
      print("Error setting destination: $e");
    }
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {

    // From the output from guys
    List<LatLng> simulatedRoute = findSafeRoutePolygons(start, end, _dangerZonePolygons);

    setState(() {
      _routePolyline = Polyline(
        polylineId: PolylineId("route"),
        points: simulatedRoute,
        color: Colors.blue,
        width: 4,
      );
    });
  }

  Widget _buildGoogleMap() {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
      polygons: _dangerZonePolygons,
      markers: _markers,
      polylines: _routePolyline != null ? {_routePolyline!} : {},
      initialCameraPosition: CameraPosition(
        target: _currentPosition ?? LatLng(0, 0),
        zoom: 14,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      onTap: (LatLng position) {
        _setDestinationFromTap(position); // Set destination from tap
      },
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: TextField(
            controller: _destinationController,
            decoration: InputDecoration(
              hintText: 'Enter destination',
              suffixIcon: IconButton(
                icon: Icon(Icons.search),
                onPressed: () {
                  _setDestinationFromSearch(_destinationController.text.trim());
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ResQMe'),
        backgroundColor: Colors.black12,
      ),
      body: Stack(
        children: [
          _currentPosition == null
              ? Center(child: CircularProgressIndicator())
              : _buildGoogleMap(),
          _buildSearchBar(),
        ],
      ),
    );
  }
}
