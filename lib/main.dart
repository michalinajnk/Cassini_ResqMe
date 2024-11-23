import 'package:flutter/material.dart';
import 'evacuation_home_page.dart';
import 'map_test.dart'; // Import the separated logic file

void main() {
  runApp(EvacuationApp());
}

class EvacuationApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Evacuation Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MapSample(), // Use the separated home page
    );
  }
}
