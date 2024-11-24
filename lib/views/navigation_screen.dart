import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NavigationScreen extends StatefulWidget {
  final List<LatLng> routeCoordinates;

  NavigationScreen({required this.routeCoordinates});

  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? _mapController;
  int _currentStep = 0;
  bool _isNavigating = false;
  LatLng? _mockedCurrentLocation;

  void _startNavigation() {
    if (widget.routeCoordinates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No route available for navigation.")),
      );
      return;
    }

    setState(() {
      _isNavigating = true;
      _currentStep = 0;
      _mockedCurrentLocation = widget.routeCoordinates.first;
    });

    // Simulate navigation
    _navigateToNextStep();
  }

  void _navigateToNextStep() async {
    if (_currentStep >= widget.routeCoordinates.length) {
      setState(() {
        _isNavigating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You have reached your evacuation destination safely!")),
      );
      return;
    }

    LatLng nextPoint = widget.routeCoordinates[_currentStep];
    _mapController?.animateCamera(CameraUpdate.newLatLng(nextPoint));

    setState(() {
      _mockedCurrentLocation = nextPoint; // Mock user location update
      _currentStep++;
    });

    if (_isNavigating) {
      await Future.delayed(Duration(milliseconds: 500)); // Faster navigation animation
      _navigateToNextStep();
    }
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _mockedCurrentLocation = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Navigation"),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: widget.routeCoordinates.first,
              zoom: 16,
            ),
            polylines: {
              Polyline(
                polylineId: PolylineId("route"),
                points: widget.routeCoordinates,
                color: Colors.blue,
                width: 4,
              ),
            },
            markers: {
              if (_mockedCurrentLocation != null)
                Marker(
                  markerId: MarkerId("current_location"),
                  position: _mockedCurrentLocation!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  infoWindow: InfoWindow(title: "Your Location"),
                ),
              Marker(
                markerId: MarkerId("destination"),
                position: widget.routeCoordinates.last,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(title: "Evacuation Destination"),
              ),
            },
          ),
          if (!_isNavigating)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: ElevatedButton(
                onPressed: _startNavigation,
                child: Text("Start Navigation"),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ),
          if (_isNavigating)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: ElevatedButton(
                onPressed: _stopNavigation,
                child: Text("Stop Navigation"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
