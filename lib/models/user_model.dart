import 'package:drift/drift.dart';

class UserModel {
  final String trigramme;
  final String group;
  final String fonction;
  final String role;
  final String email;
  final String fullName;
  final String phone;
  final bool isAdmin;

  UserModel({
    required this.trigramme,
    required this.group,
    required this.fonction,
    required this.role,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.isAdmin,
  });

  factory UserModel.fromJson(Map<String, dynamic> data, String email) {
    return UserModel(
      trigramme: data['trigramme'] ?? '',
      group: data['group'] ?? '',
      fonction: data['fonction'] ?? '',
      role: data['role'] ?? '',
      email: email,
      fullName: data['fullName'] ?? '',
      phone: data['phone'] ?? '',
      isAdmin: data['isAdmin'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trigramme': trigramme,
      'group': group,
      'fonction': fonction,
      'role': role,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'isAdmin': isAdmin,
    };
  }

  factory UserModel.fromDriftRow(dynamic row) {
    return UserModel(
      trigramme: row.trigramme,
      group: row.group,
      fonction: row.fonction,
      role: row.role,
      email: row.email ?? '',
      fullName: row.fullName ?? '',
      phone: row.phone ?? '',
      isAdmin: row.isAdmin ?? false,
    );
  }
}
