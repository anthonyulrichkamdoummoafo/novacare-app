class Hospital {
  final String id;
  final String name;
  final String type;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String status;
  final double rating;
  final int reviewCount;
  final String waitTime;
  final bool isEmergency;
  final String? phoneNumber;
  final List<String> services;
  final String? address;
  final Map<String, String>? operatingHours;
  final String? website;
  final String? email;

  const Hospital({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.status = 'Unknown',
    this.rating = 0.0,
    this.reviewCount = 0,
    this.waitTime = 'N/A',
    this.isEmergency = false,
    this.phoneNumber,
    this.services = const [],
    this.address,
    this.operatingHours,
    this.website,
    this.email,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: json['id']?.toString() ??
          '${json['facility_name']}_${json['latitude']}_${json['longitude']}',
      name: json['facility_name'] ?? json['name'] ?? 'Unknown Hospital',
      type: json['facility_type'] ?? json['type'] ?? 'General',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Unknown',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviews'] as num?)?.toInt() ?? 0,
      waitTime: json['waitTime']?.toString() ?? 'N/A',
      isEmergency: json['isEmergency'] == true,
      phoneNumber: json['phone']?.toString(),
      services:
          json['services'] != null ? List<String>.from(json['services']) : [],
      address: json['address']?.toString(),
      operatingHours: json['operating_hours'] != null
          ? Map<String, String>.from(json['operating_hours'])
          : null,
      website: json['website']?.toString(),
      email: json['email']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'facility_name': name,
      'facility_type': type,
      'latitude': latitude,
      'longitude': longitude,
      'distance_km': distanceKm,
      'status': status,
      'rating': rating,
      'reviews': reviewCount,
      'waitTime': waitTime,
      'isEmergency': isEmergency,
      'phone': phoneNumber,
      'services': services,
      'address': address,
      'operating_hours': operatingHours,
      'website': website,
      'email': email,
    };
  }

  Hospital copyWith({
    String? id,
    String? name,
    String? type,
    double? latitude,
    double? longitude,
    double? distanceKm,
    String? status,
    double? rating,
    int? reviewCount,
    String? waitTime,
    bool? isEmergency,
    String? phoneNumber,
    List<String>? services,
    String? address,
    Map<String, String>? operatingHours,
    String? website,
    String? email,
  }) {
    return Hospital(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceKm: distanceKm ?? this.distanceKm,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      waitTime: waitTime ?? this.waitTime,
      isEmergency: isEmergency ?? this.isEmergency,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      services: services ?? this.services,
      address: address ?? this.address,
      operatingHours: operatingHours ?? this.operatingHours,
      website: website ?? this.website,
      email: email ?? this.email,
    );
  }

  bool get isOpen {
    return status.toLowerCase().contains('open');
  }

  bool get isHighRated {
    return rating >= 4.0;
  }

  String get formattedDistance {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m away';
    } else {
      return '${distanceKm.toStringAsFixed(1)}km away';
    }
  }

  String get statusColor {
    switch (status.toLowerCase()) {
      case 'open':
      case 'open 24/7':
        return 'green';
      case 'closed':
        return 'red';
      case 'busy':
        return 'orange';
      default:
        return 'grey';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Hospital && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Hospital(id: $id, name: $name, type: $type, distance: $formattedDistance)';
  }
}
