// lib/services/user_service.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Modèle de données pour un utilisateur, tel qu’il apparaît dans assets/users.json
class UserInfo {
  final String trigramme;
  final String role;
  final String group;
  final String fullName;
  final String phone;
  final String email;
  final bool isAdmin;

  UserInfo({
    required this.trigramme,
    required this.role,
    required this.group,
    required this.fullName,
    required this.phone,
    required this.email,
    this.isAdmin = false,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
    trigramme: json['trigramme'] as String,
    role:      json['role'] as String,
    group:     json['group'] as String,
    fullName:  json['fullName'] as String,
    phone:     json['phone'] as String,
    email:     json['email'] as String,
    isAdmin:   json['isAdmin'] == true,
  );
}

/// Service de gestion des utilisateurs statiques (JSON) embarqués
class UserService {
  static List<UserInfo>? _cache;

  /// Charge et met en cache la liste des utilisateurs depuis assets/users.json
  static Future<List<UserInfo>> loadUsers() async {
    if (_cache != null) return _cache!;
    final data = await rootBundle.loadString('assets/users.json');
    final list = json.decode(data) as List<dynamic>;
    _cache = list.map((e) => UserInfo.fromJson(e as Map<String, dynamic>)).toList();
    return _cache!;
  }

  /// Recherche un utilisateur par trigramme (insensible à la casse)
  static Future<UserInfo?> findByTrigramme(String trigramme) async {
    final users = await loadUsers();
    for (var u in users) {
      if (u.trigramme.toUpperCase() == trigramme.toUpperCase()) {
        return u;
      }
    }
    return null;
  }

  /// Recherche un utilisateur par email (insensible à la casse)
  static Future<UserInfo?> findByEmail(String email) async {
    final users = await loadUsers();
    for (var u in users) {
      if (u.email.toLowerCase() == email.toLowerCase()) {
        return u;
      }
    }
    return null;
  }
}
