// lib/data/user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appgap/data/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class UserService {
  /// Recherche un utilisateur par email. Retourne un [UserModel] ou null si non trouvé.
  static Future<UserModel?> findUserByEmail(String email, {required AppDatabase db}) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(email).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        // Sauvegarde locale (cache prefs)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userTrigram', data['trigramme'] ?? '');
        await prefs.setString('userGroup', data['group'] ?? '');
        await prefs.setString('fonction', data['fonction'] ?? '');
        await prefs.setString('role', data['role'] ?? '');
        await prefs.setBool('isAdmin', data['isAdmin'] ?? false);

        return UserModel( //The named parameter 'passwordHash' is required, but there's no corresponding argument.
          trigramme: data['trigramme'] ?? '',
          group: data['group'] ?? '',
          fonction: data['fonction'] ?? '', //The named parameter 'fonction' isn't defined.
          role: data['role'] ?? '',
          email: email,
          fullName: data['fullName'] ?? '',
          phone: data['phone'] ?? '',
          isAdmin: data['isAdmin'] ?? false, //The named parameter 'isAdmin' isn't defined.
        );
      }
    } catch (e) {
      print('Erreur Firestore: $e');
    }

    // Fallback : local DB
    final user = await (db.select(db.users)..where((u) => u.email.equals(email))).getSingleOrNull();
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userTrigram', user.trigramme);
      await prefs.setString('userGroup', user.group);
      await prefs.setString('fonction', user.fonction);
      await prefs.setString('role', user.role);
      await prefs.setBool('isAdmin', user.isAdmin);

      return UserModel(
        trigramme: user.trigramme,
        group: user.group,
        fonction: user.fonction,
        role: user.role,
        email: user.email ?? '',
        fullName: user.fullName ?? '',
        phone: user.phone ?? '',
        isAdmin: user.isAdmin,
      );
    }

    return null;
  }
}
