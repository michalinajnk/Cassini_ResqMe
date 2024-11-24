import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DataFetcher {
  final Dio _dio;

  DataFetcher(String baseUrl)
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(milliseconds: 10000),
    receiveTimeout: const Duration(milliseconds: 30000),
    headers: {"Content-Type": "application/json"},
  ));

  /// Fetches the processed route and danger zones from the server
  Future<Map<String, dynamic>> fetchProcessedData(LatLng start,
      LatLng target) async {
    try {
      // GET request with query parameters
      final response = await _dio.get(
        "/navigate",
        queryParameters: {
          "start": "${start.longitude},${start.latitude}",
          "target": "${target.longitude},${target.latitude}",
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception("Invalid response: ${response.statusCode} - ${response
            .statusMessage}");
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
            "Failed to fetch data: ${e.response?.statusCode} - ${e.response
                ?.data}");
      } else {
        throw Exception("Connection error: ${e.message}");
      }
    }
  }
}


