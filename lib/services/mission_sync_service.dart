// lib/services/mission_sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/mission_dao.dart';

const String kMissionsCollection = 'missions';

class MissionSyncService {
  final AppDatabase db;
  final MissionDao dao;
  final fs.FirebaseFirestore _firestore;

  MissionSyncService({
    required this.db,
    required this.dao,
    fs.FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? fs.FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  DateTime _getDate(dynamic v) {
    if (v is fs.Timestamp) return v.toDate();
    if (v is DateTime) return v;
    throw ArgumentError('Invalid date value: $v');
  }

  String? _getOptString(dynamic v) {
    if (v == null) return null;
    if (v is String && v.trim().isEmpty) return null;
    if (v is String && v.trim() == '--') return null;
    return v as String?;
  }

  // ---------------------------------------------------------------------------
  // Remote -> Local
  // ---------------------------------------------------------------------------

  /// Récupère toutes les missions Firestore et les “merge” en local
  /// (insert si absente, update sinon).
  Future<void> pullFromRemote() async {
    final snap = await _firestore.collection(kMissionsCollection).get();
    debugPrint('SYNC[pull]: fetched ${snap.docs.length} docs');

    for (final doc in snap.docs) {
      final data = doc.data();
      final remoteId = doc.id;

      final dt = _getDate(data['date']);
      final vecteur = (data['vecteur'] as String?) ?? 'ATR72';
      final pilote1 = (data['pilote1'] as String?) ?? '';
      final pilote2 = _getOptString(data['pilote2']);
      final pilote3 = _getOptString(data['pilote3']);
      final destinationCode = (data['destinationCode'] as String?) ?? '--';
      final description = _getOptString(data['description']);

      // Timestamps distants (optionnels)
      final DateTime? createdAtRemote =
      data['createdAt'] is fs.Timestamp ? (data['createdAt'] as fs.Timestamp).toDate() : null;
      final DateTime? updatedAtRemote =
      data['updatedAt'] is fs.Timestamp ? (data['updatedAt'] as fs.Timestamp).toDate() : null;

      final existing = await dao.getByRemoteId(remoteId);//The method 'getByRemoteId' isn't defined for the type 'MissionDao'.

      if (existing == null) {
        // INSERT local
        final comp = MissionsCompanion.insert(
          date: dt,
          vecteur: vecteur,
          pilote1: pilote1,
          destinationCode: destinationCode,
          // optionnels
          pilote2: Value(pilote2),
          pilote3: Value(pilote3),
          description: Value(description),
          remoteId: Value(remoteId),
          // createdAt non-nullable : on met la valeur Firestore si dispo, sinon on laisse ABSENT
          createdAt: createdAtRemote != null ? Value(createdAtRemote) : const Value.absent(),
          // updatedAt nullable
          updatedAt: updatedAtRemote != null ? Value(updatedAtRemote) : const Value.absent(),
        );

        await dao.insertMission(comp);
        debugPrint('SYNC[pull]: inserted $remoteId');
      } else {
        // UPDATE local : respecter les types de copyWith
        final updated = existing.copyWith(
          date: dt,                     // non-nullable => brut
          vecteur: vecteur,             // non-nullable => brut
          pilote1: pilote1,             // non-nullable => brut
          destinationCode: destinationCode, // non-nullable => brut
          // nullable => Value(...)
          pilote2: Value(pilote2),
          pilote3: Value(pilote3),
          description: Value(description),
          remoteId: Value(remoteId),
          // createdAt est non-nullable localement : on NE LE TOUCHE PAS (on garde la valeur locale)
          // updatedAt est nullable => Value(...)
          updatedAt: Value(updatedAtRemote),
        );

        await dao.updateMission(updated);
        debugPrint('SYNC[pull]: updated $remoteId');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Local -> Remote
  // ---------------------------------------------------------------------------

  /// Création distante d’une mission locale (qui n’a pas encore de remoteId).
  /// Met ensuite à jour la ligne locale (remoteId, updatedAt).
  Future<void> pushLocalCreate(Mission m) async {
    final now = DateTime.now();

    final payload = <String, dynamic>{
      'date': fs.Timestamp.fromDate(m.date),
      'vecteur': m.vecteur,
      'pilote1': m.pilote1,
      if (m.pilote2 != null && m.pilote2!.isNotEmpty) 'pilote2': m.pilote2,
      if (m.pilote3 != null && m.pilote3!.isNotEmpty) 'pilote3': m.pilote3,
      'destinationCode': m.destinationCode,
      if (m.description != null && m.description!.isNotEmpty) 'description': m.description,
      'createdAt': fs.Timestamp.fromDate(m.createdAt), // colonne non-nullable locale
      'updatedAt': fs.Timestamp.fromDate(now),
    };

    final ref = await _firestore.collection(kMissionsCollection).add(payload);
    final remoteId = ref.id;

    // copyWith : respecter les types
    final localUpdated = m.copyWith(
      remoteId: Value(remoteId), // nullable => Value(...)
      updatedAt: Value(now),     // nullable => Value(...)
      // createdAt non-nullable : on ne le modifie pas (on garde la valeur mise par la DB)
    );

    await dao.updateMission(localUpdated);
    debugPrint('SYNC[create->remote]: created $remoteId');
  }

  /// Mise à jour distante de la mission locale (qui a un remoteId).
  /// Met ensuite à jour le updatedAt local.
  Future<void> pushLocalUpdate(Mission m) async {
    if (m.remoteId == null || m.remoteId!.isEmpty) {
      debugPrint('SYNC[update->remote]: skip, no remoteId for local id=${m.id}');
      return;
    }
    final now = DateTime.now();

    final payload = <String, dynamic>{
      'date': fs.Timestamp.fromDate(m.date),
      'vecteur': m.vecteur,
      'pilote1': m.pilote1,
      if (m.pilote2 != null && m.pilote2!.isNotEmpty) 'pilote2': m.pilote2 else 'pilote2': null,
      if (m.pilote3 != null && m.pilote3!.isNotEmpty) 'pilote3': m.pilote3 else 'pilote3': null,
      'destinationCode': m.destinationCode,
      'description': (m.description != null && m.description!.isNotEmpty) ? m.description : null,
      'updatedAt': fs.Timestamp.fromDate(now),
    };

    await _firestore.collection(kMissionsCollection).doc(m.remoteId).set(
      payload,
      fs.SetOptions(merge: true),
    );

    await dao.updateMission(m.copyWith(updatedAt: Value(now)));
    debugPrint('SYNC[update->remote]: updated ${m.remoteId}');
  }

  /// Suppression distante si remoteId présent.
  Future<void> pushLocalDelete(Mission m) async {
    if (m.remoteId == null || m.remoteId!.isEmpty) return;
    await _firestore.collection(kMissionsCollection).doc(m.remoteId).delete();
    debugPrint('SYNC[delete->remote]: deleted ${m.remoteId}');
  }
}
