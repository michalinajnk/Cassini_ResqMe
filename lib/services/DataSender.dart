import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DataSender {
  final Dio _dio;

  DataSender(String baseUrl)
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(milliseconds: 5000),
    receiveTimeout: const Duration(milliseconds: 5000),
    headers: {"Content-Type": "application/json"},
  ));

  /// Sends the user's current location and target destination to the server
  Future<void> sendUserLocationAndTarget(LatLng currentPosition, LatLng destinationPosition) async {
    try {
      await _dio.post(
        "/navigate",
        data: {
          "start": [currentPosition.longitude, currentPosition.latitude],
          "target": [destinationPosition.longitude, destinationPosition.latitude],
        },
      );
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception("Failed to send data: ${e.response?.statusCode}");
      } else {
        throw Exception("Connection error: ${e.message}");
      }
    }
  }
}
