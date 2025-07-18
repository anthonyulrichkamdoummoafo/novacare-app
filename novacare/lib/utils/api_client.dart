import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiClient {
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Make a GET request
  Future<dynamic> get(
    String url, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final uri = Uri.parse(url).replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...?headers,
        },
      ).timeout(timeout ?? _defaultTimeout);

      return _handleResponse(response);
    } catch (e) {
      debugPrint('GET request failed: $e');
      rethrow;
    }
  }

  /// Make a POST request
  Future<dynamic> post(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...?headers,
        },
        body: body != null ? jsonEncode(body) : null,
      ).timeout(timeout ?? _defaultTimeout);

      return _handleResponse(response);
    } catch (e) {
      debugPrint('POST request failed: $e');
      rethrow;
    }
  }

  /// Make a PUT request
  Future<dynamic> put(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...?headers,
        },
        body: body != null ? jsonEncode(body) : null,
      ).timeout(timeout ?? _defaultTimeout);

      return _handleResponse(response);
    } catch (e) {
      debugPrint('PUT request failed: $e');
      rethrow;
    }
  }

  /// Make a DELETE request
  Future<dynamic> delete(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...?headers,
        },
      ).timeout(timeout ?? _defaultTimeout);

      return _handleResponse(response);
    } catch (e) {
      debugPrint('DELETE request failed: $e');
      rethrow;
    }
  }

  /// Handle HTTP response
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    
    if (statusCode >= 200 && statusCode < 300) {
      // Success
      if (response.body.isEmpty) {
        return null;
      }
      
      try {
        return jsonDecode(response.body);
      } catch (e) {
        // If JSON decode fails, return raw body
        return response.body;
      }
    } else if (statusCode == 404) {
      throw ApiException('Resource not found', statusCode);
    } else if (statusCode >= 400 && statusCode < 500) {
      throw ApiException('Client error: ${response.body}', statusCode);
    } else if (statusCode >= 500) {
      throw ApiException('Server error: ${response.body}', statusCode);
    } else {
      throw ApiException('Unexpected error: ${response.body}', statusCode);
    }
  }
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}
