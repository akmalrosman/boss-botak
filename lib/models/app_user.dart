enum UserRole {
  customer,
  admin;

  static UserRole parse(String? v) => v == 'admin' ? admin : customer;
}

/// A signed-in user's profile (customer or the business owner/admin).
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone = '',
    this.role = UserRole.customer,
    this.address = '',
    this.lat,
    this.lng,
    this.createdAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;

  /// Default delivery address (filled using GPS + reverse geocoding).
  final String address;
  final double? lat;
  final double? lng;
  final DateTime? createdAt;

  bool get isAdmin => role == UserRole.admin;
  bool get hasLocation => lat != null && lng != null;

  AppUser copyWith({
    String? fullName,
    String? phone,
    String? address,
    double? lat,
    double? lng,
  }) {
    return AppUser(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      createdAt: createdAt,
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: m['id'] as String,
        email: (m['email'] as String?) ?? '',
        fullName: (m['full_name'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        role: UserRole.parse(m['role'] as String?),
        address: (m['address'] as String?) ?? '',
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        createdAt: m['created_at'] == null
            ? null
            : DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'phone': phone,
        'role': role.name,
        'address': address,
        'lat': lat,
        'lng': lng,
        'created_at': createdAt?.toIso8601String(),
      };

  /// Fields a user is allowed to change on their own profile.
  Map<String, dynamic> toProfileUpdate() => {
        'full_name': fullName,
        'phone': phone,
        'address': address,
        'lat': lat,
        'lng': lng,
      };
}
