import 'package:drift/drift.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/cupertino.dart';

import 'app_database.dart';

part 'mission_dao.g.dart';

const String kMissionsCollection = 'missions';

@DriftAccessor(tables: [Missions, Users])
class MissionDao extends DatabaseAccessor<AppDatabase>
    with _$MissionDaoMixin {
  final AppDatabase _db;
  final fs.CollectionReference<Map<String, dynamic>> _remote =
  fs.FirebaseFirestore.instance.collection(kMissionsCollection);

  MissionDao(this._db) : super(_db);

  // ---------------------------------------------------------------------------
  // CRUD LOCAL
  // ---------------------------------------------------------------------------

  Future<List<Mission>> getAllMissions() => select(missions).get();

  Future<Mission?> getByRemoteId(String remoteId) {
    return (select(missions)..where((t) => t.remoteId.equals(remoteId)))
        .getSingleOrNull();
  }

  Future<int> insertMission(MissionsCompanion comp) =>
      into(missions).insert(comp);

  Future<void> deleteMission(int id) async {
    final mission = await (_db.select(_db.missions)
      ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();

    if (mission != null) {
      // 🔄 Supprime du local
      await (_db.delete(_db.missions)..where((t) => t.id.equals(id))).go();

      // 🔄 Supprime du Firestore si remoteId existe
      if (mission.remoteId != null) {
        await fs.FirebaseFirestore.instance
            .collection('missions')
            .doc(mission.remoteId!)
            .delete();
        debugPrint("SYNC[delete]: Supprimé Firestore ${mission.remoteId}");
      }
    }
  }

  // upsert: insert si nouveau, sinon update
  Future<void> upsertMission(MissionsCompanion comp) async {
    if (comp.id.present) {
      await (update(missions)..where((t) => t.id.equals(comp.id.value)))
          .write(comp.copyWith(isSynced: const Value(false)));
    } else {
      await into(missions).insert(comp.copyWith(isSynced: const Value(false)));
    }
  }

  // ---------------------------------------------------------------------------
  // SYNC FIRESTORE <-> DRIFT
  // ---------------------------------------------------------------------------

  Future<void> pullFromRemote() async {
    final snap = await _remote.get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final remoteId = doc.id;

      final dt = (data['date'] as fs.Timestamp).toDate();
      final vecteur = data['vecteur'] as String;
      final pilote1 = data['pilote1'] as String;
      final pilote2 = data['pilote2'] as String?;
      final pilote3 = data['pilote3'] as String?;
      final destinationCode = data['destinationCode'] as String;
      final description = data['description'] as String?;
      final createdAtRemote =
          (data['createdAt'] as fs.Timestamp?)?.toDate() ?? DateTime.now();
      final updatedAtRemote =
          (data['updatedAt'] as fs.Timestamp?)?.toDate() ?? DateTime.now();

      final comp = MissionsCompanion.insert(
        date: dt,
        vecteur: vecteur,
        pilote1: pilote1,
        pilote2: Value(pilote2),
        pilote3: Value(pilote3),
        destinationCode: destinationCode,
        description: Value(description),
        createdAt: Value(createdAtRemote),
        updatedAt: Value(updatedAtRemote),
        remoteId: Value(remoteId),
        isSynced: const Value(true), // ✅ vient du serveur
      );

      final existing = await getByRemoteId(remoteId);

      if (existing == null) {
        await into(missions).insert(comp);
        print("SYNC[pull->insert]: $remoteId");
      } else {
        // Conflit → comparer updatedAt
        final localUpdated =
            existing.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final remoteUpdated = updatedAtRemote;

        if (remoteUpdated.isAfter(localUpdated)) {
          // Firestore plus récent → maj local
          await (update(missions)..where((t) => t.id.equals(existing.id)))
              .write(comp);
          print("SYNC[pull->update]: $remoteId");
        } else {
          // Local plus récent → push Firestore
          await _remote.doc(existing.remoteId!).set(
            _toRemoteUpdateMap(existing),
            fs.SetOptions(merge: true),
          );
          await (update(missions)..where((t) => t.id.equals(existing.id)))
              .write(const MissionsCompanion(isSynced: Value(true)));
          print("SYNC[pull->pushLocal]: $remoteId");
        }
      }
    }
  }

  Future<void> syncPendingMissions() async {
    final pending =
    await (select(missions)..where((t) => t.isSynced.equals(false))).get();

    for (final m in pending) {
      if (m.remoteId == null) {
        // CREATE
        final ref = await _remote.add(_toRemoteCreateMap(m));
        await (update(missions)..where((t) => t.id.equals(m.id))).write(
          MissionsCompanion(
            remoteId: Value(ref.id),
            isSynced: const Value(true),
          ),
        );
        print("SYNC[upsert->create]: ${ref.id}");
      } else {
        // UPDATE
        await _remote.doc(m.remoteId!).set(
          _toRemoteUpdateMap(m),
          fs.SetOptions(merge: true),
        );
        await (update(missions)..where((t) => t.id.equals(m.id))).write(
          const MissionsCompanion(isSynced: Value(true)),
        );
        print("SYNC[upsert->update]: ${m.remoteId}");
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PATCH DEPART / ARRIVEE
  // ---------------------------------------------------------------------------

  Future<void> setActualDeparture(int id, {DateTime? when}) async {
    final ts = when ?? DateTime.now();
    final row =
    await (select(missions)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    await (update(missions)..where((t) => t.id.equals(id))).write(
      MissionsCompanion(
        actualDeparture: Value(ts),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );

    if (row.remoteId != null) {
      await _remote.doc(row.remoteId!).set({
        'actualDeparture': fs.Timestamp.fromDate(ts),
        'updatedAt': fs.Timestamp.fromDate(DateTime.now()),
      }, fs.SetOptions(merge: true));

      await (update(missions)..where((t) => t.id.equals(id))).write(
        const MissionsCompanion(isSynced: Value(true)),
      );
    }
  }

  Future<void> setActualArrival(int id, {DateTime? when}) async {
    final ts = when ?? DateTime.now();
    final row =
    await (select(missions)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;

    await (update(missions)..where((t) => t.id.equals(id))).write(
      MissionsCompanion(
        actualArrival: Value(ts),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );

    if (row.remoteId != null) {
      await _remote.doc(row.remoteId!).set({
        'actualArrival': fs.Timestamp.fromDate(ts),
        'updatedAt': fs.Timestamp.fromDate(DateTime.now()),
      }, fs.SetOptions(merge: true));

      await (update(missions)..where((t) => t.id.equals(id))).write(
        const MissionsCompanion(isSynced: Value(true)),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _toRemoteCreateMap(Mission m) => {
    'date': fs.Timestamp.fromDate(m.date),
    'vecteur': m.vecteur,
    'pilote1': m.pilote1,
    if (m.pilote2 != null) 'pilote2': m.pilote2,
    if (m.pilote3 != null) 'pilote3': m.pilote3,
    'destinationCode': m.destinationCode,
    if (m.description != null) 'description': m.description,
    'createdAt': fs.Timestamp.fromDate(m.createdAt),
    'updatedAt': fs.Timestamp.fromDate(DateTime.now()),
  };

  Map<String, dynamic> _toRemoteUpdateMap(Mission m) => {
    'date': fs.Timestamp.fromDate(m.date),
    'vecteur': m.vecteur,
    'pilote1': m.pilote1,
    if (m.pilote2 != null) 'pilote2': m.pilote2,
    if (m.pilote3 != null) 'pilote3': m.pilote3,
    'destinationCode': m.destinationCode,
    if (m.description != null) 'description': m.description,
    'updatedAt': fs.Timestamp.fromDate(DateTime.now()),
  };
}
