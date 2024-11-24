import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DataFetcher {
  final Dio _dio;

  DataFetcher(String baseUrl)
      : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(milliseconds: 5000),
    receiveTimeout: const Duration(milliseconds: 5000),
    headers: {"Content-Type": "application/json"},
  ));

  /// Fetches the processed route and danger zones from the server
  Future<Map<String, dynamic>> fetchProcessedData() async {
    try {
      final response = await _dio.get("/navigate");

      // Server response contains "path" (route) and "danger_zone" (polygons)
      return response.data; // Map with keys: "path" and "danger_zone"
    } on DioError catch (e) {
      if (e.response != null) {
        throw Exception("Failed to fetch data: ${e.response?.statusCode}");
      } else {
        throw Exception("Connection error: ${e.message}");
      }
    }
  }
}
