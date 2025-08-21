// File: lib/data/planning_dao.dart
//
// DAO Planning : accès local (Drift) + push Firestore, avec helpers
// compatibles avec l’UI existante (insertEvent/updateEventByFirestoreId/
// deleteEventByFirestoreId).
//
// Points clés :
// - Correction du bug de type sur copyWith(rank: Value(...)).
// - Réintroduction des 3 méthodes attendues par planning_list.dart.
// - Déduction automatique de l’UID via FirebaseAuth (pas besoin de
//   modifier les écrans).
//
// Note d’architecture : on garde ici le push Firestore pour rester
// cohérent avec MissionDao. Si tu veux, on déplacera plus tard ces
// appels réseau dans SyncService.

import 'package:drift/drift.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/cupertino.dart';

import 'app_database.dart';

part 'planning_dao.g.dart';

const String kPlanningCollection = 'planningEvents';

@DriftAccessor(tables: [PlanningEvents])
class PlanningDao extends DatabaseAccessor<AppDatabase>
    with _$PlanningDaoMixin {
  final AppDatabase _db;
  final fs.CollectionReference<Map<String, dynamic>> _remote =
  fs.FirebaseFirestore.instance.collection(kPlanningCollection);

  PlanningDao(this._db) : super(_db);

  // ---------------------------------------------------------------------------
  // Utils
  // ---------------------------------------------------------------------------

  /// Récupère l'UID courant (sécurité : jamais vide).
  String _currentUid() =>
      auth.FirebaseAuth.instance.currentUser?.uid?.trim().isNotEmpty == true
          ? auth.FirebaseAuth.instance.currentUser!.uid
          : 'unknown';

  // ---------------------------------------------------------------------------
  // CRUD LOCAL (simples)
  // ---------------------------------------------------------------------------

  Future<List<PlanningEvent>> getAll() => select(planningEvents).get();

  Future<PlanningEvent?> getById(int id) =>
      (select(planningEvents)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<PlanningEvent?> getByFirestoreId(String firestoreId) =>
      (select(planningEvents)..where((t) => t.firestoreId.equals(firestoreId)))
          .getSingleOrNull();

  /// Insert local simple (sans réseau)
  Future<int> insertLocal(PlanningEventsCompanion comp) =>
      into(planningEvents).insert(comp);

  /// Update local simple (sans réseau)
  Future<int> updateLocal(int id, PlanningEventsCompanion comp) =>
      (update(planningEvents)..where((t) => t.id.equals(id))).write(comp);

  /// Delete local simple (sans réseau)
  Future<void> deleteLocal(int id) async {
    await (delete(planningEvents)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // QUERIES D'AFFICHAGE (UI)
  // ---------------------------------------------------------------------------

  /// Retourne les events qui **chevauchent** la journée `day`:
  /// [dateEnd] >= startOfDay && [dateStart] < endOfDay
  Future<List<PlanningEvent>> getForDay(DateTime day, {String? forUser}) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final q = select(planningEvents)
      ..where((t) =>
      t.dateEnd.isBiggerOrEqualValue(start) &
      t.dateStart.isSmallerThanValue(end))
      ..orderBy([
            (t) => OrderingTerm.asc(t.dateStart),
            (t) => OrderingTerm.asc(t.rank),
      ]);

    if (forUser != null && forUser.isNotEmpty) {
      q.where((t) => t.user.equals(forUser.toUpperCase()));
    }

    return q.get();
  }

  /// Stream des events qui chevauchent la journée `day`
  Stream<List<PlanningEvent>> watchDay(DateTime day, {String? forUser}) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final q = select(planningEvents)
      ..where((t) =>
      t.dateEnd.isBiggerOrEqualValue(start) &
      t.dateStart.isSmallerThanValue(end))
      ..orderBy([
            (t) => OrderingTerm.asc(t.dateStart),
            (t) => OrderingTerm.asc(t.rank),
      ]);

    if (forUser != null && forUser.isNotEmpty) {
      q.where((t) => t.user.equals(forUser.toUpperCase()));
    }

    return q.watch();
  }

  /// Retourne les events qui chevauchent [start, end[
  Future<List<PlanningEvent>> getForRange(DateTime start, DateTime end,
      {String? forUser}) {
    final q = select(planningEvents)
      ..where((t) =>
      t.dateEnd.isBiggerOrEqualValue(start) &
      t.dateStart.isSmallerThanValue(end))
      ..orderBy([
            (t) => OrderingTerm.asc(t.dateStart),
            (t) => OrderingTerm.asc(t.rank),
      ]);

    if (forUser != null && forUser.isNotEmpty) {
      q.where((t) => t.user.equals(forUser.toUpperCase()));
    }

    return q.get();
  }

  /// Stream des events qui chevauchent [start, end[
  Stream<List<PlanningEvent>> watchRange(DateTime start, DateTime end,
      {String? forUser}) {
    final q = select(planningEvents)
      ..where((t) =>
      t.dateEnd.isBiggerOrEqualValue(start) &
      t.dateStart.isSmallerThanValue(end))
      ..orderBy([
            (t) => OrderingTerm.asc(t.dateStart),
            (t) => OrderingTerm.asc(t.rank),
      ]);

    if (forUser != null && forUser.isNotEmpty) {
      q.where((t) => t.user.equals(forUser.toUpperCase()));
    }

    return q.watch();
  }

  /// Tous les events d’un utilisateur (tri standard)
  Future<List<PlanningEvent>> getForUser(String trigram) {
    return (select(planningEvents)
      ..where((t) => t.user.equals(trigram.toUpperCase()))
      ..orderBy([
            (t) => OrderingTerm.asc(t.dateStart),
            (t) => OrderingTerm.asc(t.rank),
      ]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // SYNC FIRESTORE (PUSH) — créations / mises à jour / suppressions
  // ---------------------------------------------------------------------------

  /// Crée un event local **et** le pousse dans Firestore.
  /// - Si pas de réseau, l'insert Firestore lèvera.
  /// - `uidDefault` est utilisé si `row.uid` est vide (sécurité).
  Future<String> createAndPush(PlanningEventsCompanion comp,
      {required String uidDefault}) async {
    // 1) Insert local
    final localId = await into(planningEvents).insert(comp);
    final row =
    await (select(planningEvents)..where((t) => t.id.equals(localId)))
        .getSingle();

    // 2) Push remote (create)
    final ref =
    await _remote.add(_toRemoteCreateMap(row, uidDefault: uidDefault));

    // 3) Rattache le firestoreId localement
    await (update(planningEvents)..where((t) => t.id.equals(localId))).write(
      PlanningEventsCompanion(firestoreId: Value(ref.id)),
    );

    debugPrint("SYNC[upsert->create][planning]: ${ref.id}");
    return ref.id;
  }

  /// Met à jour un event local **et** pousse la mise à jour dans Firestore.
  /// - Si l'event n'a pas encore de firestoreId → bascule en create.
  Future<void> updateAndPush(int id, PlanningEventsCompanion comp,
      {required String uidDefault}) async {
    final existing =
    await (select(planningEvents)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null) return;

    // 1) Update local
    await (update(planningEvents)..where((t) => t.id.equals(id))).write(comp);

    // 2) Push remote
    if (existing.firestoreId == null) {
      // Pas encore dans Firestore → create
      final ref = await _remote.add(
        _toRemoteCreateMap(
          // IMPORTANT : pour les champs nullable (ex: rank),
          // copyWith attend un Value<int?>.
          existing.copyWith(
            // on fabrique une "vue" locale mise à jour à partir de comp
            user: comp.user.present ? comp.user.value : existing.user,
            typeEvent:
            comp.typeEvent.present ? comp.typeEvent.value : existing.typeEvent,
            dateStart: comp.dateStart.present
                ? comp.dateStart.value
                : existing.dateStart,
            dateEnd:
            comp.dateEnd.present ? comp.dateEnd.value : existing.dateEnd,
            uid: comp.uid.present ? comp.uid.value : existing.uid,
            rank: comp.rank.present
                ? Value<int?>(comp.rank.value)
                : Value<int?>(existing.rank),
          ),
          uidDefault: uidDefault,
        ),
      );

      await (update(planningEvents)..where((t) => t.id.equals(id))).write(
        PlanningEventsCompanion(firestoreId: Value(ref.id)),
      );
      debugPrint("SYNC[upsert->create][planning]: ${ref.id}");
    } else {
      // déjà en Firestore → update
      await _remote.doc(existing.firestoreId!).set(
        _toRemoteUpdateMap(
          await (select(planningEvents)..where((t) => t.id.equals(id)))
              .getSingle(),
          uidDefault: uidDefault,
        ),
        fs.SetOptions(merge: true),
      );
      debugPrint("SYNC[upsert->update][planning]: ${existing.firestoreId}");
    }
  }

  /// Supprime local + Firestore (si firestoreId présent)
  Future<void> deleteAndPush(int id) async {
    final row =
    await (select(planningEvents)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;

    // Supprime local
    await (delete(planningEvents)..where((t) => t.id.equals(id))).go();

    // Supprime Firestore si sync
    if (row.firestoreId != null) {
      await _remote.doc(row.firestoreId!).delete();
      debugPrint("SYNC[delete][planning]: ${row.firestoreId}");
    }
  }

  /// Synchronise **uniquement les créations locales** (lignes sans firestoreId).
  Future<void> syncPendingPlanningEvents({required String uidDefault}) async {
    final pending = await (select(planningEvents)
      ..where((t) => t.firestoreId.isNull()))
        .get();

    for (final ev in pending) {
      final ref = await _remote.add(_toRemoteCreateMap(ev, uidDefault: uidDefault));
      await (update(planningEvents)..where((t) => t.id.equals(ev.id))).write(
        PlanningEventsCompanion(firestoreId: Value(ref.id)),
      );
      debugPrint("SYNC[upsert->create][planning]: ${ref.id}");
    }
  }

  // ---------------------------------------------------------------------------
  // API DE COMPATIBILITÉ AVEC L’UI EXISTANTE
  // ---------------------------------------------------------------------------

  /// Insère un event (local + Firestore).
  /// Signature conservée pour `planning_list.dart`.
  Future<String> insertEvent({
    required String user,
    required String typeEvent,
    required DateTime dateStart,
    required DateTime dateEnd,
    int? rank,
  }) async {
    final comp = PlanningEventsCompanion.insert(
      user: user.toUpperCase(),
      typeEvent: typeEvent,
      dateStart: dateStart,
      dateEnd: dateEnd,
      //uid: _currentUid(), // The argument type 'String' can't be assigned to the parameter type 'Value<String>'.
      rank: Value(rank),
    );
    return createAndPush(comp, uidDefault: _currentUid());
  }

  /// Met à jour (dates/rank) par firestoreId (local + Firestore).
  /// Signature conservée pour `planning_list.dart`.
  Future<void> updateEventByFirestoreId({
    required String firestoreId,
    required DateTime dateStart,
    required DateTime dateEnd,
    int? rank,
  }) async {
    final row = await getByFirestoreId(firestoreId);

    if (row == null) {
      // Cas de robustesse (rare) : si la ligne locale a disparu,
      // on recrée une ligne locale minimale pour garder l’UI cohérente.
      final tempId = await insertLocal(PlanningEventsCompanion.insert(
        user: '---', // inconnu (on ne l’a pas), l’UI recharge ensuite
        typeEvent: 'UNK',
        dateStart: dateStart,
        dateEnd: dateEnd,
        rank: Value(rank),
        // et on colle le firestoreId connu
      ).copyWith(firestoreId: Value(firestoreId)));
      await updateAndPush(
        tempId,
        PlanningEventsCompanion(
          dateStart: Value(dateStart),
          dateEnd: Value(dateEnd),
          rank: Value(rank),
        ),
        uidDefault: _currentUid(),
      );
      return;
    }

    await updateAndPush(
      row.id,
      PlanningEventsCompanion(
        dateStart: Value(dateStart),
        dateEnd: Value(dateEnd),
        rank: Value(rank),
      ),
      uidDefault: _currentUid(),
    );
  }

  /// Supprime par firestoreId (local + Firestore).
  /// Signature conservée pour `planning_list.dart`.
  Future<void> deleteEventByFirestoreId(String firestoreId) async {
    final row = await getByFirestoreId(firestoreId);
    if (row != null) {
      await deleteAndPush(row.id);
      return;
    }
    // Si pas de ligne locale, on supprime au moins le remote.
    await _remote.doc(firestoreId).delete();
    debugPrint("SYNC[delete][planning]: $firestoreId (local manquant)");
  }

  // ---------------------------------------------------------------------------
  // HELPERS DE MAPPING
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _toRemoteCreateMap(PlanningEvent e,
      {required String uidDefault}) =>
      {
        'user': e.user, // trigramme
        'typeEvent': e.typeEvent,
        'dateStart': fs.Timestamp.fromDate(e.dateStart),
        'dateEnd': fs.Timestamp.fromDate(e.dateEnd),
        // uid non vide sinon fallback uidDefault
        'uid': (e.uid.isNotEmpty ? e.uid : uidDefault),
        if (e.rank != null) 'rank': e.rank,
        'createdAt': fs.FieldValue.serverTimestamp(),
        'updatedAt': fs.FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> _toRemoteUpdateMap(PlanningEvent e,
      {required String uidDefault}) =>
      {
        'user': e.user,
        'typeEvent': e.typeEvent,
        'dateStart': fs.Timestamp.fromDate(e.dateStart),
        'dateEnd': fs.Timestamp.fromDate(e.dateEnd),
        'uid': (e.uid.isNotEmpty ? e.uid : uidDefault),
        if (e.rank != null) 'rank': e.rank,
        'updatedAt': fs.FieldValue.serverTimestamp(),
      };
}
