// lib/data/mission_dao.dart
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:drift/drift.dart'; // <- complet : fournit isBiggerOrEqualValue, Value, OrderingTerm...
import 'app_database.dart';

class MissionDao {
  final AppDatabase _db;
  MissionDao(this._db);

  AppDatabase get attachedDatabase => _db;

  // -----------------------------
  // Helpers
  // -----------------------------
  String _groupFromVecteur(String v) {
    final up = v.toUpperCase();
    if (up == 'AH175' || up == 'EC225') return 'helico';
    return 'avion';
  }

  Map<String, dynamic> _toRemoteMap(Mission m, {bool forCreate = false}) {
    // Pour une création, createdAt peut être serverTimestamp si null localement
    return {
      'remoteId': m.remoteId,
      'date': fs.Timestamp.fromDate(m.date.toUtc()),
      'vecteur': m.vecteur,
      'group': _groupFromVecteur(m.vecteur),
      'pilote1': m.pilote1,
      if (m.pilote2 != null && m.pilote2!.isNotEmpty) 'pilote2': m.pilote2,
      if (m.pilote3 != null && m.pilote3!.isNotEmpty) 'pilote3': m.pilote3,
      'destinationCode': m.destinationCode,
      if (m.description != null && m.description!.isNotEmpty) 'description': m.description,
      if (m.actualDeparture != null) 'actualDeparture': fs.Timestamp.fromDate(m.actualDeparture!.toUtc()),
      if (m.actualArrival != null) 'actualArrival': fs.Timestamp.fromDate(m.actualArrival!.toUtc()),
      'createdAt': m.createdAt != null
          ? fs.Timestamp.fromDate(m.createdAt!.toUtc())
          : (forCreate ? fs.FieldValue.serverTimestamp() : null),
      'updatedAt': fs.FieldValue.serverTimestamp(),
    }..removeWhere((k, v) => v == null);
  }

  // -----------------------------
  // Queries - Local
  // -----------------------------
  Future<List<Mission>> getAllMissions() async {
    return _db.select(_db.missions).get();
  }

  Stream<List<Mission>> watchUpcomingMissions({int limit = 5}) {
    final now = DateTime.now();
    final q = (_db.select(_db.missions)
      ..where((m) => m.date.isBiggerOrEqualValue(now))
      ..orderBy([ (m) => OrderingTerm(expression: m.date, mode: OrderingMode.asc) ])
      ..limit(limit));
    return q.watch();
  }

  Future<Mission?> getByRemoteId(String remoteId) async {
    return (_db.select(_db.missions)..where((t) => t.remoteId.equals(remoteId)))
        .getSingleOrNull();
  }

  // -----------------------------
  // Firestore collection
  // -----------------------------
  fs.CollectionReference<Map<String, dynamic>> get _remote =>
      fs.FirebaseFirestore.instance.collection('missions');

  // -----------------------------
  // Write - Local + Remote
  // -----------------------------

  /// Insert local + timestamps, puis crée le doc Firestore.
  /// Ensuite, stocke le remoteId dans la ligne locale.
  Future<int> insertMission(MissionsCompanion entry) async {
    final now = DateTime.now();

    // 1) Insert local avec createdAt/updatedAt
    final id = await _db.into(_db.missions).insert(
      entry.copyWith(
        createdAt: const Value.absent(), // default en DB: currentDateAndTime
        updatedAt: Value(now),
      ),
    );

    // 2) Récup ligne insérée
    final row = await (_db.select(_db.missions)..where((t) => t.id.equals(id))).getSingle();

    // 3) Push Firestore
    try {
      final doc = await _remote.add(_toRemoteMap(row, forCreate: true));
      // 4) store remoteId localement
      await (_db.update(_db.missions)..where((t) => t.id.equals(id))).write(
        MissionsCompanion(remoteId: Value(doc.id)),
      );
    } catch (e) {
      // Permissions ou offline : on garde l'insert local, sans remoteId
      // Tu peux logguer si tu veux
    }

    return id;
  }

  /// Update local + updatedAt, puis upsert Firestore (avec merge).
  Future<void> updateMission(Mission m) async {
    final now = DateTime.now();

    // 1) update local
    await (_db.update(_db.missions)..where((t) => t.id.equals(m.id))).write(
      MissionsCompanion(
        date: Value(m.date),
        vecteur: Value(m.vecteur),
        pilote1: Value(m.pilote1),
        pilote2: Value(m.pilote2),          // nullable
        pilote3: Value(m.pilote3),          // nullable
        destinationCode: Value(m.destinationCode),
        description: Value(m.description),  // nullable
        actualDeparture: Value(m.actualDeparture),
        actualArrival: Value(m.actualArrival),
        updatedAt: Value(now),
      ),
    );

    // 2) upsert Firestore
    final row = await (_db.select(_db.missions)..where((t) => t.id.equals(m.id))).getSingle();
    try {
      if (row.remoteId == null || row.remoteId!.isEmpty) {
        final doc = await _remote.add(_toRemoteMap(row, forCreate: true));
        await (_db.update(_db.missions)..where((t) => t.id.equals(row.id))).write(
          MissionsCompanion(remoteId: Value(doc.id)),
        );
      } else {
        await _remote.doc(row.remoteId!).set(_toRemoteMap(row), fs.SetOptions(merge: true));
      }
    } catch (_) {
      // ignore: errors réseau / permissions → update local reste OK
    }
  }

  /// Suppression locale + suppression distante (si remoteId présent)
  Future<void> deleteMission(int id) async {
    final row = await (_db.select(_db.missions)..where((t) => t.id.equals(id))).getSingleOrNull();

    // 1) delete local
    await (_db.delete(_db.missions)..where((t) => t.id.equals(id))).go();

    // 2) delete remote
    if (row?.remoteId != null && row!.remoteId!.isNotEmpty) {
      try {
        await _remote.doc(row.remoteId!).delete();
      } catch (_) {
        // ignore
      }
    }
  }

  // -----------------------------
  // Actions "Vol en cours"
  // -----------------------------

  /// Marque l'heure réelle de décollage.
  /// - met à jour la ligne locale (actualDeparture + updatedAt)
  /// - upsert le doc Firestore (merge)
  Future<void> setActualDeparture(int id, {DateTime? at}) async {
    final when = at ?? DateTime.now();

    // 1) local
    await (_db.update(_db.missions)..where((t) => t.id.equals(id))).write(
      MissionsCompanion(
        actualDeparture: Value(when),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // 2) remote
    final row = await (_db.select(_db.missions)..where((t) => t.id.equals(id))).getSingle();
    try {
      if (row.remoteId == null || row.remoteId!.isEmpty) {
        final created = await _remote.add(_toRemoteMap(row.copyWith(actualDeparture: Value(when)), forCreate: true));
        await (_db.update(_db.missions)..where((t) => t.id.equals(id))).write(
          MissionsCompanion(remoteId: Value(created.id)),
        );
      } else {
        await _remote.doc(row.remoteId!).set(
          {
            'actualDeparture': fs.Timestamp.fromDate(when.toUtc()),
            'updatedAt': fs.FieldValue.serverTimestamp(),
          },
          fs.SetOptions(merge: true),
        );
      }
    } catch (_) {
      // ignore
    }
  }

  /// Marque l'heure réelle d'atterrissage.
  /// - met à jour la ligne locale (actualArrival + updatedAt)
  /// - upsert le doc Firestore (merge)
  Future<void> setActualArrival(int id, {DateTime? at}) async {
    final when = at ?? DateTime.now();

    // 1) local
    await (_db.update(_db.missions)..where((t) => t.id.equals(id))).write(
      MissionsCompanion(
        actualArrival: Value(when),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // 2) remote
    final row = await (_db.select(_db.missions)..where((t) => t.id.equals(id))).getSingle();
    try {
      if (row.remoteId == null || row.remoteId!.isEmpty) {
        final created = await _remote.add(_toRemoteMap(row.copyWith(actualArrival: Value(when)), forCreate: true));
        await (_db.update(_db.missions)..where((t) => t.id.equals(id))).write(
          MissionsCompanion(remoteId: Value(created.id)),
        );
      } else {
        await _remote.doc(row.remoteId!).set(
          {
            'actualArrival': fs.Timestamp.fromDate(when.toUtc()),
            'updatedAt': fs.FieldValue.serverTimestamp(),
          },
          fs.SetOptions(merge: true),
        );
      }
    } catch (_) {
      // ignore
    }
  }
}
