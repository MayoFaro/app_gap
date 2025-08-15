// lib/data/planning_dao.dart
//
// DAO Drift + synchro Firestore pour PlanningEvents.
// Nouveautés :
// - updateEventByFirestoreId(...)
// - deleteEventByFirestoreId(...)
// pour permettre l’édition/suppression depuis l’écran Planning où l’on lit Firestore directement.

import 'package:drift/drift.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;

import 'app_database.dart';

part 'planning_dao.g.dart';

@DriftAccessor(tables: [Users, PlanningEvents])
class PlanningDao extends DatabaseAccessor<AppDatabase> with _$PlanningDaoMixin {
  PlanningDao(AppDatabase db) : super(db);

  fs.CollectionReference<Map<String, dynamic>> get _col =>
      fs.FirebaseFirestore.instance.collection('planningEvents');

  /// Stream local par trigramme (si utile ailleurs).
  Stream<List<PlanningEvent>> watchEventsForUser(String trigramme) {
    return (select(planningEvents)..where((e) => e.user.equals(trigramme)))
        .watch();
  }

  /// Insert Firestore puis local.
  /// [user] = trigramme; Firestore stocke user=UID.
  Future<void> insertEvent({
    required String user,
    required String typeEvent,
    required DateTime dateStart,
    required DateTime dateEnd,
    int? rank, // 1..3 pour TWR, sinon null
  }) async {
    final uid = fbAuth.FirebaseAuth.instance.currentUser?.uid ?? '';
    String? firestoreId;

    try {
      if (uid.isNotEmpty) {
        final payload = <String, dynamic>{
          'user': uid,
          'typeEvent': typeEvent,
          'dateStart': fs.Timestamp.fromDate(dateStart),
          'dateEnd': fs.Timestamp.fromDate(dateEnd),
          'createdAt': fs.FieldValue.serverTimestamp(),
          'trigramme': user,
        };
        if (typeEvent == 'TWR' && rank != null) {
          payload['rank'] = rank;
        }
        final doc = await _col.add(payload);
        firestoreId = doc.id;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Firestore insert ERROR: $e');
    }

    await into(planningEvents).insert(
      PlanningEventsCompanion.insert(
        user: user,
        typeEvent: typeEvent,
        dateStart: dateStart,
        dateEnd: dateEnd,
        uid: Value(uid),
        firestoreId: Value(firestoreId),
        rank: Value(rank),
      ),
    );
  }

  /// Met à jour par id local (historiquement).
  Future<int> updateEvent({
    required int id,
    required DateTime dateStart,
    required DateTime dateEnd,
    int? rank,
  }) async {
    final row = await (select(planningEvents)..where((e) => e.id.equals(id)))
        .getSingle();

    String? fsId = row.firestoreId;
    final uid = fbAuth.FirebaseAuth.instance.currentUser?.uid ?? row.uid;

    if (fsId == null || fsId.isEmpty) {
      try {
        if (uid.isEmpty) throw Exception('No Firebase UID available');
        final payload = <String, dynamic>{
          'user': uid,
          'typeEvent': row.typeEvent,
          'dateStart': fs.Timestamp.fromDate(row.dateStart),
          'dateEnd': fs.Timestamp.fromDate(row.dateEnd),
          'createdAt': fs.FieldValue.serverTimestamp(),
          'trigramme': row.user,
        };
        if (row.typeEvent == 'TWR' && (row.rank != null)) {
          payload['rank'] = row.rank;
        }
        final doc = await _col.add(payload);
        fsId = doc.id;

        await (update(planningEvents)..where((e) => e.id.equals(id))).write(
          PlanningEventsCompanion(
            firestoreId: Value(fsId),
            uid: Value(uid),
          ),
        );
      } catch (e) {
        // ignore: avoid_print
        print('Firestore create-before-update ERROR: $e');
      }
    }

    if (fsId != null && fsId.isNotEmpty) {
      final updateMap = <String, dynamic>{
        'dateStart': fs.Timestamp.fromDate(dateStart),
        'dateEnd': fs.Timestamp.fromDate(dateEnd),
      };
      if (rank != null) {
        updateMap['rank'] = rank;
      }
      try {
        await _col.doc(fsId).update(updateMap);
      } catch (e) {
        // ignore: avoid_print
        print('Firestore update ERROR: $e');
      }
    }

    return (update(planningEvents)..where((e) => e.id.equals(id))).write(
      PlanningEventsCompanion(
        dateStart: Value(dateStart),
        dateEnd: Value(dateEnd),
        rank: rank != null ? Value(rank) : const Value.absent(),
      ),
    );
  }

  /// Supprime par id local.
  Future<int> deleteEvent(int id) async {
    final row = await (select(planningEvents)..where((e) => e.id.equals(id)))
        .getSingle();
    final fsId = row.firestoreId;
    if (fsId != null && fsId.isNotEmpty) {
      await _col.doc(fsId).delete();
    }
    return (delete(planningEvents)..where((e) => e.id.equals(id))).go();
  }

  // ---------------------------
  //  Nouveaux helpers Firestore
  // ---------------------------

  /// Update par firestoreId (utile quand l’event vient de Firestore sans id local).
  Future<void> updateEventByFirestoreId({
    required String firestoreId,
    DateTime? dateStart,
    DateTime? dateEnd,
    int? rank,
  }) async {
    final updateMap = <String, dynamic>{};
    if (dateStart != null) updateMap['dateStart'] = fs.Timestamp.fromDate(dateStart);
    if (dateEnd != null) updateMap['dateEnd'] = fs.Timestamp.fromDate(dateEnd);
    if (rank != null) updateMap['rank'] = rank;

    if (updateMap.isNotEmpty) {
      await _col.doc(firestoreId).update(updateMap);
    }

    // réplique local si présent
    await (update(planningEvents)..where((e) => e.firestoreId.equals(firestoreId))).write(
      PlanningEventsCompanion(
        dateStart: dateStart != null ? Value(dateStart) : const Value.absent(),
        dateEnd:   dateEnd   != null ? Value(dateEnd)   : const Value.absent(),
        rank:      rank      != null ? Value(rank)      : const Value.absent(),
      ),
    );
  }

  /// Delete par firestoreId.
  Future<void> deleteEventByFirestoreId(String firestoreId) async {
    await _col.doc(firestoreId).delete();
    await (delete(planningEvents)..where((e) => e.firestoreId.equals(firestoreId))).go();
  }

  /// Push offline → online (si besoin).
  Future<void> pushPendingToFirestore() async {
    final uid = fbAuth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final pending = await (select(planningEvents)
      ..where((e) => e.firestoreId.isNull()))
        .get();

    for (final row in pending) {
      try {
        final payload = <String, dynamic>{
          'user': uid,
          'typeEvent': row.typeEvent,
          'dateStart': fs.Timestamp.fromDate(row.dateStart),
          'dateEnd': fs.Timestamp.fromDate(row.dateEnd),
          'createdAt': fs.FieldValue.serverTimestamp(),
          'trigramme': row.user,
        };
        if (row.typeEvent == 'TWR' && row.rank != null) {
          payload['rank'] = row.rank;
        }
        final doc = await _col.add(payload);
        await (update(planningEvents)..where((e) => e.id.equals(row.id))).write(
          PlanningEventsCompanion(
            firestoreId: Value(doc.id),
            uid: Value(uid),
          ),
        );
      } catch (e) {
        // ignore: avoid_print
        print('pushPendingToFirestore ERROR for local id=${row.id}: $e');
      }
    }
  }
}
