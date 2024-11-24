import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DataSender {
  final Dio _dio;

  DataSender(String baseUrl)
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(milliseconds: 50000),
    receiveTimeout: const Duration(milliseconds: 50000),
    headers: {"Content-Type": "application/json"},
  ));

  /// Sends the user's current location and target destination to the server
  Future<void> sendUserLocationAndTarget(LatLng currentPosition, LatLng destinationPosition) async {
    try {
      final response = await _dio.post(
        "/navigate",
        data: {
          "start": [currentPosition.longitude, currentPosition.latitude],
          "target": [destinationPosition.longitude, destinationPosition.latitude],
        },
      );

      // Log or inspect the response if necessary
      print("Data sent successfully. Response: ${response.statusCode}");
    } on DioError catch (e) {
      if (e.response != null) {
        // Detailed error from the server
        throw Exception(
            "Failed to send data: ${e.response?.statusCode} - ${e.response?.statusMessage}\n${e.response?.data}");
      } else {
        // Connection-related error
        throw Exception("Connection error: ${e.message}");
      }
    }
  }
}
