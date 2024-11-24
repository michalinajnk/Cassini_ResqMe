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
  bool _allowLocationTracking = false;
  TextEditingController _emergencyContactController = TextEditingController();

  Future<void> _requestPermissions() async {
    print("Requesting permissions...");
    var locationStatus = await Permission.locationWhenInUse.request();
    var backgroundStatus = _allowLocationTracking
        ? await Permission.locationAlways.request()
        : PermissionStatus.granted;

    print("Location permission status: $locationStatus");
    print("Background location permission status: $backgroundStatus");

    if (locationStatus.isDenied || locationStatus.isPermanentlyDenied) {
      print("Location permission denied.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location permission is required to continue.')),
      );
    } else if (_allowLocationTracking &&
        (backgroundStatus.isDenied || backgroundStatus.isPermanentlyDenied)) {
      print("Background location permission denied.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'Background location permission is required for tracking.')),
      );
    }
    print("Permissions granted. Navigating to EvacuationHomePage...");
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            EvacuationHomePage(
              inDangerRay: _dangerZoneRadius,
              allowBackgroundNotifications: true,
            ),
      ),
    );
  }

    @override
    void dispose() {
      _emergencyContactController.dispose();
      super.dispose();
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
              CheckboxListTile(
                title: Text("Allow Location Tracking"),
                value: _allowLocationTracking,
                onChanged: (value) {
                  setState(() {
                    _allowLocationTracking = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              TextField(
                controller: _emergencyContactController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Emergency Contact",
                  hintText: "Enter phone number",
                  border: OutlineInputBorder(),
                ),
              ),
              Spacer(),
              ElevatedButton(
                onPressed: _requestPermissions,
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
