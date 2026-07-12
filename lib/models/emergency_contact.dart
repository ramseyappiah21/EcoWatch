import 'package:equatable/equatable.dart';

class EmergencyContact extends Equatable {
  const EmergencyContact({
    required this.name,
    required this.agency,
    required this.phone,
    this.description,
  });

  final String name;
  final String agency;
  final String phone;
  final String? description;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        name: json['name'] as String,
        agency: json['agency'] as String,
        phone: json['phone'] as String,
        description: json['description'] as String?,
      );

  @override
  List<Object?> get props => [name, agency, phone];
}
