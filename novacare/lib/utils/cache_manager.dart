import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class CacheManager {
  static const String _keyPrefix = 'cache_';
  static const String _timestampSuffix = '_timestamp';
  
  /// Get cached data
  Future<T?> get<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _keyPrefix + key;
      final timestampKey = cacheKey + _timestampSuffix;
      
      // Check if cache exists
      if (!prefs.containsKey(cacheKey)) {
        return null;
      }
      
      // Check if cache is expired
      final timestamp = prefs.getInt(timestampKey);
      if (timestamp == null) {
        // No timestamp, consider expired
        await _remove(key);
        return null;
      }
      
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now > timestamp) {
        // Cache expired
        await _remove(key);
        return null;
      }
      
      // Get cached data
      final cachedData = prefs.getString(cacheKey);
      if (cachedData == null) {
        return null;
      }
      
      // Deserialize data
      final decodedData = jsonDecode(cachedData);
      return _deserialize<T>(decodedData);
    } catch (e) {
      debugPrint('Cache get error: $e');
      return null;
    }
  }
  
  /// Set cached data with expiration
  Future<void> set<T>(String key, T data, {Duration? duration}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _keyPrefix + key;
      final timestampKey = cacheKey + _timestampSuffix;
      
      // Calculate expiration timestamp
      final expiration = duration ?? const Duration(hours: 1);
      final expirationTimestamp = DateTime.now()
          .add(expiration)
          .millisecondsSinceEpoch;
      
      // Serialize and store data
      final serializedData = jsonEncode(_serialize(data));
      await prefs.setString(cacheKey, serializedData);
      await prefs.setInt(timestampKey, expirationTimestamp);
      
      debugPrint('Cached data for key: $key (expires in ${expiration.inMinutes} minutes)');
    } catch (e) {
      debugPrint('Cache set error: $e');
    }
  }
  
  /// Remove cached data
  Future<void> remove(String key) async {
    await _remove(key);
  }
  
  /// Private remove method
  Future<void> _remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _keyPrefix + key;
      final timestampKey = cacheKey + _timestampSuffix;
      
      await prefs.remove(cacheKey);
      await prefs.remove(timestampKey);
    } catch (e) {
      debugPrint('Cache remove error: $e');
    }
  }
  
  /// Clear all cached data
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final cacheKeys = keys.where((key) => key.startsWith(_keyPrefix));
      
      for (final key in cacheKeys) {
        await prefs.remove(key);
      }
      
      debugPrint('Cleared all cached data');
    } catch (e) {
      debugPrint('Cache clear error: $e');
    }
  }
  
  /// Check if cache exists and is valid
  Future<bool> exists(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _keyPrefix + key;
      final timestampKey = cacheKey + _timestampSuffix;
      
      if (!prefs.containsKey(cacheKey)) {
        return false;
      }
      
      final timestamp = prefs.getInt(timestampKey);
      if (timestamp == null) {
        return false;
      }
      
      final now = DateTime.now().millisecondsSinceEpoch;
      return now <= timestamp;
    } catch (e) {
      debugPrint('Cache exists check error: $e');
      return false;
    }
  }
  
  /// Get cache size (number of cached items)
  Future<int> getCacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final cacheKeys = keys.where((key) => 
          key.startsWith(_keyPrefix) && !key.endsWith(_timestampSuffix));
      
      return cacheKeys.length;
    } catch (e) {
      debugPrint('Cache size error: $e');
      return 0;
    }
  }
  
  /// Serialize data for storage
  dynamic _serialize<T>(T data) {
    if (data is List) {
      return data.map((item) => _serialize(item)).toList();
    } else if (data is Map) {
      return data.map((key, value) => MapEntry(key, _serialize(value)));
    } else {
      // For custom objects, assume they have toJson method
      try {
        return (data as dynamic).toJson();
      } catch (e) {
        // Fallback to direct serialization
        return data;
      }
    }
  }
  
  /// Deserialize data from storage
  T? _deserialize<T>(dynamic data) {
    try {
      return data as T;
    } catch (e) {
      debugPrint('Deserialization error: $e');
      return null;
    }
  }
}
