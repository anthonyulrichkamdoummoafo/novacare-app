import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../models/hospital.dart';
import '../utils/api_client.dart';
import '../utils/cache_manager.dart';

class HospitalService {
  // Flip this to true while developing locally against
  // `uvicorn main:app --reload --port 8001` in hospital_referal/.
  // Set it back to false before building a release you'll hand to someone
  // else, so it points at the deployed API instead.
  static const bool _useLocalBackend = false;

  static const int _localPort = 8001;

  // TODO: Replace with your deployed API URL
  // Examples:
  // Railway: 'https://your-hospital-api.railway.app'
  // Render: 'https://novacare-hospital-api.onrender.com'
  // Heroku: 'https://novacare-hospital-api.herokuapp.com'
  static const String _deployedBaseUrl =
      'https://novacare-hospital-api1.onrender.com'; // Deployed on Render

  static String get _baseUrl {
    if (!_useLocalBackend) return _deployedBaseUrl;

    // localhost means something different depending on where the app runs:
    // - Android emulator can't see the host machine as "localhost" - it
    //   needs the special alias 10.0.2.2.
    // - Web, Windows/desktop, and a physical device on the same network as
    //   the API can use the loopback address (a physical device would
    //   actually need your PC's real LAN IP, e.g. 192.168.x.x - swap it in
    //   here manually if you're testing on a phone over WiFi).
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:$_localPort';
    }
    return 'http://127.0.0.1:$_localPort';
  }

  static const Duration _timeoutDuration = Duration(seconds: 10);

  final ApiClient _apiClient = ApiClient();
  final CacheManager _cacheManager = CacheManager();

  /// Fetch hospitals near a location
  Future<List<Hospital>> fetchNearbyHospitals({
    required double latitude,
    required double longitude,
    String? facilityType,
    int limit = 10,
    bool useCache = true,
  }) async {
    try {
      // Generate cache key
      final cacheKey =
          'hospitals_${latitude}_${longitude}_${facilityType ?? 'all'}_$limit';

      // Try cache first
      if (useCache) {
        final cachedData = await _cacheManager.get<List<Hospital>>(cacheKey);
        if (cachedData != null) {
          debugPrint('Returning cached hospitals');
          return cachedData;
        }
      }

      // Build query parameters
      final queryParams = {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'top_n': limit.toString(),
        if (facilityType != null && facilityType.isNotEmpty)
          'type': facilityType,
      };

      // Make API request
      final response = await _apiClient.get(
        '$_baseUrl/recommend-hospitals',
        queryParams: queryParams,
        timeout: _timeoutDuration,
      );

      // Parse response
      final List<dynamic> hospitalsJson = response;
      final hospitals =
          hospitalsJson.map((json) => Hospital.fromJson(json)).toList();

      // Cache results
      if (useCache) {
        await _cacheManager.set(cacheKey, hospitals,
            duration: const Duration(minutes: 15));
      }

      return hospitals;
    } catch (e) {
      debugPrint('Error fetching hospitals: $e');
      rethrow;
    }
  }

  /// Get available facility types
  Future<List<String>> getFacilityTypes() async {
    const cacheKey = 'facility_types';

    // Try cache first
    final cachedTypes = await _cacheManager.get<List<String>>(cacheKey);
    if (cachedTypes != null) {
      return cachedTypes;
    }

    try {
      final response = await _apiClient.get(
        '$_baseUrl/facility-types',
        timeout: _timeoutDuration,
      );

      final List<String> types = List<String>.from(response);

      // Cache for longer since facility types don't change often
      await _cacheManager.set(cacheKey, types,
          duration: const Duration(hours: 24));

      return types;
    } catch (e) {
      debugPrint('Error fetching facility types: $e');
      // Return default types if API fails
      return [
        'All',
        'Hospital',
        'Health Centre',
        'Clinic',
        'Emergency',
      ];
    }
  }

  /// Search hospitals by name or location
  Future<List<Hospital>> searchHospitals({
    required String query,
    double? latitude,
    double? longitude,
    int limit = 20,
  }) async {
    try {
      final queryParams = {
        'q': query,
        'limit': limit.toString(),
        if (latitude != null) 'lat': latitude.toString(),
        if (longitude != null) 'lon': longitude.toString(),
      };

      final response = await _apiClient.get(
        '$_baseUrl/search-hospitals',
        queryParams: queryParams,
        timeout: _timeoutDuration,
      );

      final List<dynamic> hospitalsJson = response;
      return hospitalsJson.map((json) => Hospital.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error searching hospitals: $e');
      rethrow;
    }
  }

  /// Get hospital details by ID
  Future<Hospital> getHospitalDetails(String hospitalId) async {
    final cacheKey = 'hospital_details_$hospitalId';

    // Try cache first
    final cachedHospital = await _cacheManager.get<Hospital>(cacheKey);
    if (cachedHospital != null) {
      return cachedHospital;
    }

    try {
      final response = await _apiClient.get(
        '$_baseUrl/hospitals/$hospitalId',
        timeout: _timeoutDuration,
      );

      final hospital = Hospital.fromJson(response);

      // Cache hospital details
      await _cacheManager.set(cacheKey, hospital,
          duration: const Duration(hours: 1));

      return hospital;
    } catch (e) {
      debugPrint('Error fetching hospital details: $e');
      rethrow;
    }
  }

  /// Report hospital information update
  Future<void> reportHospitalUpdate({
    required String hospitalId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await _apiClient.post(
        '$_baseUrl/hospitals/$hospitalId/report',
        body: updates,
        timeout: _timeoutDuration,
      );

      // Invalidate cache for this hospital
      await _cacheManager.remove('hospital_details_$hospitalId');
    } catch (e) {
      debugPrint('Error reporting hospital update: $e');
      rethrow;
    }
  }

  /// Get emergency hospitals (24/7 availability)
  Future<List<Hospital>> getEmergencyHospitals({
    required double latitude,
    required double longitude,
    int limit = 5,
  }) async {
    return fetchNearbyHospitals(
      latitude: latitude,
      longitude: longitude,
      facilityType: 'Emergency',
      limit: limit,
    );
  }

  /// Clear all cached hospital data
  Future<void> clearCache() async {
    await _cacheManager.clearAll();
  }

  /// Check API health
  Future<bool> checkApiHealth() async {
    try {
      final response = await _apiClient.get(
        '$_baseUrl/health',
        timeout: const Duration(seconds: 5),
      );

      return response['status'] == 'healthy';
    } catch (e) {
      debugPrint('API health check failed: $e');
      return false;
    }
  }
}
