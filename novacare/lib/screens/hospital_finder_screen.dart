import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';

class HospitalFinderScreen extends StatefulWidget {
  const HospitalFinderScreen({super.key});
  static const routeName = '/hospital_finder';

  @override
  State<HospitalFinderScreen> createState() => _HospitalFinderScreenState();
}

class HospitalService {
  static const baseUrl = 'http://192.168.39.111:8001';
  static const Duration timeoutDuration = Duration(seconds: 10);

  static Future<List<dynamic>> fetchHospitals(double lat, double lon,
      {String? type, int topN = 10}) async {
    try {
      final uri =
          Uri.parse('$baseUrl/recommend-hospitals').replace(queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'top_n': topN.toString(),
        if (type != null && type.isNotEmpty) 'type': type,
      });

      final response = await http.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> hospitals = jsonDecode(response.body);
        return hospitals
            .map((hospital) => _enhanceHospitalData(hospital))
            .toList();
      } else if (response.statusCode == 404) {
        return []; // No hospitals found
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timeout. Please check your connection.');
    } catch (e) {
      throw Exception('Failed to load hospitals: $e');
    }
  }

  static Map<String, dynamic> _enhanceHospitalData(
      Map<String, dynamic> hospital) {
    // Add mock data for features not in the API
    return {
      ...hospital,
      'status': _generateStatus(),
      'rating': _generateRating(),
      'reviews': _generateReviews(),
      'waitTime': _generateWaitTime(),
      'isEmergency': _isEmergencyFacility(hospital['facility_type'] ?? ''),
      'phone': _generatePhoneNumber(),
      'services': _generateServices(hospital['facility_type'] ?? ''),
    };
  }

  static String _generateStatus() {
    return ['Open', 'Closed', 'Open 24/7'][DateTime.now().hour < 22 ? 0 : 1];
  }

  static double _generateRating() {
    return 3.0 + (DateTime.now().millisecond % 20) / 10.0;
  }

  static int _generateReviews() {
    return 50 + (DateTime.now().millisecond % 200);
  }

  static String _generateWaitTime() {
    final times = ['5-10 min', '15-20 min', '30-45 min', '1-2 hours'];
    return times[DateTime.now().minute % times.length];
  }

  static bool _isEmergencyFacility(String facilityType) {
    return facilityType.toLowerCase().contains('hospital') ||
        facilityType.toLowerCase().contains('emergency');
  }

  static String _generatePhoneNumber() {
    return '+237 6${DateTime.now().millisecond.toString().padLeft(8, '0')}';
  }

  static List<String> _generateServices(String facilityType) {
    if (facilityType.toLowerCase().contains('hospital')) {
      return ['Emergency Care', 'Surgery', 'Radiology', 'Laboratory'];
    } else if (facilityType.toLowerCase().contains('centre')) {
      return ['General Medicine', 'Vaccination', 'Basic Care'];
    }
    return ['General Medicine'];
  }
}

class _HospitalFinderScreenState extends State<HospitalFinderScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  String _selectedFilter = 'All';
  bool _isMapView = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _allHospitals = [];
  List<Map<String, dynamic>> _filteredHospitals = [];
  StreamSubscription<Position>? _positionStream;

  List<String> get filterOptions => ['All', 'Emergency', 'Open Now', 'Nearby'];

  @override
  void initState() {
    super.initState();
    _loadHospitals();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar('Location services are disabled.');
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackBar('Location permissions are denied');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackBar(
          'Location permissions are permanently denied, please enable them in settings.');
      return null;
    }

    // Get current position
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _loadHospitals() async {
    setState(() => _isLoading = true);
    try {
      final position = await _determinePosition();
      if (position == null) {
        setState(() => _isLoading = false);
        return; // permission or service disabled, stop here
      }

      final hospitals = await HospitalService.fetchHospitals(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _allHospitals = List<Map<String, dynamic>>.from(hospitals);
        _applyFilter(position); // pass position to filter
      });

      // Log the activity
      try {
        await _supabaseService.logActivity(
          'hospital_search',
          'Searched for hospitals near current location (${hospitals.length} found)',
        );
      } catch (e) {
        // Silently handle logging errors
        debugPrint('Error logging activity: $e');
      }
    } catch (e) {
      print('Error fetching hospitals: $e');
      _showErrorSnackBar('Failed to fetch hospitals: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startLocationUpdates() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // update every 50 meters
      ),
    ).listen((Position position) {
      // Reapply filter with new position
      _applyFilter(position);
    });
  }

  void _applyFilter([Position? userPosition]) {
    setState(() {
      switch (_selectedFilter) {
        case 'Emergency':
          _filteredHospitals = _allHospitals
              .where((h) => (h['facility_type'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains('emergency'))
              .toList();
          break;
        case 'Nearby':
          if (userPosition == null) {
            _filteredHospitals = _allHospitals;
            break;
          }

          _filteredHospitals = _allHospitals.where((hospital) {
            final lat = hospital['latitude'];
            final lon = hospital['longitude'];
            if (lat == null || lon == null) return false;

            final distanceInMeters = Geolocator.distanceBetween(
              userPosition.latitude,
              userPosition.longitude,
              lat,
              lon,
            );
            final distanceInKm = distanceInMeters / 1000;
            return distanceInKm <= 2.0;
          }).toList();
          break;
        case 'Open Now':
          _filteredHospitals = _allHospitals
              .where((h) =>
                  (h['status']?.toString().toLowerCase() ?? '') == 'open')
              .toList();
          break;
        default:
          _filteredHospitals = _allHospitals;
      }
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showErrorSnackBar('Could not make call to $phoneNumber');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text(
          'Find Hospitals',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isMapView ? Icons.list : Icons.map,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isMapView = !_isMapView;
              });
              _showSuccessSnackBar(
                _isMapView ? 'Map view enabled' : 'List view enabled',
              );
            },
            tooltip: _isMapView ? 'Switch to List View' : 'Switch to Map View',
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              _showSuccessSnackBar('Search feature coming soon!');
            },
            tooltip: 'Search Hospitals',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter Results',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: filterOptions.map((filter) {
                            final isSelected = _selectedFilter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(
                                  filter,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF6B7280),
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedFilter = filter;
                                    _applyFilter();
                                  });
                                },
                                backgroundColor: const Color(0xFFF3F4F6),
                                selectedColor: Colors.teal,
                                checkmarkColor: Colors.white,
                                elevation: 0,
                                pressElevation: 2,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                // Results Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: const Color(0xFFF8FAFB),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_filteredHospitals.length} hospital${_filteredHospitals.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Text(
                        'Sorted by distance',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                // Hospital List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredHospitals.length,
                    itemBuilder: (context, index) {
                      final hospital = _filteredHospitals[index];
                      return _buildHospitalCard(hospital);
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _makePhoneCall('112'); // Emergency number
        },
        backgroundColor: Colors.red[600],
        icon: const Icon(Icons.local_hospital, color: Colors.white),
        label: const Text(
          'Emergency',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHospitalCard(Map<String, dynamic> hospital) {
    final isOpen =
        (hospital['status']?.toString().toLowerCase() ?? '') == 'open';
    final hasEmergency = hospital['isEmergency'] == true;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _showHospitalDetails(hospital);
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hospital Icon/Image Placeholder
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_hospital,
                      color: Color(0xFF0891B2),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Hospital Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                hospital['facility_name'] ?? 'Unknown Hospital',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            _buildStatusChip(hospital['status'] ?? 'Closed'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hospital['facility_type'] ?? 'General',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Rating and Reviews
                        Row(
                          children: [
                            ...List.generate(
                              5,
                              (i) {
                                final rating = hospital['rating'];
                                final safeRating =
                                    (rating is num) ? rating.floor() : 0;
                                return Icon(
                                  Icons.star,
                                  size: 16,
                                  color: i < safeRating
                                      ? Colors.amber[600]
                                      : Colors.grey[300],
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${hospital['rating'] ?? '0'} (${hospital['reviews'] ?? 0} reviews)',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Info Grid
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.place_outlined,
                      '${hospital['distance_km'] ?? '?'} km away',
                      const Color(0xFF059669),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.access_time,
                      hospital['waitTime'] ?? 'N/A',
                      const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Address
              _buildInfoItem(
                Icons.location_on_outlined,
                hospital['address'] ?? 'Address not available',
                const Color(0xFF6B7280),
              ),
              const SizedBox(height: 16),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed:
                          isOpen ? () => _bookAppointment(hospital) : null,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(isOpen ? 'Book Now' : 'Closed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isOpen ? Colors.teal : Colors.grey[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final phone = hospital['phone'];
                        if (phone != null && phone.isNotEmpty) {
                          _makePhoneCall(phone);
                        } else {
                          _showErrorSnackBar('Phone number not available');
                        }
                      },
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal,
                        side: const BorderSide(color: Color(0xFF0891B2)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Emergency Badge
              if (hasEmergency) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emergency, size: 16, color: Colors.red[600]),
                      const SizedBox(width: 4),
                      Text(
                        '24/7 Emergency Services',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isOpen = status.toLowerCase() == 'open';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isOpen ? const Color(0xFF166534) : const Color(0xFFDC2626),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _bookAppointment(Map<String, dynamic> hospital) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildBookingBottomSheet(hospital),
    );
  }

  Widget _buildBookingBottomSheet(Map<String, dynamic> hospital) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Book Appointment',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hospital['facility_name'] ?? 'Unknown Hospital',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Booking system integration coming soon!',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'For now, please call the hospital directly to schedule your appointment.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    final phone = hospital['phone'];
                    if (phone != null && phone.isNotEmpty) {
                      _makePhoneCall(phone);
                    } else {
                      _showErrorSnackBar('Phone number not available');
                    }
                  },
                  child: const Text('Call Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHospitalDetails(Map<String, dynamic> hospital) {
    _showSuccessSnackBar(
        'Detailed view for ${hospital['facility_name']} coming soon!');
  }
}
