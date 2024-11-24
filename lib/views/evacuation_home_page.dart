import 'dart:convert';
import 'package:cassini_hackathon/services/DataFetcher.dart';
import 'package:cassini_hackathon/services/DataSender.dart';
import 'package:cassini_hackathon/views/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:http/http.dart' as http;

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

class _EvacuationHomePageState extends State<EvacuationHomePage> {
  GoogleMapController? _mapController;
  Set<Polygon> _dangerZonePolygons = {};
  Set<Marker> _markers = {};
  LatLng? _currentPosition;
  LatLng? _destinationPosition;
  Polyline? _routePolyline;
  TextEditingController _destinationController = TextEditingController();
  String _travelMode = "driving";
  late DataFetcher _dataFetcher;
  late DataSender _dataSender;
  double _inDangerRay = 500;
  final String _googleApiKey = 'AIzaSyAtuucM4ZmPmcqZiYwGZUpme_h5CYsXVD0';

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupBackgroundNotifications();
    _initLocationService();
    _inDangerRay = widget.inDangerRay;
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
  }

  /// Handles the destination selection process
  Future<void> _onDestinationSet() async {
    if (_currentPosition == null || _destinationPosition == null) {
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
      top: 10,
      left: 10,
      right: 10,
      child: Card(
        elevation: 4,
        child: TypeAheadField<Map<String, dynamic>>(
          textFieldConfiguration: TextFieldConfiguration(
            controller: _destinationController,
            decoration: InputDecoration(
              hintText: "Search for a place",
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.search), // Optional search icon
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
              await _askTravelMode(); // Ask travel mode after destination is set
              await _onDestinationSet(); // Send data to the server and fetch results
            }
          },
          noItemsFoundBuilder: (context) =>
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("No places found"),
              ),
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
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    onPressed: _centerMapOnCurrentLocation,
                    child: Icon(Icons.my_location),
                    backgroundColor: Colors.grey,
                    heroTag: "currentLocationButton", // Unique heroTag
                  ),
                  SizedBox(height: 16.0), // Space between the buttons
                  FloatingActionButton(
                    onPressed: _goToSettingsPage,
                    child: Icon(Icons.settings),
                    backgroundColor: Colors.grey,
                    heroTag: "settingsButton", // Unique heroTag
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}