import 'package:flutter/material.dart';
import 'views/welcome_screen.dart';
import 'views/evacuation_home_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ResQMe',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: WelcomeScreen(), // Start with the welcome screen
    );
  }
}
