import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HospitalFinderScreen extends StatelessWidget {
  const HospitalFinderScreen({super.key});
  static const routeName = '/hospital_finder';

  final List<Map<String, String>> hospitals = const [
    {
      'name': 'City General Hospital',
      'specialty': 'Emergency Medicine',
      'distance': '1.2 km away',
      'rating': '4.5',
      'address': '123 Main Street, Downtown',
      'phone': '+1 (555) 123-4567',
      'waitTime': '15-20 min',
      'status': 'Open',
    },
    {
      'name': 'St. Mary\'s Medical Center',
      'specialty': 'Internal Medicine',
      'distance': '2.8 km away',
      'rating': '4.8',
      'address': '456 Oak Avenue, Midtown',
      'phone': '+1 (555) 234-5678',
      'waitTime': '30-45 min',
      'status': 'Open',
    },
    {
      'name': 'University Health Clinic',
      'specialty': 'Medical Emergency?',
      'distance': '',
      'rating': '',
      'address': '',
      'phone': '112',
      'waitTime': '60+ min',
      'status': 'Closed',
    },
  ];

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('Could not launch $phoneNumber');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // light background
      appBar: AppBar(
        title: const Text('Hospital Recommendations'),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.list, color: Colors.white),
            onPressed: () {}, // future List View toggle
          ),
          IconButton(
            icon: const Icon(Icons.map, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Map view coming soon!')),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: hospitals.length,
        itemBuilder: (context, index) {
          final hospital = hospitals[index];
          return Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hospital Name + Status Chip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          hospital['name']!,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          hospital['status'] ?? 'Unknown',
                          style: TextStyle(
                            color: hospital['status'] == 'Open'
                                ? Colors.green[800]
                                : Colors.red[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: hospital['status'] == 'Open'
                            ? Colors.green[100]
                            : Colors.red[100],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hospital['specialty']!,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  // Distance & Rating Row
                  Row(
                    children: [
                      if (hospital['distance']!.isNotEmpty)
                        Icon(Icons.location_on, color: Colors.teal[400], size: 18),
                      const SizedBox(width: 4),
                      Text(hospital['distance'] ?? ''),
                      const SizedBox(width: 10),
                      if (hospital['rating']!.isNotEmpty)
                        Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(hospital['rating'] ?? ''),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Address
                  if (hospital['address']!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.place, size: 18, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(hospital['address']!),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  // Phone (Clickable)
                  GestureDetector(
                    onTap: () => _makePhoneCall(hospital['phone']!),
                    child: Row(
                      children: [
                        const Icon(Icons.phone, size: 18, color: Colors.teal),
                        const SizedBox(width: 4),
                        Text(
                          hospital['phone']!,
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Estimated Wait: ${hospital['waitTime']}',
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  // Book Now button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Booking feature coming soon for ${hospital['name']}!'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Book Now',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
