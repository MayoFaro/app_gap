// File: lib/data/planning_dao.dart
//
// DAO Planning : accès local (Drift) + push Firestore + helpers UI
// Contrat Firestore verrouillé :
//   - user = TRIGRAMME (canonique, 3 lettres, UPPERCASE)
//   - trigramme = TRIGRAMME (miroir de user)
//   - uid = Firebase UID (toujours non vide)
//   - typeEvent, dateStart, dateEnd, rank?, createdAt, updatedAt
//
// IMPORTANT : on n’écrit JAMAIS user=UID. Toujours user=trigramme et trigramme=trigramme.

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

  /// UID Firebase courant (fallback 'unknown' si non connecté)
  String _currentUid() =>
      auth.FirebaseAuth.instance.currentUser?.uid?.trim().isNotEmpty == true
          ? auth.FirebaseAuth.instance.currentUser!.uid
          : 'unknown';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // ---------------------------------------------------------------------------
  // CRUD LOCAL (simples)
  // ---------------------------------------------------------------------------

  Future<List<PlanningEvent>> getAll() => select(planningEvents).get();

  Future<PlanningEvent?> getById(int id) =>
      (select(planningEvents)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<PlanningEvent?> getByFirestoreId(String firestoreId) =>
      (select(planningEvents)..where((t) => t.firestoreId.equals(firestoreId)))
          .getSingleOrNull();

  Future<int> insertLocal(PlanningEventsCompanion comp) =>
      into(planningEvents).insert(comp);

  Future<int> updateLocal(int id, PlanningEventsCompanion comp) =>
      (update(planningEvents)..where((t) => t.id.equals(id))).write(comp);

  Future<void> deleteLocal(int id) async {
    await (delete(planningEvents)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // QUERIES D'AFFICHAGE (UI)
  // ---------------------------------------------------------------------------

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
  // AJOUTS POUR MOTEUR/OUTILS
  // ---------------------------------------------------------------------------

  /// Tous les events chevauchant [start, end[ pour une liste de trigrammes.
  Future<List<PlanningEvent>> fetchEventsForUsersInRange({
    required List<String> userTrigrams,
    required DateTime start,
    required DateTime end,
  }) async {
    if (userTrigrams.isEmpty) return <PlanningEvent>[];
    final upper = userTrigrams.map((e) => e.toUpperCase()).toList();

    final q = select(planningEvents)
      ..where((t) =>
      t.dateEnd.isBiggerOrEqualValue(start) &
      t.dateStart.isSmallerThanValue(end) &
      t.user.isIn(upper))
      ..orderBy([
            (t) => OrderingTerm.asc(t.dateStart),
            (t) => OrderingTerm.asc(t.rank),
      ]);

    return q.get();
  }

  /// Insère des events jour par jour **si la cellule est vide** (pas d’écrasement).
  Future<void> insertDailyEventsIfEmpty(
      List<({String user, DateTime day, String typeEvent, int? rank})> items,
      ) async {
    for (final it in items) {
      final userUp = it.user.toUpperCase();
      final start = _dateOnly(it.day);
      final end = start.add(const Duration(days: 1));

      final q = select(planningEvents)
        ..where((t) =>
        t.user.equals(userUp) &
        t.dateEnd.isBiggerOrEqualValue(start) &
        t.dateStart.isSmallerThanValue(end));
      final existing = await q.get();
      if (existing.isNotEmpty) continue;

      final comp = PlanningEventsCompanion.insert(
        user: userUp,
        typeEvent: it.typeEvent,
        dateStart: start,
        dateEnd: end,
        rank: Value(it.rank),
      );
      await createAndPush(comp, uidDefault: _currentUid());
    }
  }

  /// Supprime tous les 'AST' chevauchant [start, end[ pour une liste de trigrammes.
  Future<void> deleteAstInRange({
    required List<String> userTrigrams,
    required DateTime start,
    required DateTime end,
  }) async {
    if (userTrigrams.isEmpty) return;

    final upper = userTrigrams.map((e) => e.toUpperCase()).toList();

    final q = select(planningEvents)
      ..where((t) =>
      t.dateEnd.isBiggerOrEqualValue(start) &
      t.dateStart.isSmallerThanValue(end) &
      t.user.isIn(upper) &
      t.typeEvent.equals('AST'))
      ..orderBy([
            (t) => OrderingTerm.asc(t.dateStart),
            (t) => OrderingTerm.asc(t.rank),
      ]);

    final rows = await q.get();
    for (final row in rows) {
      await deleteAndPush(row.id);
    }
  }

  // ---------------------------------------------------------------------------
  // PULL FIRESTORE -> LOCAL (hydrate le cache)
  // ---------------------------------------------------------------------------

  /// Hydrate le cache local pour tous les events qui **chevauchent** [start, end[.
  ///
  /// Mapping trigramme :
  ///   - si `trigramme` (remote) existe et long==3 → on l’utilise (UPPERCASE).
  ///   - sinon si `user` (remote) long==3 → on l’utilise (UPPERCASE).
  ///   - sinon → SKIP + log (on ne peut pas déterminer le trigramme).
  ///
  /// On interroge Firestore avec `dateStart < end`, puis on filtre en mémoire `dateEnd >= start`.
  Future<int> pullRangeFromRemote({
    required DateTime start,
    required DateTime end,
    List<String>? trigramFilter,
  }) async {
    final startD = _dateOnly(start);
    final endExcl = _dateOnly(end);
    final endForQuery = endExcl;

    final trigSet = trigramFilter?.map((e) => e.toUpperCase()).toSet();

    final snap = await _remote
        .where('dateStart', isLessThan: fs.Timestamp.fromDate(endForQuery))
        .get();

    int upserts = 0;

    for (final doc in snap.docs) {
      final data = doc.data();

      final tsStart = data['dateStart'] as fs.Timestamp?;
      final tsEnd = data['dateEnd'] as fs.Timestamp?;
      if (tsStart == null || tsEnd == null) continue;

      final dStart = tsStart.toDate();
      final dEnd = tsEnd.toDate();

      // chevauchement [start, end[
      final overlaps =
      !(dEnd.isBefore(startD) || !dStart.isBefore(endExcl));
      if (!overlaps) continue;

      // trigramme robuste
      String? tri;
      final trigField = (data['trigramme'] as String?)?.trim();
      if (trigField != null && trigField.length == 3) {
        tri = trigField.toUpperCase();
      } else {
        final userField = (data['user'] as String?)?.trim();
        if (userField != null && userField.length == 3) {
          tri = userField.toUpperCase();
        }
      }
      if (tri == null) {
        debugPrint("PULL[skip] ${doc.id}: trigramme introuvable (trigramme/user invalides).");
        continue;
      }

      if (trigSet != null && !trigSet.contains(tri)) continue;

      final typeEvent = ((data['typeEvent'] as String?) ?? 'UNK').trim();
      final uid = ((data['uid'] as String?) ?? '').trim();
      final rankRaw = data['rank'];
      final rankVal = (rankRaw is int) ? rankRaw : null;

      // upsert local par firestoreId
      final existing = await getByFirestoreId(doc.id);
      if (existing == null) {
        final comp = PlanningEventsCompanion.insert(
          user: tri,
          typeEvent: typeEvent,
          dateStart: dStart,
          dateEnd: dEnd,
          rank: Value(rankVal),
        ).copyWith(
          uid: Value(uid),
          firestoreId: Value(doc.id),
        );
        await insertLocal(comp);
        upserts++;
      } else {
        await updateLocal(existing.id, PlanningEventsCompanion(
          user: Value(tri),
          typeEvent: Value(typeEvent),
          dateStart: Value(dStart),
          dateEnd: Value(dEnd),
          uid: Value(uid),
          rank: Value(rankVal ?? existing.rank),
        ));
        upserts++;
      }
    }

    debugPrint("PULL[planning] upserts=$upserts (range ${startD.toIso8601String()} .. ${endExcl.toIso8601String()})");
    return upserts;
  }

  // ---------------------------------------------------------------------------
  // SYNC FIRESTORE (PUSH)
  // ---------------------------------------------------------------------------

  /// Crée local + pousse Firestore, en écrivant **user=trigramme**, **trigramme=trigramme**, **uid non vide**.
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

    // 3) Rattache l'ID
    await (update(planningEvents)..where((t) => t.id.equals(localId))).write(
      PlanningEventsCompanion(firestoreId: Value(ref.id)),
    );

    debugPrint("SYNC[upsert->create][planning]: ${ref.id}");
    return ref.id;
  }

  /// Met à jour local + Firestore (création si besoin).
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
      final ref = await _remote.add(
        _toRemoteCreateMap(
          existing.copyWith(
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

  Future<void> deleteAndPush(int id) async {
    final row =
    await (select(planningEvents)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;

    await (delete(planningEvents)..where((t) => t.id.equals(id))).go();

    if (row.firestoreId != null) {
      await _remote.doc(row.firestoreId!).delete();
      debugPrint("SYNC[delete][planning]: ${row.firestoreId}");
    }
  }

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
      rank: Value(rank),
    );
    return createAndPush(comp, uidDefault: _currentUid());
  }

  /// ✅ Corrigé : met à jour **uniquement** dateStart/dateEnd/rank côté Firestore si la ligne locale est manquante,
  /// sans jamais pousser un typeEvent 'UNK'. Puis (re)construit proprement la ligne locale depuis le doc Firestore.
  Future<void> updateEventByFirestoreId({
    required String firestoreId,
    required DateTime dateStart,
    required DateTime dateEnd,
    int? rank,
  }) async {
    final row = await getByFirestoreId(firestoreId);

    if (row != null) {
      // Cas standard : on garde le pipeline local->remote existant.
      await updateAndPush(
        row.id,
        PlanningEventsCompanion(
          dateStart: Value(dateStart),
          dateEnd: Value(dateEnd),
          rank: Value(rank),
        ),
        uidDefault: _currentUid(),
      );
      return;
    }

    // ⚠️ Cas "ligne locale manquante" :
    // 1) PATCH MINIMAL côté Firestore (merge), pour ne pas toucher typeEvent/user/trigramme
    await _remote.doc(firestoreId).set({
      'dateStart': fs.Timestamp.fromDate(dateStart),
      'dateEnd'  : fs.Timestamp.fromDate(dateEnd),
      if (rank != null) 'rank': rank,
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }, fs.SetOptions(merge: true));

    // 2) Relire le doc Firestore pour reconstruire une ligne locale propre
    final snap = await _remote.doc(firestoreId).get();
    if (!snap.exists) {
      debugPrint("UPDATE[planning] doc $firestoreId introuvable après patch.");
      return;
    }
    final data = snap.data()!;
    final typeEvent = (data['typeEvent'] as String?)?.trim() ?? 'UNK';
    final uid = (data['uid'] as String?)?.trim() ?? '';
    final rankRaw = data['rank'];
    final rankVal = (rankRaw is int) ? rankRaw : null;

    String tri;
    final trigField = (data['trigramme'] as String?)?.trim();
    if (trigField != null && trigField.length == 3) {
      tri = trigField.toUpperCase();
    } else {
      final userField = (data['user'] as String?)?.trim() ?? '';
      tri = (userField.length == 3 ? userField.toUpperCase() : '---');
    }

    // 3) (Ré)insérer une ligne locale propre, **sans** renvoyer une écriture réseau parasite.
    await insertLocal(
      PlanningEventsCompanion.insert(
        user: tri,
        typeEvent: typeEvent,
        dateStart: dateStart,
        dateEnd: dateEnd,
        rank: Value(rank ?? rankVal),
      ).copyWith(
        uid: Value(uid),
        firestoreId: Value(firestoreId),
      ),
    );
  }

  Future<void> deleteEventByFirestoreId(String firestoreId) async {
    final row = await getByFirestoreId(firestoreId);
    if (row != null) {
      await deleteAndPush(row.id);
      return;
    }
    await _remote.doc(firestoreId).delete();
    debugPrint("SYNC[delete][planning]: $firestoreId (local manquant)");
  }

  // ---------------------------------------------------------------------------
  // HELPERS DE MAPPING (écriture Firestore)
  // ---------------------------------------------------------------------------

  /// Map de création Firestore garantissant `user=trigramme`, `trigramme=trigramme`, `uid` non vide.
  Map<String, dynamic> _toRemoteCreateMap(PlanningEvent e,
      {required String uidDefault}) =>
      {
        'user': e.user,              // TRIGRAMME (canonique)
        'trigramme': e.user,         // miroir
        'typeEvent': e.typeEvent,
        'dateStart': fs.Timestamp.fromDate(e.dateStart),
        'dateEnd': fs.Timestamp.fromDate(e.dateEnd),
        'uid': (e.uid.isNotEmpty ? e.uid : uidDefault),
        if (e.rank != null) 'rank': e.rank,
        'createdAt': fs.FieldValue.serverTimestamp(),
        'updatedAt': fs.FieldValue.serverTimestamp(),
      };

  /// Map d’update Firestore gardant le même contrat.
  Map<String, dynamic> _toRemoteUpdateMap(PlanningEvent e,
      {required String uidDefault}) =>
      {
        'user': e.user,              // TRIGRAMME
        'trigramme': e.user,         // miroir
        'typeEvent': e.typeEvent,
        'dateStart': fs.Timestamp.fromDate(e.dateStart),
        'dateEnd': fs.Timestamp.fromDate(e.dateEnd),
        'uid': (e.uid.isNotEmpty ? e.uid : uidDefault),
        if (e.rank != null) 'rank': e.rank,
        'updatedAt': fs.FieldValue.serverTimestamp(),
      };
}
