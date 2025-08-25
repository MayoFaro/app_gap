// lib/sync/organigramme_sync.dart
//
// Use-case autonome de synchronisation de l'organigramme.
// A appeler depuis ton SyncService existant, ex:
//   await syncOrganigramme(db, FirebaseFirestore.instance);

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/organigramme_dao.dart';

/// Synchronise la collection Firestore 'organigramme' vers Drift.
/// - Upsert de chaque nœud (userId = doc.id, parentId)
/// - Nettoyage local des entrées absentes du remote
Future<void> syncOrganigramme(AppDatabase db, fs.FirebaseFirestore firestore) async {
  debugPrint('SYNC[organigramme]: start');

  final dao = OrganigrammeDao(db);
  final col = firestore.collection('organigramme');

  // Récupération complète (peu d'entrées, généralement)
  final snap = await col.get();

  // Pour le nettoyage
  final remoteIds = <String>{};

  int upserts = 0;

  for (final doc in snap.docs) {
    final data = doc.data();
    final userId = doc.id; // identique à /users/{userId}
    final parentId = (data['parentId'] as String?)?.trim();
    final ts = data['updatedAt'];
    final updatedAt =
    (ts is fs.Timestamp) ? ts.toDate() : null;

    await dao.upsertNode(
      userId: userId,
      parentId: (parentId != null && parentId.isNotEmpty) ? parentId : null,
      updatedAt: updatedAt,
    );
    remoteIds.add(userId);
    upserts++;
  }

  // Nettoyage local des entrées qui n'existent plus côté remote
  final deleted = await dao.deleteWhereNotIn(remoteIds);

  debugPrint('SYNC[organigramme]: upserts=$upserts, deleted=$deleted');
  debugPrint('SYNC[organigramme]: done');
}
