// lib/data/user_dao.dart

import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:drift/drift.dart';
import 'app_database.dart';

/// Data Access Object for looking up local users by email (in the Drift database).
class UserDao {
  final AppDatabase db;
  UserDao(this.db);

  /// Tries to find a local Users row whose `email` column matches [email].
  /// Prints debug information along the way.
  Future<User?> getUserByEmail(String email) async {
    debugPrint('UserDao ▶ Looking up user by email="$email"');
    final query = db.select(db.users)
      ..where((tbl) => tbl.email.equals(email));
    final userRow = await query.getSingleOrNull();
    debugPrint('UserDao ▶ getUserByEmail result: $userRow');
    return userRow;
  }
}
