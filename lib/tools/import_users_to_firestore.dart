import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/*** Fiohier destiné uniquement à mettre à jour le users.json vers le firestore database.
Pour l'utiliser, une fois le users.json mis à jour, exéctuer la commande suivante:
flutter run -t lib/tools/import_users_to_firestore.dart
si nécessaire, modifier les regles de la firestore database:
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;  // ❗️ACCÈS TOTAL pour dev uniquement
    }
  }
}
puis, apres l'import, remettre celles ci:
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.token.email == resource.data.email;
    }
  }
}
 ***/

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  try {
    final raw = await rootBundle.loadString('assets/users.json');
    final List<dynamic> users = json.decode(raw);

    print('➡️ Début de l’injection de ${users.length} utilisateurs');

    for (final user in users) {
      final trigramme = user['trigramme'] as String?;
      if (trigramme == null) {
        print('⚠️ Utilisateur sans trigramme, ignoré');
        continue;
      }

      await firestore.collection('users').doc(trigramme).set({
        'email': user['email'],
        'trigramme': trigramme,
        'role': user['role'],
        'fonction': user['fonction'],
        'group': user['group'],
        'fullName': user['fullName'],
        'phone': user['phone'],
        'isAdmin': user['isAdmin'],
      }, SetOptions(merge: true));

      print('✅ $trigramme ajouté à Firestore');
    }

    print('🎉 Injection terminée.');
  } catch (e) {
    print('❌ Erreur lors de l’injection : $e');
  }
}
