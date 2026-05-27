class AhviContact {
  const AhviContact({
    required this.id,
    required this.firstName,
    required this.phoneNumber,
    this.lastName = '',
    this.displayName = '',
    this.relationship = '',
    this.notes = '',
    this.tags = const [],
    this.isFavorite = false,
    this.avatarUrl = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String displayName;
  final String relationship;
  final String notes;
  final List<String> tags;
  final bool isFavorite;
  final String avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fullName {
    final name = displayName.trim().isNotEmpty
        ? displayName.trim()
        : '$firstName $lastName'.trim();
    return name.isEmpty ? phoneNumber : name;
  }

  String get initials {
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  factory AhviContact.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return AhviContact(
      id: (json['id'] ?? json[r'$id'] ?? '').toString(),
      firstName: (json['firstName'] ?? json['firstname'] ?? '').toString(),
      lastName: (json['lastName'] ?? json['surname'] ?? '').toString(),
      phoneNumber: (json['phoneNumber'] ?? json['phoneno'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      relationship: (json['relationship'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      tags: (json['tags'] is List)
          ? (json['tags'] as List).map((item) => item.toString()).toList()
          : const [],
      isFavorite: json['isFavorite'] == true,
      avatarUrl: (json['avatarUrl'] ?? '').toString(),
      createdAt: parseDate(json['createdAt'] ?? json[r'$createdAt']),
      updatedAt: parseDate(json['updatedAt'] ?? json[r'$updatedAt']),
    );
  }
}

class AhviContactInput {
  const AhviContactInput({
    required this.firstName,
    required this.phoneNumber,
    this.lastName = '',
    this.displayName = '',
    this.relationship = '',
    this.notes = '',
    this.tags = const [],
    this.isFavorite = false,
    this.avatarUrl = '',
  });

  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String displayName;
  final String relationship;
  final String notes;
  final List<String> tags;
  final bool isFavorite;
  final String avatarUrl;

  Map<String, dynamic> toJson() => {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'displayName': displayName.trim(),
        'relationship': relationship.trim(),
        'notes': notes.trim(),
        'tags': tags
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(),
        'isFavorite': isFavorite,
        'avatarUrl': avatarUrl.trim(),
      };
}
