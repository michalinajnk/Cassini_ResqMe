import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MockedEvacuationHomePage extends StatefulWidget {
  final String filePath; // Path to the mock route file

  MockedEvacuationHomePage({required this.filePath});

  @override
  _MockedEvacuationHomePageState createState() =>
      _MockedEvacuationHomePageState();
}

class _MockedEvacuationHomePageState extends State<MockedEvacuationHomePage>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Polyline? _routePolyline;
  LatLng? _currentPosition;
  LatLng? _destinationPosition;
  bool _showNotification = false;

  @override
  void initState() {
    super.initState();
    _loadMockedRoute();
  }

  /// Load route data from the mock file
  Future<void> _loadMockedRoute() async {
    try {
      final fileData = await _readFile(widget.filePath);
      final routePoints = _parseRoute(fileData);

      if (routePoints.isNotEmpty) {
        setState(() {
          _currentPosition = routePoints.first; // First point as start
          _destinationPosition = routePoints.last; // Last point as end
          _routePolyline = Polyline(
            polylineId: PolylineId("mocked_route"),
            points: routePoints,
            color: Colors.blue,
            width: 4,
          );

          // Add markers for start and end points
          _markers.add(Marker(
            markerId: MarkerId("current_location"),
            position: _currentPosition!,
            infoWindow: InfoWindow(title: "Start Point"),
          ));

          _markers.add(Marker(
            markerId: MarkerId("destination"),
            position: _destinationPosition!,
            infoWindow: InfoWindow(title: "Destination"),
          ));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load route data: $e")),
      );
    }
  }

  /// Mocked file reading
  Future<String> _readFile(String path) async {
    // Replace this with actual file reading if necessary
    // Simulated file content for the example
    return """
      [
        [40.92619, 26.17145],
        [40.92636, 26.17167],
        [40.92651, 26.17187],
        [40.85712, 25.93447]
      ]
    """;
  }

  /// Parse route data into a list of LatLng points
  List<LatLng> _parseRoute(String fileData) {
    final List<dynamic> rawPoints = json.decode(fileData);
    return rawPoints
        .map((point) => LatLng(point[0], point[1]))
        .toList();
  }

  /// Build Google Map Widget
  Widget _buildGoogleMap() {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
      markers: _markers,
      polylines: _routePolyline != null ? {_routePolyline!} : {},
      initialCameraPosition: CameraPosition(
        target: _currentPosition ?? LatLng(0, 0),
        zoom: 14,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
    );
  }

  /// Notification Widget for Navigation Availability
  Widget _buildNavigationNotification() {
    return AnimatedOpacity(
      opacity: _showNotification ? 1.0 : 0.0, // Toggle opacity
      duration: Duration(milliseconds: 500), // Fade animation duration
      child: Positioned(
        top: 10.0,
        left: 16.0,
        right: 16.0,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4.0,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            "Navigation available! Tap the button to start.",
            style: TextStyle(color: Colors.deepPurple, fontSize: 16.0),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  /// Floating Action Button (FAB)
  Widget _buildFAB(IconData icon, String tooltip, VoidCallback onPressed,
      Color color, String heroTag) {
    return Center(
      child: SizedBox(
        width: 50.0, // Fixed width
        height: 50.0, // Fixed height
        child: FloatingActionButton(
          onPressed: onPressed,
          child: Icon(icon),
          backgroundColor: color,
          heroTag: heroTag,
          tooltip: tooltip,
        ),
      ),
    );
  }

  /// Floating Action Button Layout
  Widget _buildFABLayout() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFAB(
              Icons.warning_amber_outlined,
              "Need Help",
              () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Help notification sent.")),
              ),
              Colors.red,
              "helpButton",
            ),
            SizedBox(height: 10.0),
            _buildFAB(
              Icons.my_location,
              "Go to My Location",
              _centerMapOnCurrentLocation,
              Colors.blue,
              "currentLocationButton",
            ),
            SizedBox(height: 10.0),
            _buildFAB(
              Icons.settings,
              "Go to Settings",
              () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Settings button clicked.")),
              ),
              Colors.blue,
              "settingsButton",
            ),
          ],
        ),
      ),
    );
  }

  /// Center the map on the current location
  void _centerMapOnCurrentLocation() {
    if (_currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_currentPosition!),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Current location not available")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mocked Evacuation Route'),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          _buildGoogleMap(),
          if (_showNotification) _buildNavigationNotification(),
          _buildFABLayout(),
        ],
      ),
    );
  }
}
