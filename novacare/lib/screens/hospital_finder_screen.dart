import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HospitalFinderScreen extends StatefulWidget {
  const HospitalFinderScreen({super.key});
  static const routeName = '/hospital_finder';

  @override
  State<HospitalFinderScreen> createState() => _HospitalFinderScreenState();
}

class _HospitalFinderScreenState extends State<HospitalFinderScreen> {
  String _selectedFilter = 'All';
  bool _isMapView = false;

  final List<Map<String, dynamic>> hospitals = const [
    {
      'name': 'City General Hospital',
      'specialty': 'Emergency Medicine',
      'distance': 1.2,
      'rating': 4.5,
      'reviews': 324,
      'address': '123 Main Street, Downtown',
      'phone': '+1 (555) 123-4567',
      'waitTime': '15-20 min',
      'status': 'Open',
      'isEmergency': true,
      'acceptsInsurance': true,
      'image': 'assets/hospital1.jpg', // placeholder
    },
    {
      'name': 'St. Mary\'s Medical Center',
      'specialty': 'Internal Medicine',
      'distance': 2.8,
      'rating': 4.8,
      'reviews': 156,
      'address': '456 Oak Avenue, Midtown',
      'phone': '+1 (555) 234-5678',
      'waitTime': '30-45 min',
      'status': 'Open',
      'isEmergency': false,
      'acceptsInsurance': true,
      'image': 'assets/hospital2.jpg', // placeholder
    },
    {
      'name': 'University Health Clinic',
      'specialty': 'General Practice',
      'distance': 3.5,
      'rating': 4.2,
      'reviews': 89,
      'address': '789 University Blvd, Campus',
      'phone': '+1 (555) 345-6789',
      'waitTime': '60+ min',
      'status': 'Closed',
      'isEmergency': false,
      'acceptsInsurance': false,
      'image': 'assets/hospital3.jpg', // placeholder
    },
  ];

  List<String> get filterOptions => ['All', 'Emergency', 'Open Now', 'Nearby'];

  List<Map<String, dynamic>> get filteredHospitals {
    switch (_selectedFilter) {
      case 'Emergency':
        return hospitals.where((h) => h['isEmergency'] == true).toList();
      case 'Open Now':
        return hospitals.where((h) => h['status'] == 'Open').toList();
      case 'Nearby':
        return hospitals.where((h) => h['distance'] <= 2.0).toList();
      default:
        return hospitals;
    }
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
        backgroundColor: const Color(0xFF0891B2), // Modern teal
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
      body: Column(
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
                              color: isSelected ? Colors.white : const Color(0xFF6B7280),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilter = filter;
                            });
                          },
                          backgroundColor: const Color(0xFFF3F4F6),
                          selectedColor: const Color(0xFF0891B2),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFB),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredHospitals.length} hospital${filteredHospitals.length != 1 ? 's' : ''} found',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Sorted by distance',
                  style: const TextStyle(
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
              itemCount: filteredHospitals.length,
              itemBuilder: (context, index) {
                final hospital = filteredHospitals[index];
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
    final isOpen = hospital['status'] == 'Open';
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
                      color: const Color(0xFF0891B2).withOpacity(0.1),
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
                                hospital['name']!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            _buildStatusChip(hospital['status']),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hospital['specialty']!,
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
                            ...List.generate(5, (i) => Icon(
                              Icons.star,
                              size: 16,
                              color: i < hospital['rating'].floor()
                                  ? Colors.amber[600]
                                  : Colors.grey[300],
                            )),
                            const SizedBox(width: 8),
                            Text(
                              '${hospital['rating']} (${hospital['reviews']} reviews)',
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
                      '${hospital['distance']} km away',
                      const Color(0xFF059669),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.access_time,
                      hospital['waitTime'],
                      const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Address
              _buildInfoItem(
                Icons.location_on_outlined,
                hospital['address'],
                const Color(0xFF6B7280),
              ),
              const SizedBox(height: 16),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: isOpen ? () => _bookAppointment(hospital) : null,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(isOpen ? 'Book Now' : 'Closed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOpen ? const Color(0xFF0891B2) : Colors.grey[400],
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
                      onPressed: () => _makePhoneCall(hospital['phone']!),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0891B2),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    final isOpen = status == 'Open';
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
          Text(
            'Book Appointment',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hospital['name'],
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
                    _makePhoneCall(hospital['phone']);
                  },
                  child: const Text('Call Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0891B2),
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
    _showSuccessSnackBar('Detailed view for ${hospital['name']} coming soon!');
  }
}