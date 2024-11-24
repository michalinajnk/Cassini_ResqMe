import 'dart:convert';
import 'package:cassini_hackathon/services/DataFetcher.dart';
import 'package:cassini_hackathon/services/DataSender.dart';
import 'package:cassini_hackathon/views/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:http/http.dart' as http;
import 'navigation_screen.dart';


import '../helper/get_route.dart';


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

class _EvacuationHomePageState extends State<EvacuationHomePage>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  Set<Polygon> _dangerZonePolygons = {};
  Set<Marker> _markers = {};
  LatLng? _currentPosition;
  LatLng? _destinationPosition;
  Polyline? _routePolyline;
  TextEditingController _destinationController = TextEditingController();
  String _travelMode = "";
  bool _isSearchBarExpanded = true;
  late DataFetcher _dataFetcher;
  late DataSender _dataSender;
  bool _showNotification = false;
  double _inDangerRay = 500;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isHelpRequested = false;
  final String _googleApiKey = 'AIzaSyAtuucM4ZmPmcqZiYwGZUpme_h5CYsXVD0';

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupBackgroundNotifications();
    _initLocationService();
    _inDangerRay = widget.inDangerRay;
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Pulsing animation duration
    )
      ..repeat(reverse: true);

    _animation =
        Tween<double>(begin: 1.0, end: 1.2).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Initialize services for communication with the server
  void _initializeServices() {
    final String baseUrl = "http://10.0.2.2:5000";
    ; // Local Flask server
    _dataSender = DataSender(baseUrl);
    _dataFetcher = DataFetcher(baseUrl);
  }

  /// Handle background notifications setup
  Future<void> _setupBackgroundNotifications() async {
    if (widget.allowBackgroundNotifications) {
      print(
          "Background notifications enabled for ${widget.inDangerRay} meters.");
    }
  }

  /// Initialize location services and fetch user location
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

    geolocator.Position position = await geolocator.Geolocator
        .getCurrentPosition(
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
    _centerMapOnCurrentLocation();
  }

  /// Handles the destination selection process
  Future<void> _onDestinationSet() async {
    if (_currentPosition == null || _destinationPosition == null) {
      setState(() {
        _showNotification = true; // Show notification if both locations are not set
      });

      // Automatically hide the notification after 3 seconds
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showNotification = false;
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            "Please set both your current location and destination.")),
      );
      return;
    }
    try {
      // Fetch processed data from the server
      final data = await _dataFetcher.fetchProcessedData(
        _currentPosition!,
        _destinationPosition!,
      );

      // Validate response data
      final List<dynamic> route = data["path"] ?? [];
      final List<dynamic> dangerZones = data["danger_zone"] ?? [];

      if (route.isEmpty || dangerZones.isEmpty) {
        throw Exception("Invalid data received: $data");
      }

      // Convert route to polyline
      final polylinePoints = route.map((point) => LatLng(point[1], point[0]))
          .toList();

      // Convert danger zones to polygons
      final dangerZonePolygons = dangerZones.map((zone) {
        final points = (zone as List)
            .map((point) => LatLng(point[1], point[0]))
            .toList();
        return Polygon(
          polygonId: PolygonId(zone.hashCode.toString()),
          points: points,
          fillColor: Colors.red.withOpacity(0.3),
          strokeColor: Colors.red,
          strokeWidth: 2,
        );
      }).toSet();

      List<LatLng> safeRouteListPoints = await getActualRoutePolyline(
          polylinePoints, _travelMode, _googleApiKey);
      setState(() {
        _routePolyline = Polyline(
          polylineId: PolylineId("route"),
          points: safeRouteListPoints,
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
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${tappedPosition
        .latitude},${tappedPosition.longitude}&key=$_googleApiKey';

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

        await _askTravelMode(); // Ask travel mode after destination is set
        await _onDestinationSet(); // Send data to the server and fetch results
      }
    } catch (e) {
      print("Error setting destination from tap: $e");
    }
  }

  /// Build Google Map Widget
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
      myLocationButtonEnabled: false,
      onTap: (LatLng position) {
        _setDestinationFromTap(position);
      },
    );
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: 16, // Match the button's top position
      left: _isSearchBarExpanded ? 72.0 : 16.0, // Offset the search bar when expanded
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        width: _isSearchBarExpanded
            ? MediaQuery.of(context).size.width - 100 // Adjust for button + padding
            : 36.0, // Button size when collapsed
        height: 36.0, // Consistent height
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28.0), // Rounded corners
          boxShadow: [
            if (_isSearchBarExpanded)
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
          ],
        ),
        child: _isSearchBarExpanded
            ? Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TypeAheadField<Map<String, dynamic>>(
            textFieldConfiguration: TextFieldConfiguration(
              controller: _destinationController,
              decoration: InputDecoration(
                hintText: "Enter evacuation destination",
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search),
              ),
            ),
            suggestionsCallback: (pattern) async {
              if (pattern.isEmpty) return [];
              return await fetchPlaceSuggestions(pattern, _googleApiKey);
            },
            itemBuilder: (context, suggestion) {
              return ListTile(
                title: Text(suggestion['description']),
              );
            },
            onSuggestionSelected: (suggestion) async {
              // Fetch place details and set destination
              final placeId = suggestion['place_id'];
              final location = await fetchPlaceDetails(placeId, _googleApiKey);

              if (location != null) {
                setState(() {
                  _destinationPosition = location;
                  _markers.add(Marker(
                    markerId: MarkerId("destination"),
                    position: location,
                    infoWindow: InfoWindow(title: suggestion['description']),
                  ));
                });

                // Ask for travel mode and fetch the route
                await _askTravelMode();
                await _onDestinationSet();
              }
            },
            noItemsFoundBuilder: (context) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("No places found"),
            ),
          ),
        )
            : FloatingActionButton(
          onPressed: () {
            setState(() {
              _isSearchBarExpanded = !_isSearchBarExpanded;
            });
          },
          child: Icon(Icons.loop),
          backgroundColor: Colors.blue,
          tooltip: "Toggle Search Bar",
          heroTag: "toggleSearchBarButton",
        ),
      ),
    );
  }


  Future<List<Map<String, dynamic>>> fetchPlaceSuggestions(String input,
      String apiKey) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$apiKey&types=geocode';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return (data['predictions'] as List)
              .map((prediction) =>
          {
            'description': prediction['description'],
            'place_id': prediction['place_id'],
          })
              .toList();
        } else {
          print("Places API Error: ${data['status']}");
          return [];
        }
      } else {
        throw Exception("Failed to fetch suggestions: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching suggestions: $e");
      return [];
    }
  }

  Future<LatLng?> fetchPlaceDetails(String placeId, String apiKey) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        } else {
          print("Places Details API Error: ${data['status']}");
          return null;
        }
      } else {
        throw Exception(
            "Failed to fetch place details: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching place details: $e");
      return null;
    }
  }


  /// Set Destination from Search
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
              LatLng(
                  location['lat'], location['lng']); // Destination coordinates
          _markers.add(Marker(
            markerId: MarkerId("destination"),
            position: _destinationPosition!,
            infoWindow: InfoWindow(title: address),
          ));
        });

        _askTravelMode(); // Ask travel mode after destination is set
        _onDestinationSet(); // Send data to the server and fetch results
      }
    } catch (e) {
      print("Error setting destination: $e");
    }
  }

  /// Ask the User for Travel Mode
  Future<void> _askTravelMode() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Select Travel Mode"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text("Driving"),
                leading: Radio<String>(
                  value: "driving",
                  groupValue: _travelMode,
                  onChanged: (value) {
                    setState(() {
                      _travelMode = value!;
                    });
                    Navigator.of(context).pop();
                    _fetchRoute(_currentPosition!, _destinationPosition!);
                  },
                ),
              ),
              ListTile(
                title: Text("Walking"),
                leading: Radio<String>(
                  value: "walking",
                  groupValue: _travelMode,
                  onChanged: (value) {
                    setState(() {
                      _travelMode = value!;
                    });
                    Navigator.of(context).pop();
                    _fetchRoute(_currentPosition!, _destinationPosition!);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Fetch Route Based on Travel Mode and Danger Zones
  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    List<LatLng> safeRoute_ListPoints = findSafeRoutePolygons(
        start, end, _dangerZonePolygons);
    List<LatLng> simulatedRoute =
    await getActualRoutePolyline(
        safeRoute_ListPoints, _travelMode, _googleApiKey);
    setState(() {
      _routePolyline = Polyline(
        polylineId: PolylineId("route"),
        points: simulatedRoute,
        color: Colors.blue,
        width: 4,
      );
    });


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

  /// Navigate to the settings page
  void _goToSettingsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) =>
          SettingsScreen()), // Replace with your Settings page widget
    );
  }

  /// Handle the "Need Help" action
  Future<void> _promptForHelp() async {
    bool? needsHelp = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Do you need help with evacuation?"),
          content: Text(
              "If you select Yes, your location will be shared with other users of the app and a notification will be sent to the emergency contacts configured in the Settings page."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("No"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("Yes"),
            ),
          ],
        );
      },
    );

    if (needsHelp == true) {
      if (needsHelp == true) {
        bool? confirmHelp = await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Are you sure?"),
              content: Text(
                  "Your current location will be shared with other users and emergency contacts will be notified."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text("Confirm"),
                ),
              ],
            );
          },
        );

        if (confirmHelp == true) {
          // For now, simulate sending location for help
          setState(() {
            _isHelpRequested = true; // Trigger the pulsing animation
          }
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Help notification sent.")),
          );

          // Add logic to share location with other users or notify emergency contacts
          _sendHelpNotification();
        } else if (_isHelpRequested) {
          setState(() {
            _isHelpRequested = false; // Trigger the pulsing animation
          }
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(" Stop sharing your location")),
          );
        }
      } else if (_isHelpRequested) {
        setState(() {
          _isHelpRequested = false; // Trigger the pulsing animation
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(" Stop sharing your location")),
        );
      }
    }
    else if (_isHelpRequested) {
      setState(() {
        _isHelpRequested = false; // Trigger the pulsing animation
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(" Stop sharing your location")),
      );
    }

  }

    /// Simulate sending a help notification
    void _sendHelpNotification() {
      // Add your logic to share location or notify contacts
      print("Help notification: Sharing current location $_currentPosition");
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ResQMe'),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          _buildGoogleMap(),
          // Search Bar with Expand and Minimize Gesture
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            top: 20,
            left: _isSearchBarExpanded ? 80 : 45.0,
            // Align with the button when collapsed
            right: _isSearchBarExpanded ? 10 : MediaQuery
                .of(context)
                .size
                .width - 80.0,
            height: _isSearchBarExpanded ? 48.0 : 0.0,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: 300),
              opacity: _isSearchBarExpanded ? 1.0 : 0.0,
              child: _isSearchBarExpanded
                  ? _buildSearchBar() // Use the existing search bar logic
                  : SizedBox.shrink(),
            ),
          ),
          SizedBox(width: 10.0),
          // Floating Action Button to toggle search bar visibility
          Positioned(
            top: 20.0,
            left: 16.0,
            width: 50,
            height: 50,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isSearchBarExpanded = !_isSearchBarExpanded;
                });
              },
              child: Icon(
                _isSearchBarExpanded ? Icons.close : Icons.search,
              ),
              backgroundColor: Colors.blue,
              tooltip: _isSearchBarExpanded ? "Hide Search Bar" : "Show Search Bar",
              heroTag: "toggleSearchBarButton",
            ),
          ),
          // Notification Widget for Navigation Availability
          if (_showNotification) _buildNavigationNotification(),
          // Floating Action Buttons
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: _buildFABLayout(),
            ),
          ),
        ],
      ),
    );
  }

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

  /// Remove notification after 3 seconds
  @override
  void setState(VoidCallback fn) {
    super.setState(() {
      fn();
      if (_routePolyline != null) {
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) setState(() {}); // Clear the notification after 3 seconds
        });
      }
    });
  }

  Widget _buildFAB(IconData icon, String tooltip, VoidCallback onPressed, Color color, String heroTag) {
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


  Widget _buildFABGrid({required Key key}) {
    return Table(
      key: key,
      defaultColumnWidth: FixedColumnWidth(60.0), // Fixed button width with spacing
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _buildFAB(Icons.warning_amber_outlined, "Need Help", _promptForHelp, Colors.red, "helpButton"),
            _buildFAB(Icons.my_location, "Go to My Location", _centerMapOnCurrentLocation, Colors.blue, "currentLocationButton"),
          ],
        ),
        TableRow(
          children: [SizedBox(height: 10.0), SizedBox(height: 10.0)], // Spacer row
        ),
        TableRow(
          children: [
            _buildFAB(Icons.settings, "Go to Settings", _goToSettingsPage, Colors.blue, "settingsButton"),
            _buildFAB(Icons.navigation, "Navigate to Destination", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NavigationScreen(
                    routeCoordinates: _routePolyline!.points,
                  ),
                ),
              );
            }, Colors.blue, "navigateButton"),
          ],
        ),
      ],
    );
  }




  Widget _buildFABLayout() {
    bool isGrid = _routePolyline != null; // Switch to grid if navigation is available

    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: Align(
        alignment: Alignment.bottomLeft, // Align the grid to the bottom-left corner
        child: Padding(
          padding: const EdgeInsets.all(10.0), // Padding from edges
          child: isGrid
              ? _buildFABGrid(key: ValueKey('FABGrid')) // 2x2 grid layout
              : _buildFABColumn(key: ValueKey('FABColumn')), // Column layout
        ),
      ),
    );
  }



  Widget _buildFABColumn({required Key key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFAB(Icons.warning_amber_outlined, "Need Help", _promptForHelp, Colors.red, "helpButton"),
        SizedBox(height: 10.0),
        _buildFAB(Icons.my_location, "Go to My Location", _centerMapOnCurrentLocation, Colors.blue, "currentLocationButton"),
        SizedBox(height: 10.0),
        _buildFAB(Icons.settings, "Go to Settings", _goToSettingsPage, Colors.blue, "settingsButton"),
      ],
    );
  }

}
