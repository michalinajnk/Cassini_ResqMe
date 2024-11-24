import 'package:flutter/material.dart';
import 'evacuation_home_page.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _dangerZoneRadius = 500.0; // Default radius
  bool _allowBackgroundNotifications = false;

  Future<void> _requestLocationPermission() async {
    var status = await Permission.locationWhenInUse.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permission is required to continue.')),
      );
    } else if (status.isGranted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => EvacuationHomePage(
            inDangerRay: _dangerZoneRadius,
            allowBackgroundNotifications: _allowBackgroundNotifications,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Set Your Preferences",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              "Danger Zone Radius: ${_dangerZoneRadius.toInt()} meters",
              style: TextStyle(fontSize: 16),
            ),
            Slider(
              value: _dangerZoneRadius,
              min: 100,
              max: 1000,
              divisions: 9,
              label: "${_dangerZoneRadius.toInt()} m",
              onChanged: (value) {
                setState(() {
                  _dangerZoneRadius = value;
                });
              },
            ),
            SizedBox(height: 16),
            CheckboxListTile(
              title: Text("Enable Background Notifications"),
              value: _allowBackgroundNotifications,
              onChanged: (value) {
                setState(() {
                  _allowBackgroundNotifications = value!;
                });
              },
            ),
            Spacer(),
            ElevatedButton(
              onPressed: _requestLocationPermission,
              child: Text("Continue to Map"),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
