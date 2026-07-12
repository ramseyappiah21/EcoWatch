import 'package:equatable/equatable.dart';

import 'enums.dart';

/// Authenticated or anonymous user profile.
/// No device identifiers stored — privacy by design.
class User extends Equatable {
  const User({
    required this.id,
    required this.displayName,
    required this.role,
    this.email,
    this.phoneNumber,
    this.organization,
    this.createdAt,
    this.lastLoginAt,
    this.preferences = const UserPreferences(),
  });

  final String id;
  final String displayName;
  final UserRole role;
  final String? email;
  final String? phoneNumber;
  final String? organization;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final UserPreferences preferences;

  bool get isAnonymous => role == UserRole.anonymous;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'role': role.name,
        'email': email,
        'phoneNumber': phoneNumber,
        'organization': organization,
        'createdAt': createdAt?.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'preferences': preferences.toJson(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        role: UserRole.values.byName(json['role'] as String),
        email: json['email'] as String?,
        phoneNumber: json['phoneNumber'] as String?,
        organization: json['organization'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        lastLoginAt: json['lastLoginAt'] != null
            ? DateTime.parse(json['lastLoginAt'] as String)
            : null,
        preferences: json['preferences'] != null
            ? UserPreferences.fromJson(
                json['preferences'] as Map<String, dynamic>,
              )
            : const UserPreferences(),
      );

  User copyWith({
    String? displayName,
    UserRole? role,
    UserPreferences? preferences,
    DateTime? lastLoginAt,
  }) =>
      User(
        id: id,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        email: email,
        phoneNumber: phoneNumber,
        organization: organization,
        createdAt: createdAt,
        lastLoginAt: lastLoginAt ?? this.lastLoginAt,
        preferences: preferences ?? this.preferences,
      );

  @override
  List<Object?> get props => [id, role];
}

class UserPreferences extends Equatable {
  const UserPreferences({
    this.notificationsEnabled = true,
    this.anonymousByDefault = true,
    this.languageCode = 'en',
    this.darkMode = false,
  });

  final bool notificationsEnabled;
  final bool anonymousByDefault;
  final String languageCode;
  final bool darkMode;

  Map<String, dynamic> toJson() => {
        'notificationsEnabled': notificationsEnabled,
        'anonymousByDefault': anonymousByDefault,
        'languageCode': languageCode,
        'darkMode': darkMode,
      };

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
        anonymousByDefault: json['anonymousByDefault'] as bool? ?? true,
        languageCode: json['languageCode'] as String? ?? 'en',
        darkMode: json['darkMode'] as bool? ?? false,
      );

  UserPreferences copyWith({
    bool? notificationsEnabled,
    bool? anonymousByDefault,
    bool? darkMode,
  }) =>
      UserPreferences(
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
        anonymousByDefault: anonymousByDefault ?? this.anonymousByDefault,
        languageCode: languageCode,
        darkMode: darkMode ?? this.darkMode,
      );

  @override
  List<Object?> get props =>
      [notificationsEnabled, anonymousByDefault, languageCode, darkMode];
}
