import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:location/location.dart' as location;

class EvacuationHomePage extends StatefulWidget {
  @override
  _EvacuationHomePageState createState() => _EvacuationHomePageState();
}

class _EvacuationHomePageState extends State<EvacuationHomePage> {
  late GoogleMapController _mapController;
  Set<Marker> _dangerZoneMarkers = {};
  LatLng? _currentPosition;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initLocationService();
    _initNotifications();
    _loadDangerZones();
  }

  // Initialize Location Services
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
      locationSettings: geolocator.LocationSettings(accuracy: geolocator.LocationAccuracy.high),
    );
    LatLng newPosition = LatLng(position.latitude, position.longitude);

    setState(() {
      _currentPosition = newPosition;
    });

    if (_mapController != null) {
      _updateMapLocation(newPosition);
    }

    geolocator.Geolocator.getPositionStream(
      locationSettings: geolocator.LocationSettings(accuracy: geolocator.LocationAccuracy.high),
    ).listen((geolocator.Position position) {
      LatLng newPosition = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentPosition = newPosition;
      });

      _updateMapLocation(newPosition);
      _checkProximityToDangerZones();
    });
  }

  void _updateMapLocation(LatLng position) {
    _mapController.animateCamera(CameraUpdate.newLatLng(position));
  }

  // Initialize Notifications
  void _initNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Show Notification
  Future<void> _showNotification(String message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'danger_zone_channel',
      'Danger Zone Alerts',
      channelDescription: 'Alerts when entering a danger zone',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Danger Zone Alert',
      message,
      platformChannelSpecifics,
    );
  }

  // Load Predefined Danger Zones
  void _loadDangerZones() {
    // Example danger zones
    List<LatLng> dangerZones = [
      LatLng(37.7749, -122.4194), // San Francisco
      LatLng(34.0522, -118.2437), // Los Angeles
    ];

    setState(() {
      _dangerZoneMarkers = dangerZones
          .map((zone) => Marker(
        markerId: MarkerId(zone.toString()),
        position: zone,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Danger Zone'),
      ))
          .toSet();
    });
  }

  // Check Proximity to Danger Zones
  void _checkProximityToDangerZones() {
    if (_currentPosition == null) return;

    for (Marker marker in _dangerZoneMarkers) {
      double distance = geolocator.Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        marker.position.latitude,
        marker.position.longitude,
      );

      if (distance < 500) {
        // Danger zone proximity detected
        _showNotification(
            'You are within 500 meters of a danger zone. Please evacuate!');
        break;
      }
    }
  }

  // Build Google Map Widget
  Widget _buildGoogleMap() {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
      markers: _dangerZoneMarkers,
      initialCameraPosition: CameraPosition(
        target: _currentPosition ?? LatLng(37.7749, -122.4194), // Default position
        zoom: 12,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Evacuation Tracker'),
        backgroundColor: Colors.blue,
      ),
      body: _currentPosition == null
          ? Center(child: CircularProgressIndicator())
          : _buildGoogleMap(),
    );
  }
}
