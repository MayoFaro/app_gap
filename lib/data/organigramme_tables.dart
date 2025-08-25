// lib/data/organigramme_tables.dart
//
// Table locale minimaliste pour l'organigramme.
// Doc Firestore: collection 'organigramme', docId = userId (identique à /users/{userId})
// Champs: parentId (nullable), updatedAt (optionnel côté serveur)

import 'package:drift/drift.dart';

class OrganigrammeNodes extends Table {
  // Identifiant utilisateur (doit correspondre à /users/{userId})
  TextColumn get userId => text()(); // PK
  TextColumn get parentId => text().nullable()();

  // Optionnel: suivi de mise à jour côté serveur (si présent)
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {userId};
}
