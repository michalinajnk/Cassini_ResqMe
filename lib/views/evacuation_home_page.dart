import 'dart:convert';
import 'package:cassini_hackathon/services/DataFetcher.dart';
import 'package:cassini_hackathon/services/DataSender.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:http/http.dart' as http;

class EvacuationHomePage extends StatefulWidget {
  final double inDangerRay;
  final bool allowBackgroundNotifications;

  EvacuationHomePage({
    required this.inDangerRay,
    required this.allowBackgroundNotifications,
  });

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
  String _travelMode = "driving";
  late DataSender _dataSender;
  late DataFetcher _dataFetcher;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupBackgroundNotifications();
    _initLocationService();
  }

  /// Initialize services for communication with the server
  void _initializeServices() {
    final String baseUrl = "http://10.0.2.2:5000";; // Local Flask server
    _dataSender = DataSender(baseUrl);
    _dataFetcher = DataFetcher(baseUrl);
  }

  /// Handle background notifications setup
  Future<void> _setupBackgroundNotifications() async {
    if (widget.allowBackgroundNotifications) {
      print("Background notifications enabled for ${widget.inDangerRay} meters.");
    }
  }

  /// Initialize location services and fetch user location
  Future<void> _initLocationService() async {
    bool serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception("Location services are disabled.");

    geolocator.LocationPermission permission = await geolocator.Geolocator.checkPermission();
    if (permission == geolocator.LocationPermission.denied) {
      permission = await geolocator.Geolocator.requestPermission();
      if (permission == geolocator.LocationPermission.denied) {
        throw Exception("Location permissions are denied.");
      }
    }

    if (permission == geolocator.LocationPermission.deniedForever) {
      throw Exception("Location permissions are permanently denied.");
    }

    geolocator.Position position = await geolocator.Geolocator.getCurrentPosition(
      locationSettings: geolocator.LocationSettings(accuracy: geolocator.LocationAccuracy.high),
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

  /// Handles the destination selection process
  Future<void> _onDestinationSet() async {
    if (_currentPosition == null || _destinationPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please set both your current location and destination.")),
      );
      return;
    }

    try {
      // Send user location and target to the server
      await _dataSender.sendUserLocationAndTarget(_currentPosition!, _destinationPosition!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Location and target sent to the server.")));

      // Fetch processed data from the server
      final data = await _dataFetcher.fetchProcessedData();

      // Process the response
      final List<dynamic> route = data["path"];
      final List<dynamic> dangerZones = data["danger_zone"];

      // Convert route to polyline
      final polylinePoints = route.map((point) => LatLng(point[1], point[0])).toList();

      // Convert danger zones to polygons
      final dangerZonePolygons = dangerZones.map((zone) {
        final points = (zone as List).map((point) => LatLng(point[1], point[0])).toList();
        return Polygon(
          polygonId: PolygonId(zone.hashCode.toString()),
          points: points,
          fillColor: Colors.red.withOpacity(0.3),
          strokeColor: Colors.red,
          strokeWidth: 2,
        );
      }).toSet();

      setState(() {
        _routePolyline = Polyline(
          polylineId: PolylineId("route"),
          points: polylinePoints,
          color: Colors.blue,
          width: 4,
        );
        _dangerZonePolygons = dangerZonePolygons;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching data: $e")),
      );
    }
  }

  /// Fetch destination from a map tap and trigger the process
  Future<void> _setDestinationFromTap(LatLng tappedPosition) async {
    setState(() => _destinationPosition = tappedPosition);
    _onDestinationSet(); // Send data to the server and fetch results
  }

  /// Build Google Map Widget
  Widget _buildGoogleMap() {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) => _mapController = controller,
      polygons: _dangerZonePolygons,
      markers: _markers,
      polylines: _routePolyline != null ? {_routePolyline!} : {},
      initialCameraPosition: CameraPosition(
        target: _currentPosition ?? LatLng(0, 0),
        zoom: 14,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      onTap: _setDestinationFromTap,
    );
  }

  /// Build Search Bar
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
              hintText: "Enter destination",
              suffixIcon: IconButton(
                icon: Icon(Icons.search),
                onPressed: () {
                  // Simulate setting a destination from a search
                  _destinationPosition = LatLng(50.6927, 17.6206); // Replace with actual API result
                  _onDestinationSet();
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
